"""Apply review patches to authored files and write a change log.

Patch lines (tab-separated):
  EDIT<TAB>word<TAB>slug<TAB>field<TAB>new value<TAB>category<TAB>reason
  ADD<TAB>full pipe row<TAB>category<TAB>reason
Fields: meaning expl col colko en1 ko1 en2 ko2 syn
"""
import json
import sys
from pathlib import Path

FIELDS = {'meaning': 3, 'expl': 4, 'col': 5, 'colko': 6, 'en1': 7, 'ko1': 8, 'en2': 9, 'ko2': 10, 'syn': 11}
root = Path('content/highschool/v1/authored')
patches = [l for p in sys.argv[1:-1] for l in Path(p).read_text().splitlines() if l.strip() and not l.startswith('#')]
log_path = Path(sys.argv[-1])
files = {f: f.read_text().splitlines() for f in sorted(root.glob('*.txt'))}
index = {}
for f, lines in files.items():
    for i, line in enumerate(lines):
        if line.strip() and not line.startswith('#'):
            p = line.split('|')
            index.setdefault((p[0], p[2]), []).append((f, i, p[1]))


def locate(word, slug):
    slug, _, pos = slug.partition('@')
    hits = [h for h in index.get((word, slug), []) if not pos or h[2] == pos]
    assert len(hits) == 1, f'ambiguous or missing {word} {slug}@{pos}: {hits}'
    return hits[0][0], hits[0][1], slug


log = []
for patch in patches:
    parts = patch.split('\t')
    if parts[0] == 'EDIT':
        _, word, slug, field, new, category, reason = parts
        f, i, slug = locate(word, slug)
        p = files[f][i].split('|')
        k = FIELDS[field]
        while len(p) <= k:
            p.append('')
        old = p[k]
        if old == new:  # 이미 같은 값이면 건너뛴다
            continue
        p[k] = new
        if len(p) == 12 and not p[11]:
            p = p[:11]
        files[f][i] = '|'.join(p)
        log.append(dict(kind='edit', word=word, slug=slug, field=field, old=old, new=new, category=category, reason=reason, file=f.name))
    elif parts[0] == 'ADD':
        _, row, category, reason = parts
        p = row.split('|')
        assert len(p) in (11, 12), row
        assert not any(h[2] == p[1] for h in index.get((p[0], p[2]), [])), f'dup add {p[0]} {p[2]}'
        f, i, _ = max((h for key, hs in index.items() if key[0] == p[0] for h in hs), key=lambda x: x[1])
        files[f].insert(i + 1, row)
        for key, hs in index.items():
            index[key] = [(ff, ii + 1 if ff == f and ii > i else ii, pp) for ff, ii, pp in hs]
        index.setdefault((p[0], p[2]), []).append((f, i + 1, p[1]))
        log.append(dict(kind='add', word=p[0], slug=p[2], new=row, category=category, reason=reason, file=f.name))
    elif parts[0] == 'DEL':
        _, word, slug, category, reason = parts
        f, i, slug = locate(word, slug)
        index[(word, slug)] = [h for h in index[(word, slug)] if h[1] != i or h[0] != f]
        old = files[f][i]
        files[f][i] = None
        log.append(dict(kind='delete', word=word, slug=slug, old=old, category=category, reason=reason, file=f.name))
    else:
        raise SystemExit(f'bad patch: {patch}')
for f, lines in files.items():
    f.write_text('\n'.join(l for l in lines if l is not None) + '\n')
log_path.write_text('\n'.join(json.dumps(x, ensure_ascii=False) for x in log) + '\n')
print('applied', len(log))
