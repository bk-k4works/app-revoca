import gzip
import json
import unittest
from pathlib import Path

from tool.content.common import CONTENT
from tool.content.pdf_books import (complete_cloze, high_entries, middle_entries,
                                    observed_day, resources_for, study_supplements,
                                    validate_entries)


class PdfBooksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path = Path(__file__).parent/'fixtures/pdf-books-layout.json.gz'
        with gzip.open(path,'rt',encoding='utf-8') as stream:
            cls.pages = json.load(stream)

    def page(self, book, number):
        return next(p for p in self.pages[book] if p['page']==number)

    def middle(self, page, number):
        return next(e for e in middle_entries(self.page('ebs-middle-excerpt',page))
                    if e['sourceEntryNumber']==number)

    def test_high_entries_preserve_examples_exam_labels_and_multiple_pos(self):
        entries = high_entries(self.page('sarang-csat-2000',6))
        self.assertEqual([e['headword'] for e in entries],['feed','accept','approach','perform','attract'])
        self.assertEqual(entries[0]['examples'][0]['sourceLabels'],['06모고'])
        self.assertEqual(entries[0]['examples'][1]['en'],
                         'In the afternoon he stopped in another town for a while to feed his horse.')
        self.assertEqual([d['pos'] for d in entries[2]['definitions']],['n','v'])

    def test_visible_page_bounds_exclude_other_page_entries_and_keep_bottom_translation(self):
        entries = high_entries(self.page('sarang-csat-2000',7))
        self.assertEqual([e['sourceEntryNumber'] for e in entries],[6,7,8,9,10])
        last = high_entries(self.page('sarang-csat-2000',27))[-1]
        self.assertEqual(last['headword'],'frustration')
        self.assertIn('좌절한 나머지',last['examples'][0]['ko'])

    def test_printed_number_without_zero_is_retained_and_not_dropped(self):
        entries = high_entries(self.page('sarang-csat-2000',134))
        self.assertEqual([e['sourceEntryNumber'] for e in entries],[431,432,433,434,435])
        self.assertEqual(entries[1]['source']['printedEntryNumber'],'432')
        self.assertEqual(entries[1]['headword'],'practical')

    def test_article_a_is_not_answer_marker_and_plural_suffix_stays_attached(self):
        person = self.middle(2,1)
        self.assertEqual(person['examples'][0]['en'],'A cheerful person smiles a lot.')
        self.assertEqual([r['term'] for r in person['relatedWords']],['people','personal'])
        self.assertEqual(self.middle(2,10)['examples'][0]['en'],'Talk to your classmates first.')
        self.assertEqual(self.middle(2,2)['examples'][0]['ko'],
                         '제 소개를 하겠습니다. 제 이름은 Melody Johnson입니다.')

    def test_printed_inflected_answers_are_used(self):
        self.assertEqual(self.middle(3,18)['examples'][0]['en'],'I am pleased to hear the news.')
        self.assertEqual(self.middle(35,158)['examples'][0]['en'],'A rat is running away from a cat.')
        example = self.middle(67,297)['examples'][0]
        self.assertEqual(example['en'],'What are you planning to do this vacation?')
        self.assertEqual(example['answers'],['are','planning to'])

    def test_multiple_blank_patterns_do_not_repeat_entire_headword(self):
        self.assertEqual(self.middle(11,56)['examples'][0]['en'],'He posted a video on YouTube.')
        self.assertEqual(self.middle(31,136)['examples'][0]['en'],'Let’s go swimming this afternoon.')
        result = complete_cloze('{{blank}} me {{blank}}.','give A a hand')
        self.assertEqual(result['en'],'give me a hand.')
        self.assertIsNone(complete_cloze('{{blank}} {{blank}}','unknown')['en'])

    def test_related_word_color_boundary_and_antonyms_are_preserved(self):
        friendly = self.middle(3,11)
        self.assertEqual([(r['term'],r['relation']) for r in friendly['relatedWords']],
                         [('kind','synonym'),('unkind','antonym'),('friend','related')])
        turn = self.middle(39,179)
        self.assertEqual([r['term'] for r in turn['relatedWords']],['turn left','make a right turn'])

    def test_day_labels_ignore_interleaved_entry_numbers_and_print_production_footer(self):
        self.assertEqual(observed_day(self.page('sarang-csat-2000',21)['text']),2)
        self.assertEqual(observed_day(self.page('ebs-middle-excerpt',39)['text']),9)
        self.assertIsNone(observed_day('Monday 11\nWord Coach(Day 6~10).indd'))

    def test_resources_distinguish_cover_reviews_puzzles_and_etymology(self):
        book = 'ebs-middle-excerpt'
        entries = [e for p in self.pages[book] for e in middle_entries(p)]
        resources = {r['page']: r for r in resources_for(book, self.pages[book], entries)}
        self.assertEqual(resources[1]['kind'], 'front_matter')
        self.assertEqual(resources[23]['kind'], 'weekly_review')
        self.assertEqual(resources[24]['kind'], 'puzzle_and_review_answers')
        self.assertEqual(resources[25]['kind'], 'etymology')
        self.assertEqual(resources[47]['reviewDayRange'], [6, 10])
        self.assertIn('DOUBLE PUZZLE 정답', resources[48]['text'])

    def test_half_metadata_keeps_tests_with_the_correct_twenty_entries(self):
        book = 'sarang-csat-2000'
        entries = [e for p in self.pages[book] for e in high_entries(p)]
        resources = {r['page']: r for r in resources_for(book, self.pages[book], entries)}
        self.assertEqual(resources[10]['half'], 'FIRST HALF')
        self.assertEqual(resources[16]['half'], 'SECOND HALF')
        self.assertEqual(resources[411]['day'], 34)
        self.assertEqual(observed_day(resources[411]['text']), 1)  # Original footer conflicts with sidebar.

    def test_etymology_transcriptions_have_source_evidence_and_are_not_approved(self):
        book = 'ebs-middle-excerpt'
        resources = resources_for(book, self.pages[book], [])
        cards = study_supplements(CONTENT/'sources/user-provided/study-supplements.json', resources)
        self.assertEqual(len(cards), 6)
        biography = next(c for c in cards if c['headword'] == 'autobiography')
        self.assertEqual(biography['source']['page'], 25)
        self.assertIn('called Baekbeomilji.', biography['examples'][0]['en'])
        self.assertFalse(biography['humanApproved'])
        self.assertIsNone(biography['recommendedGrade'])
        next(r for r in resources if r['page'] == 49)['text'] = 'missing transcription evidence'
        with self.assertRaisesRegex(ValueError, 'transcription mismatch'):
            study_supplements(CONTENT/'sources/user-provided/study-supplements.json', resources)

    def test_missing_or_duplicate_source_entries_fail_instead_of_silent_partial_import(self):
        entries = middle_entries(self.page('ebs-middle-excerpt',2))
        with self.assertRaisesRegex(ValueError,'entry sequence mismatch'):
            validate_entries('ebs-middle-excerpt',entries)
        with self.assertRaisesRegex(ValueError,'duplicates='):
            validate_entries('ebs-middle-excerpt',entries+entries)
        self.assertIsNone(entries[0]['recommendedGrade'])
        self.assertFalse(entries[0]['humanApproved'])


if __name__=='__main__':
    unittest.main()
