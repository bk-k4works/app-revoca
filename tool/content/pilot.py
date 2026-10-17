"""Prepare a reproducible 100-headword pilot without calling paid APIs."""
from collections import Counter
from pathlib import Path

from . import batches, review_io
from .common import (CONTENT, SOURCE, digest, file_hash, now, read_json, require,
                     sources, write_json)

VERSION = 'pilot-v1'
QUOTAS = {'*': 27, '**': 40, '': 33}
# Editorial stress cases, not claims about frequency or the primary sense.
ANCHORS = {
    'polysemy': 'get take run set bank light right',
    'homograph': 'read live close lead bow record minute wind',
    'function_word': 'a be can that while although would',
    'variant': 'color check mathematics advertize catalogue practice analyze gasoline',
    'hyphenated': 'twenty-first',
    'related_form': 'able',
    'legacy_identity': 'achieve prepare compare describe view identity environ opportune',
    'irregular': 'go write',
}


def select(source_rows):
    """Keep source marker proportions, stress cases and broad page coverage."""
    tags = {}
    for tag, words in ANCHORS.items():
        for word in words.split():
            require(word in source_rows, f'Pilot anchor missing from source: {word}')
            tags.setdefault(word, []).append(tag)
    chosen = set(tags)
    counts = Counter(source_rows[w]['source_marker'] for w in chosen)
    require(all(counts[m] <= n for m, n in QUOTAS.items()), 'Pilot anchors exceed source quotas')
    while len(chosen) < sum(QUOTAS.values()):
        pages = {source_rows[w]['source_page'] for w in chosen}
        initials = {w[0].lower() for w in chosen}
        eligible = [w for w, row in source_rows.items() if w not in chosen
                    and row['source_marker'] in QUOTAS
                    and counts[row['source_marker']] < QUOTAS[row['source_marker']]]
        require(eligible, 'Insufficient source entries for pilot quotas')
        word = min(eligible, key=lambda w: (source_rows[w]['source_page'] in pages,
                   w[0].lower() in initials, digest([VERSION, w])))
        chosen.add(word)
        counts[source_rows[word]['source_marker']] += 1
    return [{'headword': w, 'selectionReasons': tags.get(w, ['source_stratified']),
             'source': source_rows[w]} for w in sorted(chosen)]


def prepare(output, source_path=SOURCE):
    output = Path(output)
    require(not output.exists() or not any(output.iterdir()),
            'Pilot directory is not empty; reuse existing requests or choose a new directory')
    rows = sources(source_path)
    source_manifest = read_json(Path(source_path).with_suffix('.manifest.json'), {})
    sha = file_hash(source_path)
    require(source_manifest.get('csvSha256') == sha, 'Source changed since extraction; reconcile it first')
    require(len(rows) == 3000 and Counter(r['source_marker'] for r in rows.values())
            == Counter({'*': 800, '**': 1200, '': 1000}), 'Unexpected source counts')
    sample = select(rows)
    words = [r['headword'] for r in sample]
    config = read_json(CONTENT / 'config.json')
    write_json(output / 'sample.json', {
        'version': VERSION, 'createdAt': now(), 'sourceCsvSha256': sha,
        'selectionHash': digest(sample), 'count': len(sample),
        'markerCounts': dict(Counter(r['source']['source_marker'] for r in sample)),
        'pageCoverage': sorted({r['source']['source_page'] for r in sample}),
        'initialCoverage': sorted({r['headword'][0].lower() for r in sample}),
        'selectionNote': 'Source-proportional sample with editorial stress cases; not a frequency ranking or release order.',
        'entries': sample,
    })
    for effort in ('medium', 'high'):
        batches.prepare('generate', output / f'generate.{effort}.requests.jsonl',
                        source_path=source_path, limit=100, effort=effort, only=words)
    comparison_rows = [{
        'headword': word, 'original': row['original'],
        'variants': '|'.join(row['variants']), 'related_forms': '|'.join(row['related_forms']),
        'elementary': str(row['elementary']).lower(), 'source_marker': row['source_marker'],
        'source_page': row['source_page'], 'sourceCsvSha256': sha,
        'reviewer': '', 'decision': '', 'note': '',
    } for word, row in rows.items()]
    for reviewer in ('a', 'b'):
        review_io.write_csv(output / f'source-comparison-{reviewer}.csv',
                            comparison_rows, list(comparison_rows[0]))
    summary = {
        'createdAt': now(), 'status': 'prepared_not_submitted',
        'uniqueHeadwords': 100, 'generationRequestsPerEffort': 100,
        'preparedEfforts': ['medium', 'high'], 'model': config['model'],
        'sourceCsvSha256': sha, 'sourceVerificationStatus': source_manifest.get('status'),
        'sourceHumanComparisons': len(source_manifest.get('checks', [])),
        'submissionStateAtPreparation': 'prepared',
        'nextAction': 'Set ANTHROPIC_API_KEY locally and submit generate.medium.requests.jsonl.',
        'humanReviewTarget': {'reviewedPerEffort': 100, 'uneditedApprovalRate': 0.8},
        'notes': [
            'The two effort arms use exactly the same headwords. high is a separate paid comparison.',
            'Source worksheets are comparison aids; only actual completed human checks may be attested.',
            'Keep each effort arm in separate review output and approved files until choosing a winner.',
            'No text generation, independent LLM review, human approval, or production audio has occurred.',
        ],
    }
    write_json(output / 'preparation.json', summary)
    return {'pilot': str(output), 'uniqueHeadwords': 100, 'preparedRequests': 200,
            'sourceWorksheetRowsPerReviewer': len(comparison_rows), 'status': summary['status']}
