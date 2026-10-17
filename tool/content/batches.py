"""Anthropic Message Batches: immutable requests, resumable collection, explicit retry."""
import json
import os
import re
import urllib.error
import urllib.request
from pathlib import Path

from .common import (CONTENT, SOURCE, canonical, digest, now, read_json, read_jsonl,
                     require, schema_validate, sources, write_json, write_jsonl)

API = "https://api.anthropic.com/v1/messages/batches"


def api(method, url, body=None):
    require(url.startswith(API), "Unexpected batch endpoint")
    key = os.environ.get("ANTHROPIC_API_KEY")
    require(key, "Set ANTHROPIC_API_KEY in the environment")
    request = urllib.request.Request(url, method=method,
        data=None if body is None else canonical(body).encode(),
        headers={"x-api-key": key, "anthropic-version": "2023-06-01", "content-type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=90) as response:
            return response.read().decode()
    except urllib.error.HTTPError as error:
        # Do not serialize request headers or secrets in logs.
        raise ValueError(f"Anthropic HTTP {error.code}: {error.read().decode()[:1000]}") from None


def api_schema(value):
    """Keep strict local validation; remove unsupported constraints from wire schema."""
    if isinstance(value, list):
        return [api_schema(v) for v in value]
    if isinstance(value, dict):
        return {k: api_schema(v) for k, v in value.items()
                if k not in {"$schema", "minLength", "maxLength", "minItems", "maxItems", "uniqueItems",
                             "minimum", "maximum", "format"}}
    return value


def prepare(stage, output, input_path=None, source_path=SOURCE, limit=100,
            effort=None, only=None, cache_dir=None, config_path=CONTENT / "config.json"):
    require(stage in {"generate", "review"}, "Unknown stage")
    require(1 <= limit <= 500, "Use batches of 1–500 entries")
    require(not Path(output).exists(), "Request file exists; choose a new output path")
    config = read_json(config_path)
    source_rows = sources(source_path)
    prompt_version = config[f"{stage}Prompt"]
    prompt = (CONTENT / f"prompts/{prompt_version}.md").read_text()
    if stage == "generate":
        gold = read_jsonl(CONTENT / "gold/starter_examples.jsonl")
        additional = read_jsonl(CONTENT / "gold/additional_examples.jsonl")
        prompt += "\n\n## 자체 작성 문체 참고 예시 (전문 검수 완료를 뜻하지 않음)\n" + canonical(gold[:2] + additional[:1])
        approved_gold = read_jsonl(CONTENT / "gold/approved_examples.jsonl")
        if approved_gold:
            require(all(r.get("status") == "human_approved" and r.get("review", {}).get("reviewer")
                        for r in approved_gold), "Gold examples need human review provenance")
            prompt += "\n\n## 사람 승인 예시\n" + canonical(approved_gold[:1])
        prompt += "\n\n## 허용 기본 어휘·단어군\n" + canonical([
            {k: r[k] for k in ("headword", "variants", "related_forms")} for r in source_rows.values()])
        inputs = [{"headword": word, "source": row} for word, row in source_rows.items()]
        if input_path:
            feedback = {r['headword']: r for r in read_jsonl(input_path) if r.get('status') == 'needs_fix'}
            require(feedback, 'Correction input must contain needs_fix records')
            inputs = [{**r, 'previousDraft': feedback[r['headword']].get('data'),
                       'correctionFeedback': {'automatic': feedback[r['headword']].get('autoValidation'),
                                              'human': feedback[r['headword']].get('humanReview')}}
                      for r in inputs if r['headword'] in feedback]
    else:
        require(input_path is not None, "Review needs validated JSONL")
        inputs = [r for r in read_jsonl(input_path) if r.get('status') == 'auto_checked']
        require(inputs, "No review input")
        require(all(r["status"] == "auto_checked" and not r["autoValidation"]["errors"]
                    and r["contentHash"] == digest(r["data"]) for r in inputs), "Review input failed/stale auto checks")
    schema = read_json(CONTENT / f"schema/{'generation' if stage == 'generate' else 'review'}.schema.json")
    successful = set()
    if cache_dir:
        for path in Path(cache_dir).glob("*.jsonl"):
            for record in read_jsonl(path):
                if record.get("status") in {"draft", "llm_reviewed"}:
                    successful.add(record.get("requestHash"))
    requests, entries = [], {}
    selected = set(only) if only else None
    if selected:
        require(selected <= {r['headword'] for r in inputs}, f"Unknown requested headwords: {selected - {r['headword'] for r in inputs}}")
    for record in inputs:
        word = record["headword"]
        if selected is not None and word not in selected:
            continue
        custom_id = word if re.fullmatch(r"[a-zA-Z0-9_-]{1,64}", word) else "word_" + digest(word)[:32]
        params = {
            "model": config["model"], "max_tokens": config["max_tokens"],
            "thinking": {"type": "adaptive"},
            "output_config": {"effort": effort or config["effort"],
                              "format": {"type": "json_schema", "schema": api_schema(schema)}},
            "system": [{"type": "text", "text": prompt, "cache_control": {"type": "ephemeral"}}],
            "messages": [{"role": "user", "content": canonical(record)}],
        }
        request_hash = digest(params)
        if request_hash in successful:
            continue
        require(custom_id not in entries, "Duplicate request ID")
        requests.append({"custom_id": custom_id, "params": params})
        entries[custom_id] = {"headword": word, "requestHash": request_hash, "input": record}
        if len(requests) == limit:
            break
    require(requests, "No changed requests to prepare")
    write_jsonl(output, requests)
    manifest = {"stage": stage, "model": config["model"], "effort": effort or config["effort"],
                "promptVersion": prompt_version, "promptHash": digest(prompt),
                "schemaHash": digest(schema), "sourceHash": digest(source_rows),
                "requestsHash": digest(requests), "createdAt": now(), "entries": entries,
                "submissionState": "prepared"}
    write_json(Path(output).with_suffix(".manifest.json"), manifest)
    return {"count": len(requests), "requests": str(output)}


def load_requests(path):
    manifest_path = Path(path).with_suffix(".manifest.json")
    manifest = read_json(manifest_path)
    requests = read_jsonl(path)
    require(manifest and digest(requests) == manifest["requestsHash"], "Request manifest is missing or changed")
    return manifest_path, manifest, requests


def submit(path, adopt_batch_id=None):
    manifest_path, manifest, requests = load_requests(path)
    if manifest.get("batchId"):
        return {"batchId": manifest["batchId"], "reused": True}
    if adopt_batch_id:
        require(re.fullmatch(r"msgbatch_[A-Za-z0-9]+", adopt_batch_id), "Invalid batch ID")
        result = json.loads(api("GET", f"{API}/{adopt_batch_id}"))
    else:
        require(manifest["submissionState"] == "prepared",
                "Prior submission outcome is unknown. Reconcile in provider console, then submit --adopt-batch-id")
        require(os.environ.get("ANTHROPIC_API_KEY"), "Set ANTHROPIC_API_KEY")
        manifest["submissionState"] = "submitting"
        write_json(manifest_path, manifest)
        result = json.loads(api("POST", API, {"requests": requests}))
    manifest.update(batchId=result["id"], submissionState="submitted", batch=result)
    write_json(manifest_path, manifest)
    return result


def status(path):
    _, manifest, _ = load_requests(path)
    require(manifest.get("batchId"), "Submit this batch first")
    return json.loads(api("GET", f"{API}/{manifest['batchId']}"))


def collect(path, output, results_path=None):
    _, manifest, requests = load_requests(path)
    if results_path:
        raw = read_jsonl(results_path)
    else:
        current = status(path)
        require(current["processing_status"] == "ended", "Batch still running; check status later")
        raw = [json.loads(line) for line in api("GET", f"{API}/{manifest['batchId']}/results").splitlines() if line]
    raw_by_id = {}
    for result in raw:
        custom_id = result["custom_id"]
        require(custom_id in manifest["entries"] and custom_id not in raw_by_id, "Unknown/duplicate result custom_id")
        raw_by_id[custom_id] = result
    write_jsonl(Path(output).with_suffix(".raw.jsonl"), raw)
    records, failures = [], []
    for custom_id, entry in manifest["entries"].items():
        result = raw_by_id.get(custom_id, {}).get("result", {"type": "missing"})
        message = result.get("message", {})
        try:
            require(result["type"] == "succeeded", result["type"])
            require(message.get("stop_reason") == "end_turn", f"stop_reason:{message.get('stop_reason')}")
            data = json.loads("".join(block["text"] for block in message["content"] if block["type"] == "text"))
            errors = schema_validate(data, "generation" if manifest["stage"] == "generate" else "review")
            require(not errors, "; ".join(errors))
            require(data["headword"] == entry["headword"], "Headword does not match custom_id")
            provenance = {"model": message.get("model", manifest["model"]), "promptVersion": manifest["promptVersion"],
                          "promptHash": manifest["promptHash"], "schemaHash": manifest["schemaHash"],
                          "effort": manifest["effort"], "batchId": manifest.get("batchId", "imported-results"),
                          "requestHash": entry["requestHash"], "usage": message.get("usage", {}), "generatedAt": now()}
            if manifest["stage"] == "generate":
                record = {"headword": entry["headword"], "data": data, "status": "draft",
                          "source": entry["input"]["source"], "generation": provenance}
            else:
                record = dict(entry["input"])
                ratings = [c['rating'] for c in data['criteria'].values()]
                data['severity'] = 'fail' if 'fail' in ratings or data['criticalError'] else 'warn' if 'warn' in ratings else 'pass'
                record.update(status="llm_reviewed", llmReview={**data, "provenance": provenance,
                                                               "inputHash": record["contentHash"]})
            record["requestHash"] = entry["requestHash"]
            records.append(record)
        except (ValueError, KeyError, TypeError) as error:
            failures.append({"custom_id": custom_id, "headword": entry["headword"], "reason": str(error),
                             "requestHash": entry["requestHash"], "usage": message.get("usage", {})})
    rank = {"fail": 0, "warn": 1, "pass": 2}
    records.sort(key=lambda r: (rank.get(r.get("llmReview", {}).get("severity"), 3), r["headword"]))
    write_jsonl(output, records)
    write_jsonl(Path(output).with_suffix(".failures.jsonl"), failures)
    failed_ids = {f["custom_id"] for f in failures}
    retry = [r for r in requests if r["custom_id"] in failed_ids]
    retry_path = Path(output).with_suffix(".retry.jsonl")
    write_jsonl(retry_path, retry)
    write_json(retry_path.with_suffix(".manifest.json"), {
        **{k: v for k, v in manifest.items() if k not in {'batchId', 'batch'}},
        "entries": {k: v for k, v in manifest["entries"].items() if k in failed_ids},
        "requestsHash": digest(retry), "submissionState": "prepared", "createdAt": now(),
    })
    usage = {}
    for row in raw:
        for key, count in row.get('result', {}).get('message', {}).get('usage', {}).items():
            if isinstance(count, (int, float)):
                usage[key] = usage.get(key, 0) + count
    summary = {"succeeded": len(records), "failed": len(failures), "usage": usage}
    write_json(Path(output).with_suffix(".summary.json"), summary)
    return summary
