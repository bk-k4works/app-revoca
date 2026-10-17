from __future__ import annotations

import csv
import hashlib
import json
import os
import tempfile
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "content"
SOURCE = CONTENT / "sources/curriculum_2022_basic.csv"
SOURCE_URL = "https://www.goe.go.kr/resource/old/BBSMSTR_000000030136/BBS_202307111028067791.pdf"


def now():
    return datetime.now(timezone.utc).isoformat()


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(value):
    return hashlib.sha256(canonical(value).encode()).hexdigest()


def file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_json(path, default=None):
    path = Path(path)
    return json.loads(path.read_text()) if path.exists() else default


def read_jsonl(path):
    path = Path(path)
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]


def atomic_write(path, text):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".pending-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as out:
            out.write(text)
            out.flush()
            os.fsync(out.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def write_json(path, value):
    atomic_write(path, json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def write_jsonl(path, values):
    atomic_write(path, "".join(canonical(value) + "\n" for value in values))


def sources(path=SOURCE):
    with open(path, encoding="utf-8-sig", newline="") as stream:
        rows = list(csv.DictReader(stream))
    result = {}
    for row in rows:
        word = row["headword"]
        if word in result:
            raise ValueError(f"Duplicate source headword: {word}")
        result[word] = {
            **row,
            "variants": [v for v in row["variants"].split("|") if v],
            "related_forms": [v for v in row.get("related_forms", "").split("|") if v],
            "elementary": row["elementary"] == "true",
            "source_page": int(row["source_page"]),
        }
    return result


def schema_validate(value, name):
    from jsonschema import Draft202012Validator, FormatChecker
    schema = read_json(CONTENT / f"schema/{name}.schema.json")
    errors = sorted(Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(value),
                    key=lambda e: str(list(e.path)))
    return [f"{'.'.join(map(str, e.path))}: {e.message}" for e in errors]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def resolve_id(value, mapping):
    seen = set()
    while value in mapping:
        require(value not in seen, f"ID migration cycle: {value}")
        seen.add(value)
        value = mapping[value]
        require(isinstance(value, str) and value, "Every retired ID needs a successor")
    return value


def safe_relative(value):
    path = Path(value)
    require(not path.is_absolute() and value and ".." not in path.parts and "\\" not in value,
            f"Unsafe relative path: {value}")
    return path
