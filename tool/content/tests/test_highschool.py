import csv
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tool.content import highschool
from tool.content.common import CONTENT, read_json, read_jsonl, sources
from tool.content.validate import HIGH, MIDDLE, validate_records

AUTHORED = CONTENT / 'highschool/v1/authored'


class HighSchoolTest(unittest.TestCase):
    def test_tiers_follow_curriculum_markers_and_frequency(self):
        curriculum = {'feed': {'source_marker': '**'}, 'abstract': {'source_marker': ''}, 'book': {'source_marker': '*'}}
        self.assertEqual(highschool.tier_of({'kind': 'exact', 'headwords': ['feed']}, curriculum, 3), 'basic')
        self.assertEqual(highschool.tier_of({'kind': 'exact', 'headwords': ['book']}, curriculum, 6), 'familiar')
        self.assertEqual(highschool.tier_of({'kind': 'exact', 'headwords': ['abstract']}, curriculum, 6), 'core')
        self.assertEqual(highschool.tier_of({'kind': 'variant_or_related', 'headwords': []}, curriculum, 2), 'core')
        self.assertEqual(highschool.tier_of({'kind': 'outside_representative_list', 'headwords': []}, curriculum, 4.2), 'core')
        self.assertEqual(highschool.tier_of({'kind': 'outside_representative_list', 'headwords': []}, curriculum, 3.1), 'advanced')
        self.assertEqual(highschool.tier_of({'kind': 'outside_representative_list', 'headwords': []}, curriculum, 6, 'in order to'), 'phrase')

    def test_source_list_carries_no_book_text_or_order(self):
        with highschool.HS_SOURCE.open(encoding='utf-8') as stream:
            rows = list(csv.DictReader(stream))
        self.assertEqual(len(rows), 2000)
        self.assertEqual(set(rows[0]), set(highschool.COLUMNS))
        self.assertTrue(all(r['original'] == r['headword'] for r in rows))
        ranks = [int(r['rank']) for r in rows]
        self.assertEqual(ranks, list(range(1, 2001)))
        order = list(highschool.TIERS)
        self.assertEqual([r['tier'] for r in rows], sorted((r['tier'] for r in rows), key=order.index))
        provenance = read_json(highschool.HS_PROVENANCE)
        self.assertEqual(set(provenance['headwords']), {r['headword'] for r in rows})

    def test_short_trailing_chunk_joins_previous_deck(self):
        rows = {f'w{i}': {'tier': 'basic', 'rank': str(i)} for i in range(23)}
        senses = [{'id': f'hs.w{i}', 'headword': f'w{i}'} for i in range(23)]
        decks = highschool.make_tier_decks(senses, rows)
        self.assertEqual([len(d['wordIds']) for d in decks], [23])
        rows['w23'], rows['w24'] = {'tier': 'basic', 'rank': '23'}, {'tier': 'basic', 'rank': '24'}
        senses += [{'id': 'hs.w23', 'headword': 'w23'}, {'id': 'hs.w24', 'headword': 'w24'}]
        self.assertEqual([len(d['wordIds']) for d in highschool.make_tier_decks(senses, rows)], [20, 5])

    def test_phrase_targets_are_contiguous_and_inflected(self):
        from tool.content.validate import Lemmatizer, forms_config
        lemmatizer = Lemmatizer(highschool.lexicon_rows(), forms_config(HIGH))
        self.assertEqual(lemmatizer.target_count('You are supposed to arrive by nine.', ['be supposed to']), 1)
        self.assertEqual(lemmatizer.target_count('She got along with everyone.', ['get along with']), 1)
        self.assertEqual(lemmatizer.target_count('Do not take your health for granted.', ['take for granted']), 0)
        self.assertEqual(lemmatizer.target_count('We often take simple things for granted.', ['take for granted']), 0)
        self.assertEqual(lemmatizer.target_count('These are things we take for granted.', ['take for granted']), 1)
        self.assertTrue(lemmatizer.in_scope('versa') and lemmatizer.in_scope('capita'))

    def test_high_profile_expects_plain_style_translations(self):
        rows = sources(highschool.HS_SOURCE)
        entry = highschool.parse_authored(AUTHORED / 'part-01.txt', rows)[0]
        polite = {'headword': entry['headword'], 'source': rows[entry['headword']], 'data': {
            **entry, 'senseCandidates': [{**entry['senseCandidates'][0], 'examples': [
                {'en': 'You can call me at any time if you need help.', 'ko': '언제든지 전화해도 돼요.'},
                {'en': 'Any student who finishes early may leave the room.', 'ko': '누구든 나가도 된다.'}]}]}}
        lexicon = highschool.lexicon_rows()
        high = validate_records([polite], rows, HIGH, lexicon)[0]['autoValidation']['warnings']
        middle = validate_records([polite], rows, MIDDLE, lexicon)[0]['autoValidation']['warnings']
        self.assertTrue(any('평서체' in w for w in high))
        self.assertTrue(any('해요체' in w for w in middle))

    def test_authored_rows_do_not_repeat_across_headwords(self):
        rows = [line.split('|') for f in sorted(AUTHORED.glob('*.txt'))
                for line in f.read_text().splitlines() if line.strip() and not line.startswith('#')]
        phrases = {r[0] for r in rows if r[1] == 'phrase'}

        def repeated(key):
            seen = {}
            for r in rows:
                seen.setdefault(key(r), set()).add(r[0])
            return {k: sorted(v) for k, v in seen.items() if len(v) > 1}

        # 철자 문제는 뜻만 보여 주므로 같은 품사의 대표 뜻이 겹치면 정답이 둘이 된다.
        self.assertEqual(repeated(lambda r: (r[1], r[3].split(';')[0].strip())), {})
        self.assertEqual(repeated(lambda r: r[4]), {})
        self.assertEqual(repeated(lambda r: r[5].lower()), {})
        self.assertEqual([r[0] for r in rows if r[1] != 'phrase' and r[5].lower() in phrases], [])

    def test_authored_rows_pass_and_build_tier_decks(self):
        with tempfile.TemporaryDirectory() as temporary:
            drafts = Path(temporary) / 'drafts.jsonl'
            result = highschool.draft(AUTHORED, drafts)
            self.assertEqual(result['failed'], {})
            self.assertEqual(result['headwords'], 2000)
            package = Path(temporary) / 'package'
            catalog = highschool.build_preview(drafts, package)
            self.assertEqual(catalog['deckCount'], 101)
            with sqlite3.connect(package / 'content.sqlite') as db:
                decks = db.execute('SELECT id FROM decks ORDER BY position').fetchall()
                self.assertEqual(decks[0][0], 'hs-basic-001')
                heads = db.execute('''SELECT d.deck_id, COUNT(DISTINCT s.headword_id) FROM deck_items d
                    JOIN senses s ON s.id=d.sense_id GROUP BY d.deck_id''').fetchall()
                self.assertTrue(all(count < 20 + highschool.MIN_DECK for _, count in heads))
                self.assertEqual(sum(count for _, count in heads), 2000)
                book = db.execute("SELECT id FROM senses WHERE headword_id='book'").fetchall()
                self.assertEqual(book, [('hs.book.v.reserve',)])
                familiar = db.execute("SELECT COUNT(*) FROM decks WHERE id LIKE 'hs-familiar-%'").fetchone()[0]
                self.assertEqual(familiar, 3)
                split = db.execute('''SELECT s.headword_id FROM deck_items d JOIN senses s ON s.id=d.sense_id
                    GROUP BY s.headword_id HAVING COUNT(DISTINCT d.deck_id) > 1''').fetchall()
                self.assertEqual(split, [])
            records = read_jsonl(drafts)
            self.assertTrue(all(r['generation']['externalApiUsed'] is False for r in records))


if __name__ == '__main__':
    unittest.main()
