"""Finalize a triage draft: drop or override Codex lines, add lines, record declines.

python3 finalize.py b05 ops.txt
ops.txt lines:
  drop  word field            (word may be 'word slug' when needed: use word only if unique)
  set   word field value      (replace value of the drafted line; reason gets '일부 수용')
  add   <full hs_patch line with tabs>
  decline key<TAB>kind<TAB>reason
"""
import sys
from pathlib import Path

base = Path(__file__).parent / 'triage'
name, ops = sys.argv[1], (Path(sys.argv[2]).read_text().splitlines() if len(sys.argv) > 2 else [])
lines = [l for l in (base / f'{name}.draft.tsv').read_text().splitlines() if l and not l.startswith('#')]
declined = []
for op in ops:
    if not op.strip():
        continue
    kind, _, rest = op.partition(' ')
    if kind == 'add':
        lines.append(rest)
    elif kind == 'decline':
        declined.append(rest)
    else:
        word, field, *value = rest.split(' ', 2) if kind == 'set' else rest.split(' ', 1) + []
        w, _, sl = word.replace('_', ' ').partition('/')
        hits = [i for i, l in enumerate(lines) if l and l.split('\t')[1] == w and l.split('\t')[3] == field
                and (not sl or l.split('\t')[2] == sl)]
        assert len(hits) == 1, f'{op}: {len(hits)} matches'
        if kind == 'drop':
            lines[hits[0]] = None
        else:
            p = lines[hits[0]].split('\t')
            p[4], p[5] = value[0], p[5].replace('수용', '일부 수용')
            lines[hits[0]] = '\t'.join(p)
keep, seen = [], set()
for l in reversed([l for l in lines if l]):
    p = l.split('\t')
    k = (p[1], p[2], p[3]) if p[0] == 'EDIT' else (l,)
    if k not in seen:
        seen.add(k)
        keep.append(l)
lines = list(reversed(keep))
(base / f'{name}.tsv').write_text('\n'.join(l for l in lines if l) + '\n')
if declined:
    (base / f'{name}-declined.tsv').write_text('\n'.join(declined) + '\n')
(base / f'{name}.draft.tsv').unlink()
print(name, sum(1 for l in lines if l), 'lines', len(declined), 'declined')
