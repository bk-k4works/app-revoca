import copy
import unittest

from tool.content.audit import compare, snapshot


def sense(sid, meaning):
    return {'id': sid, 'headwordId': sid, 'headword': sid, 'pos': 'n',
            'meaningKo': meaning, 'meaningKoAlt': [], 'distractorExclusions': [],
            'collocation': sid + ' context'}


class IncrementalAuditTest(unittest.TestCase):
    def test_unchanged_snapshot_requires_no_new_work_but_is_not_approval(self):
        old = snapshot([sense('a', '나무')], 'v1', 'rules')
        new = snapshot([sense('a', '나무')], 'v2', 'rules')
        queue = compare(new, old)
        self.assertEqual(queue['contentReviewRequired'], [])
        self.assertEqual(queue['quizReviewRequired'], [])
        self.assertIn('does not mean approved', queue['notice'])

    def test_added_word_requeues_affected_existing_questions(self):
        base = [sense('a', '나무'), sense('b', '하늘'), sense('c', '바다')]
        old = snapshot(base, 'v1', 'rules')
        new = snapshot(base + [sense('d', '구름')], 'v2', 'rules')
        queue = compare(new, old)
        self.assertEqual(queue['contentReviewRequired'], ['d'])
        self.assertEqual(queue['quizChanged'], ['a', 'b', 'c'])
        self.assertEqual(queue['quizReviewRequired'], ['a', 'b', 'c', 'd'])
        self.assertEqual(new['items']['a']['quiz']['mode'], 'multiple_choice')

    def test_translation_only_change_requeues_content_not_choices(self):
        base = [sense('a', '나무')]
        old = snapshot(base, 'v1', 'rules')
        changed = copy.deepcopy(base)
        changed[0]['examples'] = [{'en': 'A tree grows here.', 'ko': '여기서 나무가 자라요.'}]
        queue = compare(snapshot(changed, 'v2', 'rules'), old)
        self.assertEqual(queue['contentReviewRequired'], ['a'])
        self.assertEqual(queue['quizReviewRequired'], [])

    def test_removal_and_rule_change_cannot_be_silently_skipped(self):
        base = [sense(c, m) for c, m in zip('abcd', ['나무', '하늘', '바다', '구름'])]
        old = snapshot(base, 'v1', 'rules')
        queue = compare(snapshot(base[:3], 'v2', 'new-rules'), old)
        self.assertEqual(queue['removed'], ['d'])
        self.assertTrue(queue['rulesChanged'])
        self.assertEqual(queue['contentReviewRequired'], list('abc'))
        self.assertEqual(queue['quizReviewRequired'], list('abc'))
