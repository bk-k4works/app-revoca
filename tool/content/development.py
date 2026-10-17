"""Reproducible, explicitly unapproved local previews; release gates stay intact."""
import json
import os
import shutil
import sqlite3
import tempfile
from pathlib import Path

from .build import create_database, make_decks
from .common import (CONTENT, SOURCE, digest, file_hash, read_json, read_jsonl,
                     require, sources, write_json)
from .validate import exclusions, normalize_meaning, validate_records


def build_preview(input_path, output, identity_path, source_path=SOURCE):
    records = read_jsonl(input_path)
    require(records and len({r['headword'] for r in records}) == len(records), 'Empty or duplicate preview input')
    identities = read_json(identity_path)
    registry = read_json(CONTENT / 'sense_registry.json')['ids']
    checked = validate_records(records, sources(source_path))
    senses, used = [], set()
    for original, record in zip(records, checked):
        review = original.get('llmReview', {})
        require(original.get('status') == 'llm_reviewed' and record['status'] == 'auto_checked', 'Preview requires checked, reviewed drafts')
        require(original.get('contentHash') == record['contentHash'] == review.get('inputHash'), 'Stale preview review')
        require(not review.get('criticalError') and review.get('severity') != 'fail', 'Failed content review')
        for candidate in record['data']['senseCandidates']:
            key = f"{record['headword']}.{candidate['pos']}.{candidate['senseSlug']}"
            identity = identities.get(key)
            if identity:
                sid = identity['id']
                require(identity.get('note') and registry.get(sid, {}).get('headword') == record['headword']
                        and registry[sid]['pos'] == candidate['pos'], 'Invalid legacy semantic identity')
                used.add(key)
            else:
                sid = f'preview.{key}'
            senses.append({**candidate, 'id': sid, 'headwordId': record['headword'],
                'headword': record['headword'], 'source': record['source'],
                'generation': original['generation'], 'status': 'llm_reviewed', 'review': None,
                'llmReview': review, 'contentHash': digest(candidate),
                'draftInputHash': record['contentHash'], 'selectedExampleIndex': 0,
                'flags': record['data']['flags'], 'distractorExclusions': []})
    require(used == set(identities), 'Unused legacy identity mapping')
    require(len({s['id'] for s in senses}) == len(senses), 'Duplicate preview sense IDs')
    blocked = exclusions(senses)
    short = []
    for sense in senses:
        sense['distractorExclusions'] = blocked[sense['id']]
        options = {normalize_meaning(s['meaningKo']) for s in senses
                   if s['pos'] == sense['pos'] and s['id'] != sense['id'] and s['id'] not in blocked[sense['id']]}
        if len(options) < 3:
            short.append(sense['id'])
    decks = make_decks(senses)
    for deck in decks:
        deck['id'] = 'preview-' + deck['id']
        deck['title'] = '파일럿 · ' + deck['title']
        deck['subtitle'] = '검수용 초안 · 의미별 카드'
    mappings = read_json(CONTENT / 'legacy_id_map.json')
    fingerprint = digest({'senses': senses, 'decks': decks, 'identities': identities, 'migrations': mappings})
    version = 'dev-pilot-' + fingerprint[:12]
    metadata = {'contentVersion': version, 'developmentOnly': True, 'idMigrations': mappings,
                'audioPacks': [], 'headwordCount': len(records), 'senseCount': len(senses),
                'exampleCount': sum(len(s['examples']) for s in senses), 'humanApproved': 0,
                'inputSha256': file_hash(input_path), 'sparseChoiceSenseIds': short,
                'reviewMethod': 'codex-local-review', 'independentModel': False}
    output = Path(output)
    existing = read_json(output / 'catalog.json', {})
    if existing:
        require(existing.get('buildHash') == fingerprint and existing.get('developmentOnly') is True,
                'Output already contains different content; choose a new output directory')
        require(file_hash(output / 'content.sqlite') == existing['databaseSha256'], 'Preview database changed')
        return existing
    require(not output.exists(), 'Use a new preview output directory')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        staging = Path(temporary) / 'package'
        staging.mkdir()
        create_database(staging / 'content.sqlite', senses, decks, metadata, [])
        catalog = {**metadata, 'buildHash': fingerprint, 'deckCount': len(decks),
                   'databaseSha256': file_hash(staging / 'content.sqlite')}
        write_json(staging / 'catalog.json', catalog)
        write_json(staging / 'id_migrations.json', mappings)
        os.replace(staging, output)
    return catalog


def install_preview(package, assets):
    package, assets = Path(package), Path(assets)
    catalog = read_json(package / 'catalog.json', {})
    require(catalog.get('developmentOnly') is True, 'Expected development preview')
    current = read_json(assets / 'catalog.json', {})
    require(not current or current.get('developmentOnly') is True, 'Cannot overwrite an installed release')
    require(file_hash(package / 'content.sqlite') == catalog['databaseSha256'], 'Preview database hash mismatch')
    with sqlite3.connect(f'file:{package / "content.sqlite"}?mode=ro', uri=True) as db:
        meta = {k: json.loads(v) for k, v in db.execute('SELECT key,value FROM metadata')}
        require(meta.get('developmentOnly') is True and meta['contentVersion'] == catalog['contentVersion'], 'Preview metadata mismatch')
    assets.mkdir(parents=True, exist_ok=True)
    for name in ('content.sqlite', 'id_migrations.json'):
        shutil.copy2(package / name, assets / name)
    write_json(assets / 'catalog.json', catalog)
    return {'installed': str(assets), 'contentVersion': catalog['contentVersion'], 'developmentOnly': True}
