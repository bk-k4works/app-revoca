"""Build a review queue from actual content and deterministic app quiz choices.

This reports work, never grants approval. A previous snapshot is an inventory,
not evidence that its items were reviewed; open findings must remain open.
"""
import json
import sqlite3
from pathlib import Path

from .common import ROOT, CONTENT, digest, file_hash, read_json, require, write_json, atomic_write
from .validate import normalize_meaning

CONTENT_FIELDS = ('id', 'headwordId', 'headword', 'pos', 'meaningKo', 'meaningKoAlt',
                  'explanationKo', 'collocation', 'collocationKo', 'examples',
                  'acceptedSpellings', 'source', 'flags', 'nearSynonymHeadwords', 'confusableHeadwords', 'distractorExclusions')


def rank(value):
    result = 2166136261
    # Match Dart UTF-16 codeUnits (IDs are normally ASCII).
    raw = value.encode('utf-16-le')
    for i in range(0, len(raw), 2):
        result = ((result ^ int.from_bytes(raw[i:i + 2], 'little')) * 16777619) & 0xffffffff
    return result


def choices_for(word, senses):
    meanings = {normalize_meaning(x) for x in [word['meaningKo'], *word['meaningKoAlt']]}
    others = [s for s in senses if s['id'] != word['id'] and s['pos'] == word['pos']
              and s['headwordId'] != word['headwordId']
              and s['id'] not in word['distractorExclusions'] and word['id'] not in s['distractorExclusions']
              and not meanings.intersection(normalize_meaning(x) for x in [s['meaningKo'], *s['meaningKoAlt']])]
    others.sort(key=lambda s: (abs(len(s['meaningKo']) - len(word['meaningKo'])),
                              rank(word['id'] + ':' + s['id']), s['id']))
    distinct = {}
    for sense in others:
        distinct.setdefault(normalize_meaning(sense['meaningKo']), sense)
    selected = [word, *list(distinct.values())[:3]]
    raw = word['id'].encode('utf-16-le')
    offset = sum(int.from_bytes(raw[i:i+2], 'little') for i in range(0, len(raw), 2)) % len(selected)
    return selected[offset:] + selected[:offset]


def rule_hash():
    return digest({str(p.relative_to(ROOT)): file_hash(p) for p in [
        ROOT / 'lib/domain/vocabulary.dart', ROOT / 'lib/ui/study_screen.dart',
        ROOT / 'tool/content/audit.py', ROOT / 'tool/content/validate.py',
        CONTENT / 'schema/generation.schema.json', CONTENT / 'sources/word_forms.json']})


def snapshot(senses, version, rules):
    items = {}
    for sense in senses:
        choices = choices_for(sense, senses)
        quiz = {'prompt': {'term': sense['headword'], 'pos': sense['pos'], 'collocation': sense['collocation']},
                'mode': 'multiple_choice' if len(choices) == 4 else 'self_assessment',
                'answerId': sense['id'],
                'choices': [{'id': c['id'], 'meaning': c['meaningKo']} for c in choices]}
        items[sense['id']] = {'contentHash': digest({k: sense.get(k) for k in CONTENT_FIELDS}),
                             'quizHash': digest(quiz), 'quiz': quiz,
                             'content': {k: sense.get(k) for k in CONTENT_FIELDS}}
    return {'schemaVersion': 1, 'contentVersion': version, 'ruleHash': rules, 'items': items,
            'notice': 'Inventory only. No human or model approval is inferred from a snapshot.'}


def compare(current, previous=None):
    previous = previous or {}
    old, new = previous.get('items', {}), current['items']
    rules_changed = bool(previous and (previous.get('schemaVersion') != current['schemaVersion']
                                      or previous.get('ruleHash') != current['ruleHash']))
    added = sorted(new.keys() - old.keys())
    removed = sorted(old.keys() - new.keys())
    changed = sorted(k for k in new.keys() & old.keys() if new[k]['contentHash'] != old[k]['contentHash'])
    quiz_changed = sorted(k for k in new.keys() & old.keys() if new[k]['quizHash'] != old[k]['quizHash'])
    return {'added': added, 'removed': removed, 'contentChanged': changed, 'quizChanged': quiz_changed,
            'rulesChanged': rules_changed,
            'contentReviewRequired': sorted(new if rules_changed else set(added + changed)),
            'quizReviewRequired': sorted(new if rules_changed else set(added + quiz_changed)),
            'notice': 'Carry unresolved findings forward separately; unchanged does not mean approved.'}


def run(package, output, previous=None):
    package, output = Path(package), Path(output)
    require(not output.exists(), 'Use a new audit directory to preserve earlier snapshots')
    catalog = read_json(package / 'catalog.json')
    require(file_hash(package / 'content.sqlite') == catalog['databaseSha256'], 'Database checksum mismatch')
    with sqlite3.connect(f'file:{package / "content.sqlite"}?mode=ro', uri=True) as db:
        senses = [json.loads(p) for p, in db.execute('SELECT payload FROM senses ORDER BY id')]
    current = snapshot(senses, catalog['contentVersion'], rule_hash())
    if previous:
        require(Path(previous).is_file(), 'Previous snapshot does not exist')
    prior = read_json(previous) if previous else None
    queue = compare(current, prior)
    write_json(output / 'snapshot.json', current)
    write_json(output / 'queue.json', queue)
    lines = ['# 콘텐츠·선택지 변경 검수', '',
             '이 목록은 검수 대상입니다. 스냅샷 생성이나 변경 없음은 승인으로 처리하지 않습니다.', '',
             f"- 내용 검수: {len(queue['contentReviewRequired'])}개 의미",
             f"- 선택지 검수: {len(queue['quizReviewRequired'])}개 문제",
             f"- 삭제: {len(queue['removed'])}개 / 규칙 변경: {queue['rulesChanged']}", '']
    for sid in sorted(set(queue['contentReviewRequired'] + queue['quizReviewRequired'])):
        item = current['items'][sid]
        c, q = item['content'], item['quiz']
        lines += [f"## {sid}", '', f"{c['headword']} · {c['pos']} · {c['meaningKo']}", '',
                  c['explanationKo'], '', f"{c['collocation']} — {c['collocationKo']}", '']
        for e in c['examples']:
            lines += [f"- {e['en']} / {e['ko']}"]
        lines += ['', '허용 철자: ' + ', '.join(c['acceptedSpellings']), '',
                  '직접 평가' if q['mode'] == 'self_assessment' else '선택지: ' + ' / '.join(
                      ('[정답] ' if x['id'] == sid else '') + x['meaning'] for x in q['choices']), '']
    atomic_write(output / 'review.md', '\n'.join(lines) + '\n')
    return {k: len(queue[k]) for k in ['added', 'removed', 'contentChanged', 'quizChanged',
                                      'contentReviewRequired', 'quizReviewRequired']}
