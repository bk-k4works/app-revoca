"""Rebuild the explicit development-only 30-card SQLite fixture, never a release."""
from .build import POS_KO, create_database
from .common import CONTENT, ROOT, file_hash, read_json, require, sources, write_json, write_jsonl


def main():
    asset_dir = ROOT / 'assets/content'
    existing = read_json(asset_dir / 'catalog.json', {})
    require(not existing or existing.get('developmentOnly'), 'Cannot replace an installed release with development data')
    starter = read_json(asset_dir / 'starter_vocabulary.json')
    slugs = ['goal', 'skill', 'ready', 'better', 'attempt', 'attention', 'routine', 'timetable', 'finish', 'study',
             'think', 'difference', 'clarify', 'details', 'recognize', 'proof', 'cause', 'outcome', 'idea', 'forecast',
             'advantage', 'help', 'regard', 'safe', 'less', 'more', 'surroundings', 'chance', 'join', 'duty']
    rows = sources()
    pos_by_label = {v: k for k, v in POS_KO.items()}
    mappings, senses, registry, examples = {}, [], read_json(CONTENT / 'sense_registry.json'), []
    for word, slug in zip(starter['words'], slugs, strict=True):
        pos = pos_by_label[word['partOfSpeech']]
        sense_id = f"{word['term']}.{pos}.{slug}"
        mappings[word['id']] = sense_id
        if sense_id not in registry['ids']:
            registry['ids'][sense_id] = {'headword': word['term'], 'pos': pos, 'issuedAt': '2026-10-16T00:00:00Z',
                                         'origin': 'MVP migration; semantic identity reserved, not human approved'}
        registry['primary'].setdefault(word['term'], sense_id)
        sense = {'id': sense_id, 'headwordId': word['term'], 'headword': word['term'], 'pos': pos,
                 'meaningKo': word['meaning'], 'meaningKoAlt': [], 'explanationKo': word['explanation'],
                 'collocation': word['collocation'], 'collocationKo': word['collocationMeaning'],
                 'examples': [{'en': word['example'], 'ko': word['exampleMeaning']}], 'selectedExampleIndex': 0,
                 'acceptedSpellings': word['acceptedSpellings'], 'distractorExclusions': [],
                 'source': rows.get(word['term'], {'kind': 'original_mvp_selection', 'elementary': False}),
                 'generation': {'model': 'original_mvp', 'promptVersion': 'not_recorded'},
                 'status': 'draft', 'review': None}
        senses.append(sense)
        examples.append({'headword': word['term'], 'status': 'unreviewed_reference',
                         'sourceFile': 'assets/content/starter_vocabulary.json', 'content': word})
    decks = [{**deck, 'wordIds': [mappings[w] for w in deck['wordIds']]} for deck in starter['decks']]
    metadata = {'contentVersion': 'dev-starter-1', 'developmentOnly': True,
                'idMigrations': mappings, 'audioPacks': [], **starter['provenance']}
    database = asset_dir / 'content.sqlite'
    if database.exists():
        database.unlink()
    create_database(database, senses, decks, metadata, [])
    write_json(asset_dir / 'catalog.json', {'contentVersion': 'dev-starter-1', 'developmentOnly': True,
                'databaseSha256': file_hash(database), 'senseCount': 30, 'deckCount': 3, 'audioPacks': []})
    write_json(CONTENT / 'legacy_id_map.json', mappings)
    write_json(CONTENT / 'sense_registry.json', registry)
    write_jsonl(CONTENT / 'gold/starter_examples.jsonl', examples)


if __name__ == '__main__':
    main()
