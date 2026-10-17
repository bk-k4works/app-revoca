"""Extract the cited KICE reproduction; never invent source attestations."""
import csv
import io
import re
from pathlib import Path

from .common import SOURCE_URL, atomic_write, file_hash, now, read_json, require, sources, write_json


def parse_entry(raw, page):
    raw = " ".join(raw.split())
    parenthetical = re.findall(r"\(([^)]+)\)", raw)
    main = re.sub(r"\([^)]*\)", "", raw).strip()
    spellings = [part.strip().replace("*", "") for part in main.split("/")]
    require(all(re.fullmatch(r"[A-Za-z]+(?:[-' ][A-Za-z]+)*", part) for part in spellings),
            f"Unparsed source entry on PDF page {page}: {raw}")
    stars = re.search(r"\*+", main.split("/")[0])
    marker = stars.group() if stars else ""
    # Parentheses describe family members, not interchangeable spelling answers.
    related = [v.strip().replace("*", "") for group in parenthetical
               for v in re.split(r"[,/]", group) if v.strip()]
    return dict(headword=spellings[0], variants="|".join(spellings[1:]),
                elementary=str(marker == "*").lower(), source_page=page,
                source_marker=marker, related_forms="|".join(related), original=raw)


def extract(pdf, output, start=7, end=36, expected=3000):
    import pdfplumber
    rows, pending = [], None
    with pdfplumber.open(pdf) as document:
        require(end <= len(document.pages), "Source page range exceeds PDF")
        for number in range(start, end + 1):
            page = document.pages[number - 1]
            # The linked KICE PDF is three-column (not the curriculum book itself).
            for left, right in [(65, 225), (225, 375), (375, 555)]:
                text = page.crop((left, 80, right, 770)).extract_text() or ""
                for line in text.splitlines():
                    line = line.strip()
                    if not line or re.fullmatch(r"[A-Z]", line) or "기본 어휘 목록" in line:
                        continue
                    if pending and (line.startswith("(") or pending[0].count("(") > pending[0].count(")")
                                    or pending[0].endswith("/")):
                        pending = (pending[0] + " " + line, pending[1])
                    else:
                        if pending:
                            rows.append(parse_entry(*pending))
                        pending = (line, number)
        if pending:
            rows.append(parse_entry(*pending))
    require(len(rows) == expected, f"Expected {expected} entries, extracted {len(rows)}")
    require(len({r['headword'] for r in rows}) == len(rows), "Duplicate source headwords")
    require(sum(r['source_marker'] == '*' for r in rows) == 800, "Expected 800 elementary entries")
    require(sum(r['source_marker'] == '**' for r in rows) == 1200, "Expected 1200 common-course entries")
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
    atomic_write(output, buffer.getvalue())
    manifest_path = Path(output).with_suffix(".manifest.json")
    previous = read_json(manifest_path, {})
    sha = file_hash(output)
    manifest = {
        "sourceList": "curriculum_2022_basic", "sourceUrl": SOURCE_URL,
        "documentTitle": "2022 개정 교육과정에 따른 영어 어휘 검색 프로그램 (KICE Word Lister)",
        "originalCitation": "교육부 고시 제2022-33호 [별책 14] pp.254–290",
        "pageNumbering": "1-based physical pages of linked KICE PDF (7–36)",
        "pdfSha256": file_hash(pdf), "csvSha256": sha, "count": len(rows),
        "elementaryCount": 800, "commonCourseCount": 1200,
        "extractedAt": now(), "status": "awaiting_two_human_checks",
        "checks": previous.get("checks", []) if previous.get("csvSha256") == sha else [],
    }
    write_json(manifest_path, manifest)
    return manifest


def attest(csv_path, reviewer, note):
    path = Path(csv_path).with_suffix(".manifest.json")
    manifest = read_json(path)
    require(manifest is not None, "Extract the source first")
    current_hash = file_hash(csv_path)
    if current_hash != manifest['csvSha256']:
        rows = sources(csv_path)
        require(len(rows) == 3000 and sum(r['elementary'] for r in rows.values()) == 800
                and sum(r['source_marker'] == '**' for r in rows.values()) == 1200,
                'Corrected source must retain the documented 3000/800/1200 counts')
        manifest.setdefault('revisionHistory', []).append({'csvSha256': manifest['csvSha256'], 'checks': manifest['checks']})
        manifest.update(csvSha256=current_hash, checks=[], status='awaiting_two_human_checks')
    require(reviewer.strip() and note.strip(), "Reviewer identity and comparison note required")
    require(reviewer not in {c['reviewer'] for c in manifest['checks']}, "A different reviewer is required")
    manifest["checks"].append(dict(reviewer=reviewer, reviewedAt=now(), note=note,
                                   csvSha256=manifest["csvSha256"]))
    if len(manifest["checks"]) >= 2:
        manifest["status"] = "human_verified"
    write_json(path, manifest)
    return manifest


def require_verified(csv_path):
    manifest = read_json(Path(csv_path).with_suffix(".manifest.json"), {})
    sha = file_hash(csv_path)
    reviewers = {c["reviewer"] for c in manifest.get("checks", []) if c.get("csvSha256") == sha}
    require(manifest.get("csvSha256") == sha and len(reviewers) >= 2
            and manifest.get("status") == "human_verified", "Source requires two human comparisons of the current CSV")
    return manifest
