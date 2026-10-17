"""Approval-gated, versioned SQLite and per-deck audio packaging."""
import json
import os
import shutil
import sqlite3
import tempfile
import zipfile
from pathlib import Path

from .common import (CONTENT, SOURCE, canonical, digest, file_hash, read_json, read_jsonl,
                     require, resolve_id, safe_relative, sources, write_json)
from .ingest import require_verified
from .review_io import sample
from .tts import approved_senses, require_publishable
from .validate import exclusions, normalize_meaning, validate_records

POS_KO = {'n': '명사', 'v': '동사', 'adj': '형용사', 'adv': '부사', 'pron': '대명사',
          'prep': '전치사', 'conj': '접속사', 'det': '한정사', 'interj': '감탄사', 'aux': '조동사', 'phrase': '구'}


def make_decks(senses, size=20, ranks=None):
    ranks = ranks or {}
    decks = []
    for elementary, prefix, title in [(True, 'foundation', '기초 다지기'), (False, 'basic', '교육과정 기본기')]:
        remaining = [s for s in senses if s['source']['elementary'] == elementary]
        remaining.sort(key=lambda s: (ranks.get(s['headword'], float('inf')), s['headword'], s['id']))
        while remaining:
            chosen, counts = [], {}
            while remaining and len(chosen) < size:
                def cost(s):
                    conflicts = sum(c['id'] in s['distractorExclusions'] for c in chosen)
                    return conflicts, counts.get(s['pos'], 0), ranks.get(s['headword'], float('inf')), s['headword']
                best = min(remaining, key=cost)
                chosen.append(best)
                counts[best['pos']] = counts.get(best['pos'], 0) + 1
                remaining.remove(best)
            index = 1 + sum(d['id'].startswith(prefix) for d in decks)
            decks.append({'id': f'{prefix}-{index:03}', 'title': f'{title} {index:02}',
                          'subtitle': f'교육과정 기본 어휘 · {len(chosen)}개', 'wordIds': [s['id'] for s in chosen]})
    return decks


def create_database(path, senses, decks, metadata, audio):
    db = sqlite3.connect(path)
    try:
        db.executescript('''
          PRAGMA foreign_keys=ON;
          CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
          CREATE TABLE headwords (id TEXT PRIMARY KEY, term TEXT NOT NULL, payload TEXT NOT NULL);
          CREATE TABLE senses (id TEXT PRIMARY KEY, headword_id TEXT NOT NULL REFERENCES headwords(id),
                               pos TEXT NOT NULL, meaning TEXT NOT NULL,
                               meaning_alternatives TEXT NOT NULL, distractor_exclusions TEXT NOT NULL,
                               payload TEXT NOT NULL);
          CREATE INDEX sense_headword ON senses(headword_id);
          CREATE INDEX sense_pos ON senses(pos);
          CREATE INDEX headword_term ON headwords(term COLLATE NOCASE);
          CREATE TABLE decks (id TEXT PRIMARY KEY, title TEXT NOT NULL, subtitle TEXT NOT NULL, position INTEGER NOT NULL);
          CREATE TABLE deck_items (deck_id TEXT NOT NULL REFERENCES decks(id), sense_id TEXT NOT NULL REFERENCES senses(id),
                                   position INTEGER NOT NULL, PRIMARY KEY(deck_id, sense_id));
          CREATE TABLE audio_assets (id TEXT PRIMARY KEY, sense_id TEXT NOT NULL REFERENCES senses(id),
                                     kind TEXT NOT NULL, payload TEXT NOT NULL);
        ''')
        db.executemany('INSERT INTO metadata VALUES (?, ?)', [(k, canonical(v)) for k, v in sorted(metadata.items())])
        headwords = {s['headwordId']: {'id': s['headwordId'], 'term': s['headword'], 'source': s['source'],
                                     'acceptedSpellings': s['acceptedSpellings']} for s in senses}
        db.executemany('INSERT INTO headwords VALUES (?, ?, ?)', [(h['id'], h['term'], canonical(h)) for h in headwords.values()])
        for sense in senses:
            db.execute('INSERT INTO senses VALUES (?, ?, ?, ?, ?, ?, ?)',
                       (sense['id'], sense['headwordId'], sense['pos'], sense['meaningKo'],
                        canonical(sense['meaningKoAlt']), canonical(sense['distractorExclusions']), canonical(sense)))
        for i, deck in enumerate(decks):
            db.execute('INSERT INTO decks VALUES (?, ?, ?, ?)', (deck['id'], deck['title'], deck['subtitle'], i))
            db.executemany('INSERT INTO deck_items VALUES (?, ?, ?)', [(deck['id'], sid, j) for j, sid in enumerate(deck['wordIds'])])
        db.executemany('INSERT INTO audio_assets VALUES (?, ?, ?, ?)',
                       [(a['assetId'], a['senseId'], a['kind'], canonical(a)) for a in audio])
        db.commit()
        require(db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok', 'SQLite integrity check failed')
        require(not db.execute('PRAGMA foreign_key_check').fetchall(), 'SQLite foreign key check failed')
    finally:
        db.close()


def write_zip(path, files):
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, 'w', compression=zipfile.ZIP_STORED) as archive:
        for name, payload in sorted(files.items()):
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.external_attr = 0o644 << 16
            archive.writestr(info, payload)


def build(approved_path, secondary_path, audio_manifest, audio_root, output, version,
          source_path=SOURCE, expected_count=300, audio_base_url=None, ranks=None,
          registry_path=CONTENT / 'sense_registry.json', deprecated_path=CONTENT / 'deprecated_ids.json',
          legacy_path=CONTENT / 'legacy_id_map.json'):
    require(version and all(c.isalnum() or c in '.-_' for c in version), 'Invalid content version')
    if audio_base_url:
        from urllib.parse import urlparse
        parsed = urlparse(audio_base_url)
        require(parsed.scheme == 'https' and parsed.netloc and not parsed.username and not parsed.query and not parsed.fragment,
                'Audio base URL must be an HTTPS directory URL without credentials/query/fragment')
    source_manifest = require_verified(source_path)
    source_rows = sources(source_path)
    senses = approved_senses(approved_path)
    require(len(senses) == expected_count, f'Expected {expected_count} approved senses, got {len(senses)}')
    require(len({s['headword'] for s in senses}) == len(senses), 'Release v1 requires one sense per headword')
    registry = read_json(registry_path)
    for sense in senses:
        require(sense['source'] == source_rows.get(sense['headword']), 'Approved source metadata changed')
        require(registry['primary'].get(sense['headword']) == sense['id'], 'Approved sense is not the registered primary')
    validation_input = []
    for sense in senses:
        candidate = {key: sense[key] for key in ['pos', 'meaningKo', 'meaningKoAlt', 'explanationKo',
                     'collocation', 'collocationKo', 'examples', 'acceptedSpellings', 'confusableHeadwords', 'nearSynonymHeadwords']}
        candidate.update(senseSlug='selected', whyPrimary='Human selected', isPrimaryProposal=True)
        validation_input.append({'headword': sense['headword'], 'source': sense['source'],
          'data': {'headword': sense['headword'], 'flags': sense['flags'],
                   'senseCandidates': [candidate, {**candidate, 'senseSlug': 'validation-copy', 'isPrimaryProposal': False}]}})
    for checked in validate_records(validation_input, source_rows):
        require(not checked['autoValidation']['errors'], f"Release S3 failed: {checked['headword']}: {checked['autoValidation']['errors']}")
    second = read_jsonl(secondary_path)
    require(len({r['senseId'] for r in second}) == len(second), 'Duplicate secondary review')
    second_by_id = {r['senseId']: r for r in second}
    for sense in sample(senses):
        review = second_by_id.get(sense['id'], {})
        require(review.get('contentHash') == sense['contentHash'] and review.get('reviewer')
                and review['reviewer'] != sense['review']['reviewer'] and review.get('reviewedAt'),
                f"{sense['id']}: independent 10% review missing/stale")
        require(review.get('criticalError') is False, 'Critical errors in secondary review block release')
    blocked = exclusions(senses)
    for sense in senses:
        sense['distractorExclusions'] = blocked[sense['id']]
        candidates = {normalize_meaning(s['meaningKo']) for s in senses if s['pos'] == sense['pos']
                      and s['id'] != sense['id'] and s['id'] not in blocked[sense['id']]}
        require(len(candidates) >= 3, f"{sense['id']}: fewer than three safe same-POS distractors")
    decks = make_decks(senses, ranks=ranks)
    mappings = {**read_json(legacy_path, {}), **read_json(deprecated_path, {})}
    active = {s['id'] for s in senses}
    require(not active.intersection(read_json(deprecated_path, {})), 'Retired IDs cannot be packaged')
    # Preserve mappings for content not in this release; the app only applies a
    # mapping when its final successor exists, retaining old history otherwise.
    for key in mappings:
        resolve_id(key, mappings)
    audio = read_jsonl(audio_manifest)
    require(len({a['assetId'] for a in audio}) == len(audio), 'Duplicate audio asset IDs')
    by_audio = {a['assetId']: a for a in audio}
    selected_audio = []
    for sense in senses:
        for kind in ('word', 'example'):
            require(f"{sense['id']}:{kind}" in by_audio, f"{sense['id']}: required {kind} audio missing")
        for kind in ('word', 'example', 'meaning'):
            asset = by_audio.get(f"{sense['id']}:{kind}")
            if asset:
                require_publishable(asset, sense, audio_root)
                expected_text = {'word': sense['headword'], 'example': sense['examples'][sense['selectedExampleIndex']]['en'],
                                 'meaning': sense['meaningKo']}[kind]
                require(asset['text'] == expected_text and asset['senseId'] == sense['id'] and asset['kind'] == kind,
                        'Audio text/identity differs from approved content')
                selected_audio.append(dict(asset))
    metadata = {'contentVersion': version, 'developmentOnly': False,
                'generatedBy': sorted({s['generation']['model'] for s in senses}),
                'promptVersion': sorted({s['generation']['promptVersion'] for s in senses}),
                'reviewedBy': sorted({s['review']['reviewer'] for s in senses}),
                'ttsVoice': sorted({a['voice'] for a in selected_audio}),
                'sourceList': [source_manifest], 'idMigrations': mappings}
    fingerprint = digest({'senses': senses, 'audio': selected_audio, 'metadata': metadata, 'decks': decks,
                          'audioBaseUrl': audio_base_url})
    destination = Path(output)
    previous = read_json(destination / 'catalog.json', {})
    if previous.get('contentVersion') == version:
        require(previous.get('buildHash') == fingerprint, 'Content version already used with different inputs')
        require(file_hash(destination / 'content.sqlite') == previous['databaseSha256'], 'Previously built database changed')
        return previous
    require(not destination.exists(), 'Build into a new version directory; install explicitly after verification')
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        staging = Path(temporary) / 'package'
        staging.mkdir()
        packs = []
        for i, deck in enumerate(decks):
            assets = [a for a in selected_audio if a['senseId'] in deck['wordIds']]
            files = {a['path']: (Path(audio_root) / safe_relative(a['path'])).read_bytes() for a in assets}
            for asset in assets:
                asset['packId'] = deck['id']
                asset['bundlePath'] = f"assets/content/audio_bundle/{Path(asset['path']).name}" if i == 0 else None
            if i == 0:
                for relative, data in files.items():
                    target = staging / 'audio_bundle' / Path(relative).name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(data)
            relative_zip = f"packs/{deck['id']}.zip"
            write_zip(staging / relative_zip, files)
            packs.append({'id': deck['id'], 'path': relative_zip,
                          'url': f"{audio_base_url.rstrip('/')}/{relative_zip}" if audio_base_url else None,
                          'sha256': file_hash(staging / relative_zip), 'bytes': (staging / relative_zip).stat().st_size,
                          'assets': [{'path': a['path'], 'sha256': a['fileSha256'], 'bytes': a['bytes']} for a in assets]})
        metadata['audioPacks'] = packs
        create_database(staging / 'content.sqlite', senses, decks, metadata, selected_audio)
        catalog = {'contentVersion': version, 'developmentOnly': False, 'buildHash': fingerprint,
                   'databaseSha256': file_hash(staging / 'content.sqlite'), 'senseCount': len(senses),
                   'deckCount': len(decks), 'audioPacks': packs}
        write_json(staging / 'catalog.json', catalog)
        write_json(staging / 'id_migrations.json', mappings)
        os.replace(staging, destination)
    return catalog


def install(package, assets):
    package, assets = Path(package), Path(assets)
    catalog = read_json(package / 'catalog.json')
    require(catalog and not catalog['developmentOnly'], 'Install only a reviewed release package')
    require(file_hash(package / 'content.sqlite') == catalog['databaseSha256'], 'Package database hash mismatch')
    with sqlite3.connect(f'file:{package / "content.sqlite"}?mode=ro', uri=True) as database:
        for row in database.execute('SELECT payload FROM audio_assets'):
            asset = json.loads(row[0])
            if asset.get('bundlePath'):
                target = package / 'audio_bundle' / Path(asset['path']).name
                require(target.is_file() and file_hash(target) == asset['fileSha256'], 'Bundled audio hash mismatch')
    assets.mkdir(parents=True, exist_ok=True)
    for name in ['content.sqlite', 'id_migrations.json']:
        shutil.copy2(package / name, assets / name)
    with tempfile.TemporaryDirectory(dir=assets) as temporary:
        staging = Path(temporary) / 'audio_bundle'
        if (package / 'audio_bundle').exists():
            shutil.copytree(package / 'audio_bundle', staging)
        else:
            staging.mkdir()
        current = assets / 'audio_bundle'
        if current.exists():
            os.replace(current, Path(temporary) / 'previous_audio_bundle')
        os.replace(staging, current)
    # Publish the manifest last. Download packs stay outside the app bundle.
    write_json(assets / 'catalog.json', catalog)
    return {'installed': str(assets), 'publishSeparately': str(package / 'packs')}
