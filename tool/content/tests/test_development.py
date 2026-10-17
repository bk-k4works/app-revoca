import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tool.content import development
from tool.content.common import CONTENT, read_jsonl, write_json, write_jsonl


class DevelopmentPreviewTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.input = CONTENT / 'pilots/pilot-v1/codex.reviewed.jsonl'
        self.identities = CONTENT / 'pilots/pilot-v1/preview-identities.json'
        self.output = self.root / 'package'

    def build(self):
        return development.build_preview(self.input, self.output, self.identities)

    def test_complete_preview_is_reproducible_and_retains_semantic_identity(self):
        catalog = self.build()
        self.assertEqual(catalog, self.build())
        self.assertEqual((catalog['headwordCount'], catalog['senseCount'], catalog['exampleCount']), (100, 154, 308))
        self.assertTrue(catalog['developmentOnly'])
        with sqlite3.connect(self.output / 'content.sqlite') as db:
            rows = {r['id']: r for (payload,) in db.execute('SELECT payload FROM senses')
                    for r in [json.loads(payload)]}
            self.assertEqual(db.execute('SELECT count(*) FROM deck_items').fetchone()[0], 154)
        self.assertEqual(rows['practice.v.skill']['pos'], 'v')
        self.assertEqual(rows['preview.practice.n.training']['pos'], 'n')
        self.assertNotIn('cheque', rows['preview.check.v.verify']['acceptedSpellings'])
        self.assertIn('cheque', rows['preview.check.n.payment']['acceptedSpellings'])
        self.assertTrue(all(r['review'] is None and r['status'] == 'llm_reviewed' for r in rows.values()))
        self.assertIn('preview.yes.interj.agreement', catalog['sparseChoiceSenseIds'])
        development.install_preview(self.output, self.root / 'assets')

    def test_stale_review_does_not_create_package(self):
        rows = read_jsonl(self.input)
        rows[0]['llmReview']['inputHash'] = 'changed'
        self.input = self.root / 'changed.jsonl'
        write_jsonl(self.input, rows)
        with self.assertRaisesRegex(ValueError, 'Stale'):
            self.build()
        self.assertFalse(self.output.exists())

    def test_preview_cannot_replace_release_or_install_corruption(self):
        self.build()
        assets = self.root / 'assets'
        write_json(assets / 'catalog.json', {'developmentOnly': False})
        with self.assertRaisesRegex(ValueError, 'overwrite'):
            development.install_preview(self.output, assets)
        with (self.output / 'content.sqlite').open('ab') as stream:
            stream.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'hash mismatch'):
            development.install_preview(self.output, self.root / 'empty-assets')
