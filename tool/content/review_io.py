"""Spreadsheet round trips with content hashes and attributable human decisions."""
import copy
import csv
import io
import json
import math
import re
from pathlib import Path

from .common import (CONTENT, SOURCE, atomic_write, canonical, digest, now, read_json,
                     read_jsonl, require, resolve_id, schema_validate, sources, write_json, write_jsonl)
from .validate import exclusions, sense_hash, validate_records

EDITABLE = {'meaningKo', 'meaningKoAlt', 'explanationKo', 'collocation', 'collocationKo',
            'examples', 'acceptedSpellings', 'confusableHeadwords', 'nearSynonymHeadwords'}


def write_csv(path, rows, fields):
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=fields)
    writer.writeheader()
    for row in rows:
        writer.writerow({k: ("'" + v if isinstance(v, str) and v.startswith(('=', '+', '-', '@')) else v)
                         for k, v in row.items()})
    atomic_write(path, '\ufeff' + buffer.getvalue())


def read_csv(path):
    with open(path, encoding='utf-8-sig', newline='') as stream:
        return list(csv.DictReader(stream))


def export(input_path, output):
    records = read_jsonl(input_path)
    require(records and all(r['status'] == 'llm_reviewed' for r in records), 'Only LLM-reviewed records can enter human review')
    rows = []
    registry = read_json(CONTENT / 'sense_registry.json', {'primary': {}})
    existing = {s['headword']: s for s in read_jsonl(CONTENT / 'approved/senses.jsonl')}
    starter = {r['headword']: r['content'] for r in read_jsonl(CONTENT / 'gold/starter_examples.jsonl')}
    for record in records:
        data = record['data']
        require(record['contentHash'] == digest(data) == record['llmReview']['inputHash'], 'Stale LLM review')
        rows.append({
            'headword': record['headword'], 'inputHash': record['contentHash'],
            'senseIndex': next(i for i, s in enumerate(data['senseCandidates']) if s['isPrimaryProposal']),
            'exampleIndex': 0, 'candidatesJson': canonical(data['senseCandidates']),
            'severity': record['llmReview']['severity'], 'llmReviewJson': canonical(record['llmReview']),
            'reviewMethod': record['llmReview'].get('provenance', {}).get('method', 'api-review'),
            'autoWarningsJson': canonical(record['autoValidation']['warnings']),
            'editsJson': '{}', 'decision': '', 'reviewer': '', 'note': '',
            'identityConfirmed': '',
            'existingSenseId': registry['primary'].get(record['headword'], ''),
            'existingMeaningKo': existing.get(record['headword'], {}).get('meaningKo',
                starter.get(record['headword'], {}).get('meaning', '')),
        })
    write_csv(output, rows, list(rows[0]))
    return {'exported': len(rows), 'selectionIndexes': 'zero-based'}


def allocate(registry, headword, pos, slug):
    word_slug = re.sub(r'[^a-z0-9]+', '-', headword.lower()).strip('-')
    proposed = f'{word_slug}.{pos}.{slug}'
    if headword in registry['primary']:
        existing = registry['primary'][headword]
        identity = registry['ids'][existing]
        require(identity['pos'] == pos, f'{headword}: part of speech changed; issue a new sense and retire the old one explicitly')
        return existing  # Regeneration may suggest another slug; it cannot rename an issued ID.
    require(proposed not in registry['ids'], f'ID was already issued and cannot be reused: {proposed}')
    registry['ids'][proposed] = {'headword': headword, 'pos': pos, 'issuedAt': now()}
    registry['primary'][headword] = proposed
    return proposed


def retire(old, successor, registry_path=CONTENT / 'sense_registry.json', mapping_path=CONTENT / 'deprecated_ids.json'):
    registry = read_json(registry_path)
    mapping = read_json(mapping_path, {})
    require(old in registry['ids'] and successor in registry['ids'], 'Both IDs must have been issued')
    require(old != successor and old not in mapping, 'A retirement cannot be overwritten or point to itself')
    mapping[old] = successor
    for key in mapping:
        resolve_id(key, mapping)
    for word, current in list(registry['primary'].items()):
        if current == old:
            require(registry['ids'][successor]['headword'] == word, 'Primary successor must have the same headword')
            registry['primary'][word] = successor
    write_json(mapping_path, mapping)
    write_json(registry_path, registry)


def import_reviews(input_path, csv_path, output, approved_path,
                   source_path=SOURCE, registry_path=CONTENT / 'sense_registry.json'):
    originals = read_jsonl(input_path)
    by_word = {r['headword']: r for r in originals}
    require(len(by_word) == len(originals), 'Duplicate review records')
    registry = copy.deepcopy(read_json(registry_path, {'ids': {}, 'primary': {}}))
    approved = {r['id']: r for r in read_jsonl(approved_path)}
    decisions, to_validate, selections, seen = [], [], {}, set()
    csv_rows = read_csv(csv_path)
    rows_by_word = {row['headword']: row for row in csv_rows}
    for row in csv_rows:
        decision = row['decision'].strip()
        if not decision:
            continue
        word = row['headword']
        require(word in by_word and word not in seen, f'Unknown/duplicate reviewed headword: {word}')
        seen.add(word)
        record = copy.deepcopy(by_word[word])
        require(record['status'] == 'llm_reviewed', f'{word}: not ready for human review')
        require(row['inputHash'] == digest(record['data']) == record['contentHash'] == record['llmReview']['inputHash'],
                f'{word}: stale spreadsheet; export the current revision')
        require(decision in {'human_approved', 'needs_fix', 'rejected'}, f'{word}: invalid decision')
        require(row['reviewer'].strip(), f'{word}: reviewer identity required')
        index, example_index = int(row['senseIndex']), int(row['exampleIndex'])
        require(0 <= index < len(record['data']['senseCandidates']) and example_index in (0, 1), 'Invalid selection index')
        edits = json.loads(row['editsJson'] or '{}')
        require(isinstance(edits, dict) and edits.keys() <= EDITABLE, f'{word}: invalid edited fields')
        original_candidate = copy.deepcopy(record['data']['senseCandidates'][index])
        record['data']['senseCandidates'][index].update(edits)
        edited = [k for k in edits if edits[k] != original_candidate[k]]
        proposed_index = next(i for i, c in enumerate(record['data']['senseCandidates']) if c['isPrimaryProposal'])
        if index != proposed_index:
            edited.append('selectedSenseIndex')
        if example_index != 0:
            edited.append('selectedExampleIndex')
        record['humanReview'] = {'reviewer': row['reviewer'].strip(), 'reviewedAt': now(), 'decision': decision,
                                 'editedFields': edited, 'note': row['note'], 'inputHash': row['inputHash']}
        record['status'] = decision
        decisions.append(record)
        if decision == 'human_approved':
            to_validate.append(record)
            selections[word] = (index, example_index)
    require(decisions, 'No completed human decisions found')
    checks = validate_records(to_validate, sources(source_path))
    for record in checks:
        require(not record['autoValidation']['errors'], f"{record['headword']}: edited content failed S3: {record['autoValidation']['errors']}")
        index, example_index = selections[record['headword']]
        candidate = record['data']['senseCandidates'][index]
        if record['headword'] in registry['primary']:
            review_row = rows_by_word[record['headword']]
            require(review_row.get('identityConfirmed') == 'true',
                    f"{record['headword']}: confirm the existing sense identity with identityConfirmed=true; use explicit retirement for a different meaning")
        sense_id = allocate(registry, record['headword'], candidate['pos'], candidate['senseSlug'])
        require(sense_id not in read_json(CONTENT / 'deprecated_ids.json', {}), 'Cannot approve a retired ID')
        sense = {k: v for k, v in candidate.items() if k not in {'isPrimaryProposal', 'whyPrimary', 'senseSlug'}}
        sense.update(id=sense_id, headword=record['headword'], headwordId=record['headword'],
                     status='human_approved', selectedExampleIndex=example_index,
                     source=record['source'], generation=record['generation'],
                     flags=sorted(set(record['data']['flags'] + record['autoValidation']['flags'])),
                     distractorExclusions=[], reviewHistory=approved.get(sense_id, {}).get('reviewHistory', []))
        sense['contentHash'] = sense_hash(sense)
        sense['review'] = {**record['humanReview'], 'contentHash': sense['contentHash']}
        previous = approved.get(sense_id)
        if previous and previous['review'] not in sense['reviewHistory']:
            sense['reviewHistory'] = [*sense['reviewHistory'], previous['review']]
        errors = schema_validate(sense, 'sense')
        require(not errors, '; '.join(errors))
        approved[sense_id] = sense
    # A rejection/needs_fix of an existing headword revokes its publishable record.
    revoked = {r['headword'] for r in decisions if r['status'] != 'human_approved'}
    approved = {key: value for key, value in approved.items() if value['headword'] not in revoked}
    blocked = exclusions(list(approved.values()))
    for value in approved.values():
        value['distractorExclusions'] = blocked[value['id']]
    write_json(registry_path, registry)
    write_jsonl(approved_path, sorted(approved.values(), key=lambda r: r['id']))
    write_jsonl(output, decisions)
    summary = metrics(decisions)
    write_json(Path(output).with_suffix('.metrics.json'), summary)
    return summary


def metrics(decisions):
    total = len(decisions)
    accepted = [r for r in decisions if r['humanReview']['decision'] == 'human_approved']
    unedited = sum(not r['humanReview']['editedFields'] for r in accepted)
    return {'reviewed': total, 'approved': len(accepted), 'uneditedApproved': unedited,
            'uneditedApprovalRate': unedited / total if total else 0,
            'pilotTargetMet': total >= 100 and unedited / total >= .8,
            'needsFix': sum(r['humanReview']['decision'] == 'needs_fix' for r in decisions),
            'rejected': sum(r['humanReview']['decision'] == 'rejected' for r in decisions)}


def sample(senses, rate=.1):
    return sorted(senses, key=lambda r: digest(r['id']))[:math.ceil(len(senses) * rate)]


def export_secondary(approved_path, output):
    selected = sample(read_jsonl(approved_path))
    require(selected, 'No approved records')
    rows = [{'senseId': r['id'], 'contentHash': r['contentHash'], 'contentJson': canonical(r),
             'firstReviewer': r['review']['reviewer'], 'reviewer': '', 'agree': '', 'criticalError': '', 'note': ''}
            for r in selected]
    write_csv(output, rows, list(rows[0]))
    return {'sampleSize': len(rows)}


def import_secondary(approved_path, csv_path, output):
    selected = {r['id']: r for r in sample(read_jsonl(approved_path))}
    reviews = []
    for row in read_csv(csv_path):
        require(row['senseId'] in selected, 'Unknown secondary sample ID')
        sense = selected[row['senseId']]
        require(row['contentHash'] == sense_hash(sense) == sense['contentHash'], 'Stale secondary sample')
        require(row['reviewer'].strip() and row['reviewer'].strip() != sense['review']['reviewer'], 'Independent second reviewer required')
        require(row['agree'] in {'true', 'false'} and row['criticalError'] in {'true', 'false'}, 'Use true/false for secondary decisions')
        reviews.append({'senseId': row['senseId'], 'contentHash': row['contentHash'],
                        'reviewer': row['reviewer'].strip(), 'reviewedAt': now(),
                        'agree': row['agree'] == 'true', 'criticalError': row['criticalError'] == 'true', 'note': row['note']})
    require(len(reviews) == len(selected) == len({r['senseId'] for r in reviews}), 'Complete the entire distinct 10% sample')
    write_jsonl(output, reviews)
    return {'sampleSize': len(reviews), 'agreementRate': sum(r['agree'] for r in reviews) / len(reviews),
            'criticalErrors': sum(r['criticalError'] for r in reviews)}


