"""Independent Codex review of the authored high-school rows.

Batches carry each sense with an input hash, so a verdict only applies to the
exact text it was given. Running `codex exec` happens outside this module; it
prepares batches and merges the returned verdicts.
"""
import json
import sys
from pathlib import Path

from .common import CONTENT, ROOT, digest

AUTHORED = CONTENT / 'highschool/v1/authored'
REVIEW = CONTENT / 'highschool/v1/review/codex-v1'
FIELDS = ['headword', 'pos', 'senseSlug', 'meaning', 'explanation', 'collocation', 'collocationKo',
          'en1', 'ko1', 'en2', 'ko2', 'synonyms']


def senses(root=AUTHORED):
    from .highschool import display_forms
    forms = display_forms()
    rows = []
    for f in sorted(Path(root).glob('*.txt')):
        for line in f.read_text().splitlines():
            if not line.strip() or line.startswith('#'):
                continue
            values = line.split('|') + ([''] if line.count('|') == 10 else [])
            row = dict(zip(FIELDS, values))
            row['key'] = f"{row['headword']}|{row['pos']}|{row['senseSlug']}"
            # A display form is reviewed with the text; senses without one keep their hash.
            form = {'display': forms[row['key']]} if row['key'] in forms else {}
            row['inputHash'] = digest({**{k: row[k] for k in FIELDS}, **form})[:16]
            row['file'] = f.name
            rows.append(row)
    return rows


def batches(size=100, root=AUTHORED):
    rows = senses(root)
    heads = list(dict.fromkeys(r['headword'] for r in rows))
    for start in range(0, len(heads), size):
        chunk = set(heads[start:start + size])
        yield [r for r in rows if r['headword'] in chunk]


def render(batch):
    lines = []
    for r in batch:
        lines.append(f"[{r['key']}] hash={r['inputHash']}\n"
                     f"  뜻: {r['meaning']}\n  설명: {r['explanation']}\n"
                     f"  연어: {r['collocation']} = {r['collocationKo']}\n"
                     f"  예문1: {r['en1']} / {r['ko1']}\n  예문2: {r['en2']} / {r['ko2']}"
                     + (f"\n  유의어(오답 제외): {r['synonyms']}" if r['synonyms'] else ''))
    return '\n'.join(lines)


def prepare(out=REVIEW, size=100):
    out = Path(out)
    (out / 'batches').mkdir(parents=True, exist_ok=True)
    manifest = []
    for n, batch in enumerate(batches(size), 1):
        name = f'batch-{n:02d}'
        (out / 'batches' / f'{name}.txt').write_text(render(batch) + '\n')
        manifest.append({'batch': name, 'senses': [{'key': r['key'], 'inputHash': r['inputHash']} for r in batch]})
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n')
    return {'batches': len(manifest), 'senses': sum(len(m['senses']) for m in manifest)}


def merge(out=REVIEW):
    """Join Codex verdicts to the manifest; report missing, stale and unknown items."""
    out = Path(out)
    manifest = json.loads((out / 'manifest.json').read_text())
    current = {r['key']: r['inputHash'] for r in senses()}
    verdicts, problems = [], []
    for m in manifest:
        path = out / 'results' / f"{m['batch']}.json"
        if not path.exists():
            problems.append(f"{m['batch']}: no result")
            continue
        result = json.loads(path.read_text())
        given = {s['key']: s['inputHash'] for s in m['senses']}
        seen = set()
        for item in result['items']:
            key = item['senseKey'] = item['senseKey'].strip().strip('[]')
            if key not in given:
                problems.append(f"{m['batch']}: unknown {key}")
                continue
            seen.add(key)
            if item['inputHash'] != given[key]:
                problems.append(f"{m['batch']}: hash mismatch {key}")
            verdicts.append({**item, 'batch': m['batch'], 'stale': current.get(key) != given[key]})
        problems += [f"{m['batch']}: missing {k}" for k in given if k not in seen]
        for missing in result.get('missingSenses', []):
            verdicts.append({'senseKey': missing['headword'], 'verdict': 'missing_sense', 'batch': m['batch'],
                             'issues': [{'field': 'sense', 'problem': missing['reason'],
                                         'suggestion': missing['suggestion']}], 'stale': False})
    (out / 'verdicts.jsonl').write_text(''.join(json.dumps(v, ensure_ascii=False) + '\n' for v in verdicts))
    counts = {}
    for v in verdicts:
        counts[v['verdict']] = counts.get(v['verdict'], 0) + 1
    return {'verdicts': len(verdicts), 'counts': counts, 'problems': problems}


if __name__ == '__main__':
    command = sys.argv[1]
    print(json.dumps(prepare() if command == 'prepare' else merge(), ensure_ascii=False, indent=1))


# ---- 사람 승인 -------------------------------------------------------------
HUMAN = CONTENT / 'highschool/v1/review/human'
DECISIONS = {'human_approved', 'needs_fix', 'rejected'}
MACHINE_REVIEWERS = {'codex', 'claude', 'gpt', 'llm', 'ai'}
CSV_FIELDS = ['senseKey', 'inputHash', 'tier', 'headword', 'pos', 'meaning', 'explanation', 'collocation',
              'en1', 'ko1', 'en2', 'ko2', 'codexVerdict', 'codexNotes', 'decision', 'reviewer', 'note']


def current_verdicts(out=REVIEW):
    """Latest Codex verdict per sense key whose hash matches the current text."""
    current = {r['key']: r['inputHash'] for r in senses()}
    found = {}
    for path in sorted(Path(out).glob('**/verdicts*.jsonl')):
        for line in path.read_text().splitlines():
            v = json.loads(line)
            if v.get('verdict') != 'missing_sense' and current.get(v['senseKey']) == v.get('inputHash'):
                found[v['senseKey']] = v
    return found


def ledger(path=HUMAN / 'decisions.jsonl'):
    path = Path(path)
    if not path.exists():
        return {}
    latest = {}
    for line in path.read_text().splitlines():
        d = json.loads(line)
        latest[d['senseKey']] = d
    return latest


def export_human(output=HUMAN / 'review.csv'):
    from .highschool import HS_SOURCE
    from .common import sources
    from .review_io import write_csv
    tiers = {w: r['tier'] for w, r in sources(HS_SOURCE).items()}
    verdicts, decided = current_verdicts(), ledger()
    rows = []
    for r in senses():
        v = verdicts.get(r['key'])
        d = decided.get(r['key'])
        d = d if d and d['inputHash'] == r['inputHash'] else {}
        notes = ' / '.join(f"[{i['field']}] {i['problem']} → {i['suggestion']}" for i in (v or {}).get('issues', []))
        rows.append({'senseKey': r['key'], 'inputHash': r['inputHash'], 'tier': tiers.get(r['headword'], ''),
                     'headword': r['headword'], 'pos': r['pos'], 'meaning': r['meaning'],
                     'explanation': r['explanation'], 'collocation': f"{r['collocation']} = {r['collocationKo']}",
                     'en1': r['en1'], 'ko1': r['ko1'], 'en2': r['en2'], 'ko2': r['ko2'],
                     'codexVerdict': (v or {}).get('verdict', '검토 없음'), 'codexNotes': notes,
                     'decision': d.get('decision', ''), 'reviewer': d.get('reviewer', ''), 'note': d.get('note', '')})
    Path(output).parent.mkdir(parents=True, exist_ok=True)
    write_csv(output, rows, CSV_FIELDS)
    return {'rows': len(rows), 'codexReviewed': sum(r['codexVerdict'] != '검토 없음' for r in rows)}


def import_human(csv_path, path=HUMAN / 'decisions.jsonl'):
    """Append attributable human decisions; reject stale rows and machine reviewers."""
    from .common import now, require
    from .review_io import read_csv
    current = {r['key']: r['inputHash'] for r in senses()}
    new, seen = [], set()
    for row in read_csv(csv_path):
        decision = row.get('decision', '').strip()
        if not decision:
            continue
        key = row['senseKey']
        require(key in current and key not in seen, f'{key}: unknown or duplicate row')
        require(row['inputHash'] == current[key], f'{key}: 원고가 바뀐 뒤의 오래된 행이에요. 검수표를 다시 내보내세요.')
        require(decision in DECISIONS, f'{key}: decision은 {sorted(DECISIONS)} 중 하나여야 해요')
        reviewer = row.get('reviewer', '').strip()
        require(reviewer and reviewer.lower() not in MACHINE_REVIEWERS, f'{key}: 실제 검수자 이름이 필요해요')
        require(decision == 'human_approved' or row.get('note', '').strip(), f'{key}: 수정·반려에는 이유(note)가 필요해요')
        seen.add(key)
        new.append({'senseKey': key, 'inputHash': row['inputHash'], 'decision': decision, 'reviewer': reviewer,
                    'note': row.get('note', '').strip(), 'decidedAt': now()})
    require(new, '기록할 사람 결정이 없어요')
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a', encoding='utf-8') as stream:
        stream.writelines(json.dumps(d, ensure_ascii=False) + '\n' for d in new)
    return {'recorded': len(new), **status()}


def status():
    rows = senses()
    verdicts, decided = current_verdicts(), ledger()
    counts = {'senses': len(rows), 'codexReviewed': 0, 'human_approved': 0, 'needs_fix': 0, 'rejected': 0, 'pending': 0}
    for r in rows:
        counts['codexReviewed'] += r['key'] in verdicts
        d = decided.get(r['key'])
        counts[d['decision'] if d and d['inputHash'] == r['inputHash'] else 'pending'] += 1
    return counts


def prepare_pending(name='round2', size=150):
    """Batch only the senses whose current text has no Codex verdict (edited or new)."""
    covered = current_verdicts()
    pending = [r for r in senses() if r['key'] not in covered]
    out = REVIEW / name
    (out / 'batches').mkdir(parents=True, exist_ok=True)
    manifest = []
    for n, start in enumerate(range(0, len(pending), size), 1):
        batch = pending[start:start + size]
        label = f'{name}-{n:02d}'
        (out / 'batches' / f'{label}.txt').write_text(render(batch) + '\n')
        manifest.append({'batch': label, 'senses': [{'key': r['key'], 'inputHash': r['inputHash']} for r in batch]})
    (out / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + '\n')
    return {'pending': len(pending), 'batches': len(manifest)}


# ---- 웹 승인 화면 ---------------------------------------------------------
WEB = ROOT / 'build/review-web'


def web_id(key):
    """Document id for the web page's store: only letters, digits and `_ - . ~ : @ +` are allowed."""
    return key.replace(' ', '_').replace('|', '~')


def export_web(output=WEB / 'senses.json'):
    """Write the data file the approval page loads: every current sense with its Codex verdict."""
    from .highschool import HS_SOURCE, display_forms
    from .common import sources, now
    tiers = {w: r['tier'] for w, r in sources(HS_SOURCE).items()}
    forms = display_forms()
    verdicts, decided = current_verdicts(), ledger()
    items = []
    for r in senses():
        v = verdicts.get(r['key']) or {}
        d = decided.get(r['key'])
        items.append({'id': web_id(r['key']), 'key': r['key'], 'hash': r['inputHash'], 'part': r['file'][:-4],
                      'tier': tiers.get(r['headword'], ''),
                      'hw': forms.get(r['key'], r['headword']), 'pos': r['pos'],
                      'meaning': r['meaning'], 'expl': r['explanation'], 'col': r['collocation'],
                      'colKo': r['collocationKo'], 'ex': [[r['en1'], r['ko1']], [r['en2'], r['ko2']]],
                      'syn': r['synonyms'], 'codex': v.get('verdict', 'none'),
                      'issues': [[i['field'], i['problem'], i['suggestion']] for i in v.get('issues', [])],
                      'repo': d['decision'] if d and d['inputHash'] == r['inputHash'] else ''})
    ids = [i['id'] for i in items]
    assert len(ids) == len(set(ids)), 'web ids collide'
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'generatedAt': now(), 'items': items}, ensure_ascii=False, separators=(',', ':')))
    return {'output': str(output), 'senses': len(items), 'bytes': output.stat().st_size}


def import_web(json_path, path=HUMAN / 'decisions.jsonl'):
    """Record decisions saved from the approval page (its '결정 파일 받기' JSON).

    Each record names a reviewer label and the reviewer's opaque account id. Rows
    already in the ledger with the same decision and hash are skipped, so the
    same file can be imported again after more work."""
    current = {r['key']: r['inputHash'] for r in senses()}
    known = ledger(path)
    data = json.loads(Path(json_path).read_text())
    from .common import require
    new, stale = [], []
    for d in data['decisions']:
        key, decision = d['senseKey'], d['decision']
        require(key in current, f'{key}: 알 수 없는 뜻이에요')
        if d['inputHash'] != current[key]:
            stale.append(key)
            continue
        require(decision in DECISIONS, f'{key}: decision은 {sorted(DECISIONS)} 중 하나여야 해요')
        reviewer = (d.get('reviewer') or '').strip()
        require(reviewer and reviewer.lower() not in MACHINE_REVIEWERS and d.get('reviewerId'),
                f'{key}: 실제 검수자 이름과 계정이 필요해요')
        note = (d.get('note') or '').strip()
        require(decision == 'human_approved' or note, f'{key}: 수정·반려에는 이유(note)가 필요해요')
        old = known.get(key)
        if old and (old['inputHash'], old['decision'], old.get('note', '')) == (d['inputHash'], decision, note):
            continue
        new.append({'senseKey': key, 'inputHash': d['inputHash'], 'decision': decision, 'reviewer': reviewer,
                    'reviewerId': d['reviewerId'], 'note': note, 'decidedAt': d['decidedAt'], 'via': 'web'})
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('a', encoding='utf-8') as stream:
        stream.writelines(json.dumps(d, ensure_ascii=False) + '\n' for d in new)
    return {'recorded': len(new), 'stale': stale, **status()}
