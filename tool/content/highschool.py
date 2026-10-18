"""High-school track: our own tiers, order and authored text over a headword list.

Elementary-marked words form their own 'familiar' tier that teaches extended
meanings; their first meanings are kept aside in content/highschool/v1/reserve/.

Only the headword list of the provided high-school book is used. Its meanings,
examples, translations, Day/Half order and page layout are never copied into
the source CSV or the app package. Tiers come from the public curriculum list
and the order inside a tier comes from public word-frequency data (wordfreq).
"""
import csv
import io
import os
import re
import tempfile
from pathlib import Path

from .build import create_database
from .common import (CONTENT, SOURCE, atomic_write, digest, file_hash, now, read_json, read_jsonl,
                     require, schema_validate, sources, write_json, write_jsonl)
from .validate import HIGH, exclusions, normalize_meaning, validate_records

HS_SOURCE = CONTENT / 'sources/highschool_v1.csv'
# Display forms for senses whose list headword is not how the word is written there
# (proper nouns, plural-only senses, the standard form of a phrase), keyed by
# headword|pos|slug. The list key and sense IDs stay; the app shows the form and
# accepts it as a spelling for that sense only.
DISPLAY_FORMS = CONTENT / 'highschool/v1/display_forms.json'
HS_PROVENANCE = CONTENT / 'sources/highschool_v1.provenance.json'
LIST_BOOK = 'sarang-csat-2000'
TIERS = {'basic': '고교 기본', 'familiar': '아는 단어, 새로운 뜻', 'core': '고교 핵심', 'phrase': '핵심 숙어',
         'advanced': '수능 심화'}
COMMON_ZIPF = 4.0  # Outside the curriculum list but common enough for the core tier
# Curriculum variants that are separate words, not alternative spellings of the headword.
NOT_SPELLINGS = {'technic'}
DECK_SIZE = 20
MIN_DECK = 5  # A shorter trailing chunk joins the previous deck instead of standing alone
COLUMNS = ['headword', 'variants', 'elementary', 'source_page', 'source_marker',
           'related_forms', 'original', 'tier', 'rank', 'zipf']
COURSES = [
    {'id': 'high', 'title': '고등 영단어', 'status': 'available',
     'tiers': [{'id': k, 'title': v, 'unit': '개' if k == 'phrase' else '단어'} for k, v in TIERS.items()]},
    {'id': 'middle', 'title': '중학 영단어', 'status': 'comingSoon', 'tiers': []},
]


def zipf(word):
    from wordfreq import zipf_frequency
    return zipf_frequency(word, 'en')


def tier_of(match, curriculum, frequency, word=''):
    if ' ' in word:
        # Multiword frequency is overestimated, so phrases get their own tier.
        return 'phrase'
    if match['kind'] == 'exact':
        # Elementary-marked words are taught for their extended exam meanings, not first meanings.
        marker = curriculum[match['headwords'][0]]['source_marker']
        return {'*': 'familiar', '**': 'basic'}.get(marker, 'core')
    if match['kind'] == 'variant_or_related':
        return 'core'
    return 'core' if frequency >= COMMON_ZIPF else 'advanced'


def build_source(entries_path, output=HS_SOURCE, provenance=HS_PROVENANCE, curriculum_path=SOURCE):
    curriculum = sources(curriculum_path)
    entries = [e for e in read_jsonl(entries_path) if e['bookId'] == LIST_BOOK]
    require(len(entries) == 2000, f'Expected 2,000 list entries, found {len(entries)}')
    rows, links = [], {}
    for entry in entries:
        word = entry['normalizedHeadword']
        require(word not in links, f'Duplicate list headword: {word}')
        match, frequency = entry['curriculumMatch'], zipf(word)
        base = curriculum.get(word) if match['kind'] == 'exact' else None
        rows.append({'headword': word, 'variants': '|'.join(base['variants']) if base else '',
                     'elementary': 'false', 'source_page': str(base['source_page']) if base else '0',
                     'source_marker': base['source_marker'] if base else '',
                     'related_forms': '|'.join(base['related_forms']) if base else '',
                     'original': word, 'tier': tier_of(match, curriculum, frequency, word),
                     'zipf': f'{frequency:.2f}'})
        links[word] = {'entryId': entry['id'], 'contentHash': entry['contentHash'], 'curriculumMatch': match}
    order = list(TIERS)
    rows.sort(key=lambda r: (order.index(r['tier']), -float(r['zipf']), r['headword']))
    for rank, row in enumerate(rows, 1):
        row['rank'] = str(rank)
    stream = io.StringIO()
    writer = csv.DictWriter(stream, COLUMNS, lineterminator='\n')
    writer.writeheader()
    writer.writerows(rows)
    atomic_write(output, stream.getvalue())
    counts = {t: sum(r['tier'] == t for r in rows) for t in TIERS}
    write_json(provenance, {
        'note': ('표제어 목록만 참조했다. 교재의 뜻풀이·예문·번역·Day 순서·쪽 구성은 이 목록과 앱 패키지에 넣지 않는다. '
                 '단계는 교육과정 대표 목록 표시, 순서는 wordfreq 빈도로 정했다. 이 파일은 로컬 대조용이며 앱에 포함하지 않는다.'),
        'listBook': LIST_BOOK, 'entriesSha256': file_hash(entries_path),
        'curriculumSha256': file_hash(curriculum_path), 'outputSha256': file_hash(output),
        'commonZipf': COMMON_ZIPF, 'tierCounts': counts, 'createdAt': now(), 'headwords': links})
    return {'headwords': len(rows), 'tiers': counts}


def display_forms(path=DISPLAY_FORMS):
    return read_json(path) if Path(path).exists() else {}


def hs_sources(source_path=HS_SOURCE, forms_path=DISPLAY_FORMS):
    """Source rows where a display form that differs beyond case counts as a variant spelling."""
    rows = sources(source_path)
    for key, form in display_forms(forms_path).items():
        word = key.split('|')[0]
        if word in rows and form.lower() != word and form not in rows[word]['variants']:
            rows[word] = {**rows[word], 'variants': [*rows[word]['variants'], form]}
    return rows


def lexicon_rows(source_path=HS_SOURCE, curriculum_path=SOURCE):
    """Example-vocabulary scope: curriculum list plus the high-school list."""
    return {**sources(curriculum_path), **hs_sources(source_path)}


def parse_authored(path, rows):
    """Pipe rows: headword|pos|slug|meaning|explanation|collocation|collocationKo|en1|ko1|en2|ko2[|syn,..]."""
    path = Path(path)
    files = sorted(path.glob('*.txt')) if path.is_dir() else [path]
    lines = [(f'{f.name}:{n}', line) for f in files for n, line in enumerate(f.read_text().splitlines(), 1)]
    entries = {}
    # A display form belongs to one sense; the headword's other senses do not accept it.
    forms = {tuple(k.split('|')): v for k, v in display_forms().items()}
    others = {}
    for number, line in lines:
        if line.strip() and not line.startswith('#'):
            key = tuple(line.split('|')[:3])
            others[key] = {f for k, f in forms.items() if k[0] == key[0] and k != key}
    for number, line in lines:
        if not line.strip() or line.startswith('#'):
            continue
        fields = line.split('|')
        require(len(fields) in {11, 12}, f'Line {number}: expected 11 or 12 fields')
        word, pos, slug, meaning, explanation, collocation, collocation_ko, en1, ko1, en2, ko2 = fields[:11]
        synonyms = [s for s in fields[11].split(',') if s] if len(fields) == 12 else []
        require(word in rows, f'Line {number}: unknown high-school headword {word}')
        entry = entries.setdefault(word, {'headword': word, 'senseCandidates': [], 'flags': []})
        primary = not entry['senseCandidates']
        meanings = [m.strip() for m in meaning.split(';') if m.strip()]
        entry['senseCandidates'].append({
            'pos': pos, 'senseSlug': slug, 'meaningKo': meanings[0], 'meaningKoAlt': meanings[1:],
            'whyPrimary': '수능·내신 지문에서 먼저 익힐 대표 의미예요.' if primary else '시험 지문에 자주 나오는 확장 의미예요.',
            'isPrimaryProposal': primary, 'explanationKo': explanation,
            'collocation': collocation, 'collocationKo': collocation_ko,
            'examples': [{'en': en1, 'ko': ko1}, {'en': en2, 'ko': ko2}],
            'acceptedSpellings': [word, *(v for v in rows[word]['variants'] if v not in NOT_SPELLINGS
                                          and v not in others.get((word, pos, slug), ()))],
            'confusableHeadwords': [],
            'nearSynonymHeadwords': synonyms})
    for entry in entries.values():
        if len(entry['senseCandidates']) == 1:
            entry['flags'].append('single_sense_candidate')
        errors = schema_validate(entry, 'generation')
        require(not errors, f"{entry['headword']}: {'; '.join(errors)}")
    return list(entries.values())


def authored_hash(path):
    path = Path(path)
    files = sorted(path.glob('*.txt')) if path.is_dir() else [path]
    return digest({f.name: file_hash(f) for f in files})


def draft(authored, output, source_path=HS_SOURCE, author='claude-session'):
    rows = hs_sources(source_path)
    entries = parse_authored(authored, rows)
    generation = {'model': author, 'method': 'local-authoring', 'promptVersion': 'highschool_v1',
                  'generatedAt': now(), 'authoredFileSha256': authored_hash(authored),
                  'schemaHash': digest(read_json(CONTENT / 'schema/generation.schema.json')),
                  'sourceHash': digest(rows), 'externalApiUsed': False}
    records = [{'headword': e['headword'], 'data': e, 'status': 'draft', 'source': rows[e['headword']],
                'generation': generation} for e in entries]
    checked = validate_records(records, rows, HIGH, lexicon_rows(source_path))
    write_jsonl(output, checked)
    failed = [r for r in checked if r['status'] != 'auto_checked']
    warned = [r for r in checked if r['autoValidation']['warnings']]
    return {'headwords': len(checked), 'senses': sum(len(e['senseCandidates']) for e in entries),
            'failed': {r['headword']: r['autoValidation']['errors'] for r in failed},
            'warnings': {r['headword']: r['autoValidation']['warnings'] for r in warned
                         if any('single' not in w.lower() for w in r['autoValidation']['warnings'])}}


def slug(word):
    return re.sub(r'[^a-z0-9]+', '-', word.lower()).strip('-')


def make_tier_decks(senses, rows, size=DECK_SIZE):
    """Decks of `size` headwords in tier/frequency order; every sense of a headword stays together."""
    by_word = {}
    for sense in senses:
        by_word.setdefault(sense['headword'], []).append(sense)
    decks = []
    for tier, title in TIERS.items():
        words = sorted((w for w in by_word if rows[w]['tier'] == tier), key=lambda w: int(rows[w]['rank']))
        chunks = [words[i:i + size] for i in range(0, len(words), size)]
        if len(chunks) > 1 and len(chunks[-1]) < MIN_DECK:
            chunks[-2:] = [chunks[-2] + chunks[-1]]
        for number, chunk in enumerate(chunks, 1):
            ids = [s['id'] for w in chunk for s in by_word[w]]
            unit = '개 표현' if tier == 'phrase' else '단어'
            decks.append({'id': f'hs-{tier}-{number:03}', 'title': f'{title} {number:02}',
                          'subtitle': f'{len(chunk)}{unit} · 뜻 {len(ids)}개', 'wordIds': ids})
    return decks


def approved_only(senses, version):
    """Keep human-approved senses whose text matches the Codex-reviewed and approved hash."""
    from .hs_review import current_verdicts, ledger, senses as authored
    require(all(c.isalnum() or c in '.-_' for c in version) and not version.startswith('dev'),
            'Invalid release version')
    rows = {f"hs.{slug(r['headword'])}.{r['pos']}.{r['senseSlug']}": r for r in authored()}
    verdicts, decided = current_verdicts(), ledger()
    kept, pending, unreviewed = [], [], []
    for sense in senses:
        row = rows[sense['id']]
        decision = decided.get(row['key'])
        if row['key'] not in verdicts:
            unreviewed.append(sense['id'])
        if not decision or decision['inputHash'] != row['inputHash'] or decision['decision'] == 'needs_fix':
            pending.append(sense['id'])
        elif decision['decision'] == 'human_approved':
            kept.append({**sense, 'status': 'human_approved',
                         'review': {k: decision[k] for k in ('reviewer', 'decidedAt', 'note')},
                         'llmReview': {'reviewer': 'codex', 'verdict': verdicts[row['key']]['verdict'],
                                       'inputHash': row['inputHash']} if row['key'] in verdicts else None})
    require(not unreviewed, f'Codex 독립 검토가 없는 뜻 {len(unreviewed)}개: {unreviewed[:5]}')
    require(not pending, f'사람 결정이 없거나 수정 대기인 뜻 {len(pending)}개: {pending[:5]}')
    require(kept, 'No approved senses')
    return kept


def build_preview(drafts, output, source_path=HS_SOURCE, release_version=None):
    rows = hs_sources(source_path)
    forms = display_forms()
    records = read_jsonl(drafts)
    require(records, 'No drafts')
    checked = validate_records(records, rows, HIGH, lexicon_rows(source_path))
    failed = [r['headword'] for r in checked if r['status'] != 'auto_checked']
    require(not failed, f'Automatic checks failed: {", ".join(failed)}')
    require(all(r['contentHash'] == old.get('contentHash') for r, old in zip(checked, records)), 'Stale drafts')
    senses = []
    for original, record in zip(records, checked):
        for candidate in record['data']['senseCandidates']:
            senses.append({**candidate, 'id': f"hs.{slug(record['headword'])}.{candidate['pos']}.{candidate['senseSlug']}",
                           'headwordId': slug(record['headword']), 'headword': record['headword'],
                           'term': forms.get(f"{record['headword']}|{candidate['pos']}|{candidate['senseSlug']}",
                                             record['headword']),
                           'source': record['source'], 'generation': original['generation'],
                           'status': 'auto_checked', 'review': None, 'llmReview': None,
                           'contentHash': digest(candidate), 'draftInputHash': record['contentHash'],
                           'selectedExampleIndex': 0, 'flags': record['data']['flags'], 'distractorExclusions': []})
    require(len({s['id'] for s in senses}) == len(senses), 'Duplicate sense IDs')
    if release_version:
        senses = approved_only(senses, release_version)
        records = [r for r in records if any(s['headword'] == r['headword'] for s in senses)]
    blocked = exclusions(senses)
    short = []
    for sense in senses:
        sense['distractorExclusions'] = blocked[sense['id']]
        options = {normalize_meaning(s['meaningKo']) for s in senses
                   if s['pos'] == sense['pos'] and s['id'] != sense['id'] and s['id'] not in blocked[sense['id']]}
        if len(options) < 3:
            short.append(sense['id'])
    decks = make_tier_decks(senses, rows)
    planned = {t: sum(r['tier'] == t for r in rows.values()) for t in TIERS}
    courses = [{**c, 'tiers': [{**t, 'planned': planned[t['id']],
                                'authored': sum(rows[r['headword']]['tier'] == t['id'] for r in records)}
                               for t in c['tiers']]} for c in COURSES]
    fingerprint = digest({'senses': senses, 'decks': decks, 'courses': courses})
    metadata = {'contentVersion': release_version or 'dev-high-' + fingerprint[:12],
                'developmentOnly': not release_version, 'track': 'high',
                'courses': courses, 'idMigrations': {}, 'audioPacks': [], 'headwordCount': len(records),
                'senseCount': len(senses), 'exampleCount': sum(len(s['examples']) for s in senses),
                'humanApproved': sum(s['status'] == 'human_approved' for s in senses),
                'inputSha256': file_hash(drafts), 'sparseChoiceSenseIds': short,
                'reviewMethod': 'codex-independent+human' if release_version else 'auto-check-only',
                'independentModel': bool(release_version)}
    output = Path(output)
    require(not output.exists(), 'Use a new preview output directory')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        staging = Path(temporary) / 'package'
        staging.mkdir()
        create_database(staging / 'content.sqlite', senses, decks, metadata, [])
        catalog = {**metadata, 'buildHash': fingerprint, 'deckCount': len(decks),
                   'databaseSha256': file_hash(staging / 'content.sqlite')}
        write_json(staging / 'catalog.json', catalog)
        write_json(staging / 'id_migrations.json', {})
        os.replace(staging, output)
    return {k: catalog[k] for k in ('contentVersion', 'headwordCount', 'senseCount', 'exampleCount', 'deckCount')}
