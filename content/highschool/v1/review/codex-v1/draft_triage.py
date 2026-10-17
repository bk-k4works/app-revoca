"""Turn Codex suggestions of one batch into a triage draft (hs_patch format).

Lines that cannot be applied verbatim are written as '# MANUAL' comments so a
person (or Claude) decides them. The draft is edited by hand before applying.
"""
import json
import re
import sys
from pathlib import Path

base = Path(__file__).parent
FIELD = {'meaning': 'meaning', 'explanation': 'expl', 'collocationKo': 'colko',
         'en1': 'en1', 'ko1': 'ko1', 'en2': 'en2', 'ko2': 'ko2'}
INSTRUCTION = re.compile(r'(세요|하세요|주세요|빼세요|바꾸세요|고치세요|넣으세요)\.?$')
QUOTED = re.compile(r"[‘'\"“]([^’'\"”]+)[’'\"”]")
slugs = {}
for f in sorted((base / '../../authored').glob('*.txt')):
    for line in f.read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            p = line.split('|')
            slugs.setdefault((p[0], p[2]), set()).add(p[1])


def unwrap(s):
    s = s.strip()
    m = re.match(r'^(?:예:\s*)?(?:[^“"]*?를\s*)?[“"](.+?)[”"]\s*(?:\(\d+단어\))?\s*(?:으로|로)\s*바꾸세요\.?$', s)
    return m.group(1).strip() if m else s


def key_parts(key):
    word, pos, slug = key.strip('[]').split('|')
    return word, slug if len(slugs.get((word, slug), ())) < 2 else f'{slug}@{pos}'


for name in sys.argv[1:]:
    d = json.loads((base / 'results' / f'{name}.json').read_text())
    out = [f'# {name} — Codex 제안 초안. 확인 후 수정·삭제한다.']
    for item in d['items']:
        if item['verdict'] == 'ok':
            continue
        word, slug = key_parts(item['senseKey'])
        tag = f"Codex {item['verdict']} 수용"
        for issue in item['issues']:
            s, f = issue['suggestion'].strip(), issue['field']
            pair = re.search(r'[“"](.+?)[”"]\s*(?:으로|로)\s*바꾸세요\.\s*번역은\s*[“"](.+?)[”"]\s*(?:으로|로)\s*바꾸세요', s)
            if pair and f in ('en1', 'en2'):
                out.append('\t'.join(['EDIT', word, slug, f, pair.group(1).strip(), tag, reason]))
                out.append('\t'.join(['EDIT', word, slug, 'ko' + f[-1], pair.group(2).strip(), tag, '예문 교체에 맞춘 번역']))
                continue
            s = unwrap(s)
            reason = issue['problem'].replace('\t', ' ')
            if f in ('en1', 'en2') and ' / ' in s:
                en, ko = s.split(' / ', 1)
                out.append('\t'.join(['EDIT', word, slug, f, unwrap(en), tag, reason]))
                out.append('\t'.join(['EDIT', word, slug, 'ko' + f[-1], unwrap(ko), tag, '예문 교체에 맞춘 번역']))
            elif f in ('collocation', 'collocationKo') and ' = ' in s:
                col, colko = s.split(' = ', 1)
                out.append('\t'.join(['EDIT', word, slug, 'col', col.strip(), tag, reason]))
                out.append('\t'.join(['EDIT', word, slug, 'colko', colko.strip(), tag, '연어 교체에 맞춘 번역']))
            elif f in FIELD and not INSTRUCTION.search(s):
                out.append('\t'.join(['EDIT', word, slug, FIELD[f], s, tag, reason]))
            elif f == 'meaning' and QUOTED.search(s):
                out.append('\t'.join(['EDIT', word, slug, 'meaning', QUOTED.search(s).group(1), tag, reason]))
            else:
                out.append(f"# MANUAL {item['senseKey']} [{f}] {reason} → {s}")
    edited = {}
    for line in out[1:]:
        p = line.split('\t')
        if p[0] == 'EDIT':
            edited.setdefault((p[1], p[2]), set()).add(p[3])
    for (word, slug), fields in edited.items():
        for n in '12':
            if f'en{n}' in fields and f'ko{n}' not in fields:
                out.append(f'# NEEDKO {word} {slug} ko{n}')
    for m in d['missingSenses']:
        out.append(f"# MISSING {m['headword']}: {m['reason']} → {m['suggestion']}")
    (base / 'triage' / f'{name.replace("batch-", "b")}.draft.tsv').write_text('\n'.join(out) + '\n')
    print(name, len(out) - 1)
