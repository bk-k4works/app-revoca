"""Print non-ok Codex verdicts of one batch with the current row and the human edit it reviews."""
import json
import sys
from pathlib import Path

base = Path(__file__).parent
rows = {}
for f in sorted((base / '../../../authored').glob('*.txt')):
    for line in f.read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            p = line.split('|')
            rows[f'{p[0]}|{p[1]}|{p[2]}'] = p
human = {}
for line in (base / '../../human/round1/changes-round1.jsonl').read_text().splitlines():
    c = json.loads(line)
    if c.get('kind') == 'edit':
        human.setdefault((c['word'], c['slug']), []).append(c)
for name in sys.argv[1:]:
    d = json.loads((base / 'results' / f'{name}.json').read_text())
    print(f'### {name}', {v: sum(i['verdict'] == v for i in d['items']) for v in ('ok', 'minor', 'fix', 'reject')})
    for i in d['items']:
        if i['verdict'] == 'ok':
            continue
        key = i['senseKey'].strip('[]')
        p = rows.get(key, ['?'] * 11)
        print(f"\n{i['verdict'].upper()} {i['senseKey']} | 뜻 {p[3]} | 설명 {p[4]} | 연어 {p[5]}={p[6]}")
        print(f"   1) {p[7]} / {p[8]}\n   2) {p[9]} / {p[10]}")
        for c in human.get((p[0], p[2]), []):
            print(f"   H [{c['field']}] {c['reason']}: {c['old']} ⇒ {c['new']}")
        for x in i['issues']:
            print(f"   - [{x['field']}] {x['problem']}\n     → {x['suggestion']}")
    for m in d['missingSenses']:
        print(f"\nMISSING {m['headword']}: {m['reason']} → {m['suggestion']}")
