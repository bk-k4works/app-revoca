import copy
import csv
import json
import sqlite3
import tempfile
from types import SimpleNamespace
import unittest
from pathlib import Path
from unittest.mock import patch

from tool.content import batches, build, ingest, local, review_io, tts, validate
from tool.content.common import CONTENT, ROOT, SOURCE, digest, file_hash, read_json, read_jsonl, sources, write_json, write_jsonl


class PipelineTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source.csv'
        self.source.write_bytes(SOURCE.read_bytes())
        self.rows = sources(self.source)
        self.registry = self.root / 'registry.json'
        write_json(self.registry, {'ids': {}, 'primary': {}})
        self.approved = self.root / 'approved.jsonl'
        self.input = self.root / 'reviewed.jsonl'
        self.csv = self.root / 'review.csv'
        starter = read_json(ROOT / 'assets/content/starter_vocabulary.json')['words']
        self.records = []
        for word in [w for w in starter if w['term'] in {'achieve', 'prepare', 'compare', 'describe'}]:
            candidate = {'pos': 'v', 'senseSlug': 'primary', 'meaningKo': word['meaning'], 'meaningKoAlt': [],
                         'whyPrimary': 'Test rationale', 'isPrimaryProposal': True, 'explanationKo': word['explanation'],
                         'collocation': word['collocation'], 'collocationKo': word['collocationMeaning'],
                         'examples': [{'en': word['example'], 'ko': word['exampleMeaning']}] * 2,
                         'acceptedSpellings': word['acceptedSpellings'], 'confusableHeadwords': [], 'nearSynonymHeadwords': []}
            secondary = {**copy.deepcopy(candidate), 'senseSlug': 'secondary', 'isPrimaryProposal': False}
            record = {'headword': word['term'], 'status': 'draft', 'source': self.rows[word['term']],
                      'data': {'headword': word['term'], 'senseCandidates': [candidate, secondary], 'flags': []},
                      'generation': {'model': 'test-fixture', 'promptVersion': 'test-v1'}}
            checked = validate.validate_record(record, self.rows)
            self.assertEqual(checked['autoValidation']['errors'], [])
            checked.update(status='llm_reviewed', llmReview={'inputHash': checked['contentHash'], 'severity': 'pass',
                           'criticalError': False, 'issues': []})
            self.records.append(checked)
        write_jsonl(self.input, self.records)

    def approve(self):
        review_io.export(self.input, self.csv)
        rows = review_io.read_csv(self.csv)
        for row in rows:
            row.update(decision='human_approved', reviewer='TEST_EDITOR_A')
        review_io.write_csv(self.csv, rows, list(rows[0]))
        result = review_io.import_reviews(self.input, self.csv, self.root/'decisions.jsonl', self.approved,
                                          self.source, self.registry)
        self.assertEqual(result['approved'], 4)
        return read_jsonl(self.approved)

    def release_inputs(self):
        senses = self.approve()
        source_hash = file_hash(self.source)
        write_json(self.source.with_suffix('.manifest.json'), {'status': 'human_verified', 'csvSha256': source_hash,
                   'sourceList': 'TEST_SOURCE', 'checks': [{'reviewer': 'TEST_A', 'csvSha256': source_hash},
                                                        {'reviewer': 'TEST_B', 'csvSha256': source_hash}]})
        secondary_csv = self.root / 'secondary.csv'
        review_io.export_secondary(self.approved, secondary_csv)
        rows = review_io.read_csv(secondary_csv)
        for row in rows:
            row.update(reviewer='TEST_EDITOR_B', agree='true', criticalError='false')
        review_io.write_csv(secondary_csv, rows, list(rows[0]))
        secondary = self.root/'secondary.jsonl'
        review_io.import_secondary(self.approved, secondary_csv, secondary)
        manifest = self.root/'audio.jsonl'
        tts.plan(self.approved, manifest)
        audio = read_jsonl(manifest)
        for asset in audio:
            target = self.root / asset['path']
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(('MOCK_AUDIO:' + asset['text']).encode())
            asset.update(fileSha256=file_hash(target), bytes=target.stat().st_size, status='human_verified',
                         asr={'fileSha256': file_hash(target), 'model': 'TEST_ASR', 'wordErrorRate': 0},
                         distributionApproval={'allowed': True, 'reviewer': 'TEST_RIGHTS_REVIEW'},
                         listeningReview={'reviewer': 'TEST_LISTENER', 'decision': 'approved', 'fileSha256': file_hash(target)})
        write_jsonl(manifest, audio)
        return dict(approved_path=self.approved, secondary_path=secondary, audio_manifest=manifest,
                    audio_root=self.root, output=self.root/'release', version='test-1', source_path=self.source,
                    expected_count=4, registry_path=self.registry, deprecated_path=self.root/'deprecated.json',
                    legacy_path=self.root/'legacy.json')

    def test_source_count_markers_and_variants(self):
        self.assertEqual(len(self.rows), 3000)
        self.assertEqual(sum(r['elementary'] for r in self.rows.values()), 800)
        self.assertEqual(sum(r['source_marker'] == '**' for r in self.rows.values()), 1200)
        self.assertEqual(self.rows['color']['variants'], ['colour'])
        self.assertIn('disabled', self.rows['able']['related_forms'])
        self.assertNotIn('disabled', self.rows['able']['variants'])
        self.assertEqual(self.rows['a']['source_page'], 7)

    def test_local_authoring_and_review_keep_provenance_without_approval(self):
        authored = self.root / 'authored.jsonl'
        drafts = self.root / 'drafts.jsonl'
        checked = self.root / 'checked.jsonl'
        reviews = self.root / 'local-reviews.jsonl'
        output = self.root / 'local-reviewed.jsonl'
        write_jsonl(authored, [r['data'] for r in self.records])
        local.import_drafts(authored, drafts, self.source)
        self.assertEqual(validate.run(drafts, checked, self.source)['passed'], 4)
        criteria = {key: {'rating': 'pass', 'reason': 'Fixture check'} for key in
                    ('primaryMeaning', 'semanticAlignment', 'englishGrammar', 'koreanTranslation',
                     'ageAppropriateness', 'uniqueAnswer')}
        authored_reviews = [{'headword': r['headword'], 'inputHash': r['contentHash'],
            'review': {'headword': r['headword'], 'criteria': copy.deepcopy(criteria),
                       'severity': 'pass', 'criticalError': False, 'issues': []},
            'references': []} for r in read_jsonl(checked)]
        authored_reviews[0]['review']['criteria']['uniqueAnswer']['rating'] = 'warn'
        write_jsonl(reviews, authored_reviews)
        result = local.import_reviews(checked, reviews, output, self.source)
        self.assertEqual(result['humanApproved'], 0)
        reviewed = read_jsonl(output)
        self.assertEqual(reviewed[0]['llmReview']['severity'], 'warn')
        for record in reviewed:
            self.assertFalse(record['generation']['externalApiUsed'])
            self.assertFalse(record['llmReview']['provenance']['independentModel'])
            self.assertNotIn('humanReview', record)
        review_io.export(output, self.csv)
        self.assertTrue(all(r['reviewMethod'] == 'codex-local-review' and not r['decision']
                            for r in review_io.read_csv(self.csv)))
        original_hash = file_hash(output)
        authored_reviews[0]['inputHash'] = 'stale'
        write_jsonl(reviews, authored_reviews)
        with self.assertRaisesRegex(ValueError, 'stale'):
            local.import_reviews(checked, reviews, output, self.source)
        self.assertEqual(file_hash(output), original_hash)
        write_jsonl(reviews, authored_reviews[1:])
        with self.assertRaisesRegex(ValueError, 'exactly one'):
            local.import_reviews(checked, reviews, output, self.source)

    def test_single_candidate_needs_explicit_editorial_flag(self):
        record = copy.deepcopy(self.records[0])
        record['data']['senseCandidates'] = record['data']['senseCandidates'][:1]
        self.assertTrue(validate.validate_record(record, self.rows)['autoValidation']['errors'])
        record['data']['flags'].append('single_sense_candidate')
        checked = validate.validate_record(record, self.rows)
        self.assertFalse(checked['autoValidation']['errors'])
        self.assertTrue(checked['autoValidation']['warnings'])

    def test_sense_specific_spelling_is_not_expanded(self):
        record = copy.deepcopy(self.records[0])
        record.update(headword='check', source=self.rows['check'])
        record['data']['headword'] = 'check'
        for candidate in record['data']['senseCandidates']:
            candidate['acceptedSpellings'] = ['check']
            candidate['examples'] = [{'en': 'Please check the door before you leave.', 'ko': '나가기 전에 문을 확인해 주세요.'}] * 2
        checked = validate.validate_record(record, self.rows)
        self.assertFalse(checked['autoValidation']['errors'])
        self.assertEqual(checked['data']['senseCandidates'][0]['acceptedSpellings'], ['check'])
        record['data']['senseCandidates'][0]['acceptedSpellings'].append('checking')
        self.assertTrue(validate.validate_record(record, self.rows)['autoValidation']['errors'])

    def test_irregular_scope_forms_do_not_turn_derivations_into_targets(self):
        lemma = validate.Lemmatizer(self.rows)
        for token in ('these', 'more', 'wound', 'blew', 'cannot', 'carefully', 'scientists'):
            self.assertTrue(lemma.in_scope(token), token)
        self.assertEqual(lemma.target_count('She wound the string around her hand.', ['wind']), 1)
        self.assertTrue(lemma.in_scope('freedom'))
        self.assertEqual(lemma.target_count('They enjoyed their freedom.', ['free']), 0)
        self.assertFalse(lemma.in_scope("he're"))

    def test_empty_validation_does_not_report_success(self):
        with self.assertRaisesRegex(ValueError, 'No drafts'):
            validate.run(self.root / 'missing.jsonl', self.root / 'out.jsonl', self.source)

    def test_source_extraction_reproducible(self):
        output = self.root/'extracted.csv'
        ingest.extract(CONTENT/'sources/curriculum_2022_basic.pdf', output)
        self.assertEqual(output.read_bytes(), SOURCE.read_bytes())
        with self.assertRaises(ValueError): ingest.require_verified(output)
        ingest.attest(output, 'TEST_A', 'Fixture comparison')
        with self.assertRaises(ValueError): ingest.attest(output, 'TEST_A', 'Duplicate')
        ingest.attest(output, 'TEST_B', 'Fixture comparison')
        ingest.require_verified(output)
        output.write_text(output.read_text() + '\n')
        with self.assertRaises(ValueError): ingest.require_verified(output)

    def test_missing_target_repeated_target_and_inflections(self):
        lemma = validate.Lemmatizer(self.rows)
        self.assertEqual(lemma.target_count('She achieved her goal yesterday.', ['achieve']), 1)
        self.assertEqual(lemma.target_count('She wrote the written text.', ['write']), 2)
        for text in ['You can meet your goal with daily practice.', 'Achieve a goal and achieve another one.']:
            record = copy.deepcopy(self.records[0])
            record['data']['senseCandidates'][0]['examples'][0]['en'] = text
            self.assertTrue(validate.validate_record(record, self.rows)['autoValidation']['errors'])

    def test_schema_invalid_record_is_reported(self):
        record = copy.deepcopy(self.records[0])
        del record['data']['senseCandidates'][0]['meaningKo']
        self.assertEqual(validate.validate_record(record, self.rows)['status'], 'needs_fix')

    def test_vocabulary_scope_and_style(self):
        record = copy.deepcopy(self.records[0])
        record['data']['senseCandidates'][0]['examples'][0]['en'] = 'You can achieve quuxfoo and quuxbar after school.'
        checked = validate.validate_record(record, self.rows)
        self.assertTrue(any('out of scope' in e for e in checked['autoValidation']['errors']))
        record['data']['senseCandidates'][0]['examples'][0]['en'] = 'You can achieve a quuxfoo after school.'
        self.assertFalse(validate.validate_record(record, self.rows)['autoValidation']['errors'])

    def test_duplicate_examples_fail_both_headwords(self):
        records = copy.deepcopy(self.records[:2])
        text = 'We achieve more when we prepare after school.'
        for record in records:
            for candidate in record['data']['senseCandidates']:
                candidate['examples'] = [{'en': text, 'ko': '학교가 끝나고 준비하면 더 많이 이뤄요.'}] * 2
        result = validate.validate_records(records, self.rows)
        self.assertTrue(all(r['status'] == 'needs_fix' for r in result))

    def test_exclusions_are_symmetric_transitive_and_include_aliases(self):
        senses = [dict(id='a', headword='achieve', meaningKo='달성하다', meaningKoAlt=['성취하다'], nearSynonymHeadwords=['accomplish']),
                  dict(id='b', headword='accomplish', meaningKo='완수하다', nearSynonymHeadwords=['finish']),
                  dict(id='c', headword='finish', meaningKo='끝내다'), dict(id='d', headword='attain', meaningKo='성취하다')]
        blocked = validate.exclusions(senses)
        self.assertEqual(blocked['a'], ['b', 'c', 'd'])
        self.assertIn('a', blocked['c'])

    def test_reviewer_and_stale_csv_are_required(self):
        review_io.export(self.input, self.csv)
        rows = review_io.read_csv(self.csv)
        rows[0]['decision'] = 'human_approved'
        review_io.write_csv(self.csv, rows, list(rows[0]))
        with self.assertRaises(ValueError):
            review_io.import_reviews(self.input, self.csv, self.root/'out', self.approved, self.source, self.registry)
        rows[0].update(reviewer='TEST_A', inputHash='stale')
        review_io.write_csv(self.csv, rows, list(rows[0]))
        with self.assertRaises(ValueError):
            review_io.import_reviews(self.input, self.csv, self.root/'out', self.approved, self.source, self.registry)
        self.assertFalse(self.approved.exists())

    def test_edits_rerun_validation_atomically(self):
        review_io.export(self.input, self.csv)
        rows = review_io.read_csv(self.csv)
        for row in rows: row.update(decision='human_approved', reviewer='TEST_A')
        rows[-1]['editsJson'] = json.dumps({'examples': [{'en': 'No target here.', 'ko': '틀렸어요.'}] * 2})
        review_io.write_csv(self.csv, rows, list(rows[0]))
        with self.assertRaises(ValueError):
            review_io.import_reviews(self.input, self.csv, self.root/'out', self.approved, self.source, self.registry)
        self.assertFalse(self.approved.exists())
        self.assertEqual(read_json(self.registry)['ids'], {})

    def test_ids_survive_regeneration_and_pos_change_needs_explicit_retirement(self):
        senses = self.approve()
        registry = read_json(self.registry)
        original = senses[0]
        self.assertEqual(review_io.allocate(registry, original['headword'], original['pos'], 'changed-slug'), original['id'])
        with self.assertRaises(ValueError): review_io.allocate(registry, original['headword'], 'n', 'changed-pos')

    def test_hash_changes_revoke_approval(self):
        senses = self.approve()
        senses[0]['meaningKo'] = '수정한 뜻'
        write_jsonl(self.approved, senses)
        with self.assertRaises(ValueError): tts.plan(self.approved, self.root/'audio.jsonl')

    def test_secondary_requires_another_reviewer(self):
        senses = self.approve()
        secondary = self.root/'secondary.csv'
        review_io.export_secondary(self.approved, secondary)
        rows = review_io.read_csv(secondary)
        self.assertEqual(len(rows), 1)
        rows[0].update(reviewer='TEST_EDITOR_A', agree='true', criticalError='false')
        review_io.write_csv(secondary, rows, list(rows[0]))
        with self.assertRaises(ValueError): review_io.import_secondary(self.approved, secondary, self.root/'secondary.jsonl')

    def test_audio_plan_hashes_text_voice_and_settings(self):
        self.approve()
        manifest = self.root/'audio.jsonl'
        tts.plan(self.approved, manifest)
        original = read_jsonl(manifest)
        tts.plan(self.approved, manifest)
        self.assertEqual(read_jsonl(manifest), original)
        config = read_json(CONTENT/'config.json')
        config['tts']['voices']['en-US'] = 'other-voice'
        custom = self.root/'config.json'
        write_json(custom, config)
        tts.plan(self.approved, manifest, custom)
        self.assertNotEqual(read_jsonl(manifest)[0]['hash'], original[0]['hash'])
        self.assertEqual(tts.word_error_rate('A short test.', 'a short test'), 0)
        self.assertGreater(tts.word_error_rate('A short test.', 'a wrong test'), 0)

    def test_distribution_review_required_before_tts(self):
        self.approve()
        manifest = self.root/'audio.jsonl'
        tts.plan(self.approved, manifest)
        with self.assertRaises(ValueError): tts.synthesize(manifest, self.root)

    def test_synthesis_resumes_and_rechecks_current_human_approval(self):
        self.approve()
        manifest = self.root/'audio.jsonl'
        tts.plan(self.approved, manifest)
        config = read_json(CONTENT/'config.json')
        config['tts']['distributionApproval'] = {'allowed': True, 'reviewer': 'TEST_RIGHTS_REVIEW',
                                                'reviewedAt': '2026-10-16T00:00:00Z', 'termsUrl': 'https://example.test/terms'}
        config_path = self.root/'config.json'
        write_json(config_path, config)
        def run(command):
            if command[0] == 'ffprobe' and '-show_streams' in command:
                return SimpleNamespace(stdout=json.dumps({'format': {'duration': '1.5'},
                  'streams': [{'codec_name': 'aac', 'channels': 1}]}), stderr='')
            if '-c:a' in command:
                Path(command[-1]).write_bytes(b'TEST_NORMALIZED_AUDIO')
            return SimpleNamespace(stdout='', stderr='')
        with patch.object(tts, 'run_command', side_effect=run), patch.object(tts, 'google_synthesize', return_value=b'TEST_WAV') as provider:
            tts.synthesize(manifest, self.root, config_path, self.approved)
            self.assertEqual(provider.call_count, 8)
            tts.synthesize(manifest, self.root, config_path, self.approved)
            self.assertEqual(provider.call_count, 8)
            write_jsonl(self.approved, [])
            with self.assertRaises(ValueError): tts.synthesize(manifest, self.root, config_path, self.approved)
            self.assertEqual(provider.call_count, 8)

    def test_edited_audio_plan_never_reaches_provider(self):
        self.approve()
        manifest = self.root/'audio.jsonl'
        tts.plan(self.approved, manifest)
        audio = read_jsonl(manifest)
        audio[0]['text'] = 'Unapproved replacement text'
        write_jsonl(manifest, audio)
        config = read_json(CONTENT/'config.json')
        config['tts']['distributionApproval'] = {'allowed': True, 'reviewer': 'TEST',
                                                'reviewedAt': '2026-10-16T00:00:00Z', 'termsUrl': 'https://example.test'}
        path = self.root/'config.json'
        write_json(path, config)
        with patch.object(tts, 'google_synthesize') as provider:
            with self.assertRaises(ValueError): tts.synthesize(manifest, self.root, path, self.approved)
            provider.assert_not_called()

    def test_korean_asr_compares_hangul(self):
        self.assertEqual(tts.word_error_rate('달성하다', '달성하다.'), 0)
        self.assertEqual(tts.word_error_rate('달성하다', '다른 말'), 2)

    def test_release_database_and_repeat_build(self):
        args = self.release_inputs()
        result = build.build(**args)
        self.assertEqual(result['senseCount'], 4)
        self.assertEqual(build.build(**args), result)
        with sqlite3.connect(args['output']/'content.sqlite') as db:
            self.assertEqual(db.execute('SELECT count(*) FROM senses').fetchone()[0], 4)
            self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
            self.assertEqual(db.execute('SELECT count(*) FROM audio_assets').fetchone()[0], 8)
        self.assertTrue(list((args['output']/'audio_bundle').glob('*.m4a')))
        self.assertTrue(list((args['output']/'packs').glob('*.zip')))
        installed = self.root/'app_assets'
        (installed/'audio_bundle').mkdir(parents=True)
        (installed/'audio_bundle/stale.m4a').write_bytes(b'old-version')
        build.install(args['output'], installed)
        self.assertFalse((installed/'audio_bundle/stale.m4a').exists())
        self.assertEqual(file_hash(installed/'content.sqlite'), result['databaseSha256'])
        self.assertFalse((installed/'packs').exists())

    def test_release_blocks_unverified_source(self):
        args = self.release_inputs()
        args['source_path'].with_suffix('.manifest.json').unlink()
        with self.assertRaises(ValueError): build.build(**args)

    def test_release_blocks_critical_secondary_error(self):
        args = self.release_inputs()
        reviews = read_jsonl(args['secondary_path'])
        reviews[0]['criticalError'] = True
        write_jsonl(args['secondary_path'], reviews)
        with self.assertRaises(ValueError): build.build(**args)

    def test_release_blocks_corrupt_or_stale_audio(self):
        args = self.release_inputs()
        audio = read_jsonl(args['audio_manifest'])
        (self.root/audio[0]['path']).write_bytes(b'corrupt')
        with self.assertRaises(ValueError): build.build(**args)

    def test_release_blocks_insufficient_safe_choices(self):
        args = self.release_inputs()
        senses = read_jsonl(self.approved)
        senses[0]['nearSynonymHeadwords'] = [senses[1]['headword']]
        senses[0]['contentHash'] = validate.sense_hash(senses[0])
        senses[0]['review']['contentHash'] = senses[0]['contentHash']
        write_jsonl(self.approved, senses)
        with self.assertRaises(ValueError): build.build(**args)

    def test_prepare_cache_and_unordered_batch_results(self):
        requests = self.root/'generate.requests.jsonl'
        batches.prepare('generate', requests, source_path=self.source, limit=4,
                        only=[r['headword'] for r in self.records])
        records_by_word = {r['headword']: r for r in self.records}
        raw = []
        for request in reversed(read_jsonl(requests)):
            word = request['custom_id']
            raw.append({'custom_id': word, 'result': {'type': 'succeeded', 'message': {
                'model': 'test-model', 'stop_reason': 'end_turn', 'usage': {'input_tokens': 100, 'output_tokens': 50},
                'content': [{'type': 'text', 'text': json.dumps(records_by_word[word]['data'])}]}}})
        raw[0]['result']['message']['stop_reason'] = 'refusal'
        raw_path = self.root/'raw.jsonl'
        write_jsonl(raw_path, raw)
        output = self.root/'drafts/result.jsonl'
        summary = batches.collect(requests, output, raw_path)
        self.assertEqual(summary['succeeded'], 3)
        self.assertEqual(summary['failed'], 1)
        self.assertEqual(summary['usage']['input_tokens'], 400)
        self.assertEqual(len(read_jsonl(output.with_suffix('.retry.jsonl'))), 1)
        second = self.root/'changed.requests.jsonl'
        result = batches.prepare('generate', second, source_path=self.source, limit=4,
                                 only=[r['headword'] for r in self.records], cache_dir=output.parent)
        self.assertEqual(result['count'], 1)

    def test_submission_outcome_unknown_does_not_duplicate_paid_work(self):
        requests = self.root/'request.jsonl'
        batches.prepare('generate', requests, source_path=self.source, limit=1, only=['achieve'])
        with patch.dict('os.environ', {'ANTHROPIC_API_KEY': 'TEST_NOT_A_REAL_KEY'}):
            with patch.object(batches, 'api', side_effect=OSError('network lost')):
                with self.assertRaises(OSError): batches.submit(requests)
            with patch.object(batches, 'api') as api:
                with self.assertRaises(ValueError): batches.submit(requests)
                api.assert_not_called()


if __name__ == '__main__':
    unittest.main()
