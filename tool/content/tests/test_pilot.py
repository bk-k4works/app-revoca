import tempfile
import unittest
from collections import Counter
from pathlib import Path

from tool.content import batches, pilot, review_io
from tool.content.common import SOURCE, file_hash, read_json, sources, write_json


class PilotTest(unittest.TestCase):
    def test_selection_is_order_independent_and_covers_source(self):
        rows = sources()
        selected = pilot.select(rows)
        self.assertEqual(selected, pilot.select(dict(reversed(list(rows.items())))))
        self.assertEqual(len({r['headword'] for r in selected}), 100)
        self.assertEqual(Counter(r['source']['source_marker'] for r in selected), pilot.QUOTAS)
        self.assertEqual({r['source']['source_page'] for r in selected}, set(range(7, 37)))
        for group in pilot.ANCHORS.values():
            self.assertTrue(set(group.split()) <= {r['headword'] for r in selected})

    def test_preparation_has_matching_arms_and_no_human_decisions(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'pilot'
            pilot.prepare(output)
            _, medium_manifest, medium = batches.load_requests(output / 'generate.medium.requests.jsonl')
            _, high_manifest, high = batches.load_requests(output / 'generate.high.requests.jsonl')
            self.assertEqual(len(medium), 100)
            self.assertEqual(medium_manifest['entries'].keys(), high_manifest['entries'].keys())
            for left, right in zip(medium, high):
                self.assertEqual(left['custom_id'], right['custom_id'])
                self.assertEqual(left['params']['messages'], right['params']['messages'])
                self.assertEqual(left['params']['system'], right['params']['system'])
                self.assertEqual(left['params']['output_config']['effort'], 'medium')
                self.assertEqual(right['params']['output_config']['effort'], 'high')
            for arm in ('a', 'b'):
                rows = review_io.read_csv(output / f'source-comparison-{arm}.csv')
                self.assertEqual(len(rows), 3000)
                self.assertTrue(all(not r['reviewer'] and not r['decision'] for r in rows))
                self.assertEqual({r['sourceCsvSha256'] for r in rows}, {file_hash(SOURCE)})
            before = file_hash(output / 'generate.medium.requests.jsonl')
            with self.assertRaisesRegex(ValueError, 'not empty'):
                pilot.prepare(output)
            self.assertEqual(before, file_hash(output / 'generate.medium.requests.jsonl'))
            self.assertEqual(read_json(output / 'preparation.json')['status'], 'prepared_not_submitted')

    def test_preparation_refuses_changed_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'source.csv'
            path.write_bytes(SOURCE.read_bytes())
            write_json(path.with_suffix('.manifest.json'), {'csvSha256': 'stale'})
            output = Path(tmp) / 'pilot'
            with self.assertRaisesRegex(ValueError, 'Source changed'):
                pilot.prepare(output, path)
            self.assertFalse(output.exists())
