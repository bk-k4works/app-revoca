"""Materialize the hand-authored rows; run from repo root with PYTHONPATH=."""
from pathlib import Path

from tool.content.common import read_json, require, sources, write_jsonl

HERE = Path(__file__).resolve().parent
SOURCE = sources()
SYNONYMS = {
    'able': ['capable'], 'achieve': ['accomplish'], 'advertize': ['promote'],
    'analyze': ['examine'], 'attention': ['notice'], 'bad': ['poor'],
    'brilliant': ['excellent', 'bright'], 'catalogue': ['list'], 'chase': ['pursue'],
    'check': ['examine', 'confirm'], 'circumstance': ['situation'], 'close': ['shut', 'near'],
    'compare': ['contrast'], 'consume': ['use', 'eat'], 'courage': ['bravery'],
    'crucial': ['important', 'essential'], 'describe': ['explain'], 'drill': ['practice'],
    'environ': ['surround'], 'explode': ['burst'], 'fasten': ['attach'], 'fate': ['destiny'],
    'get': ['receive', 'become'], 'hall': ['corridor'], 'install': ['place'],
    'join': ['participate', 'connect'], 'lead': ['guide'], 'light': ['bright'],
    'live': ['reside'], 'migrate': ['move'], 'minute': ['tiny'], 'motor': ['engine'],
    'neat': ['tidy'], 'opportune': ['timely'], 'particular': ['specific'],
    'pat': ['tap'], 'practice': ['exercise', 'train'], 'prepare': ['arrange'],
    'press': ['push'], 'principal': ['main', 'chief'], 'prohibit': ['forbid', 'ban'],
    'quite': ['rather', 'completely'], 'rat': ['mouse'], 'relax': ['rest'],
    'request': ['ask', 'demand'], 'revive': ['restore'], 'right': ['correct'],
    'run': ['operate'], 'sacred': ['holy'], 'set': ['put', 'place'], 'spoil': ['ruin'],
    'stain': ['mark'], 'take': ['bring', 'carry'], 'territory': ['area', 'zone'],
    'threat': ['danger'], 'toxic': ['poisonous'], 'transmit': ['send'],
    'vague': ['unclear'], 'view': ['scene', 'opinion'], 'vivid': ['clear', 'bright'],
    'zone': ['area', 'territory'],
}
CONFUSABLES = {'principal': ['principle'], 'quite': ['quiet'], 'adapt': ['adopt'],
               'affect': ['effect'], 'identity': ['identify'], 'environ': ['environment'],
               'opportune': ['opportunity'], 'view': ['review'], 'write': ['right'],
               'right': ['write'], 'pat': ['pet'], 'rat': ['rate']}
NOTES = {
    'advertize': ['source_headword_spelling_review: 원천 표제어는 advertize, 예문에는 advertise를 사용함'],
    'congress': ['primary_selection_review: 정치 소재 제한 때문에 학술 대회 의미만 제안함; 대표 의미 적합성 재검토'],
    'environ': ['register_review: 문어적 용법의 교육 적합성 검토', 'legacy_identity: environment와 의미를 합치지 않음'],
    'identity': ['legacy_identity: identify의 기존 학습 의미와 다름'],
    'opportune': ['legacy_identity: opportunity의 기존 학습 의미와 다름'],
    'view': ['legacy_identity: review의 기존 학습 의미와 다름'],
    'check': ['sense_specific_spelling: cheque는 수표 명사 후보에만 허용'],
    'practice': ['sense_specific_spelling: practise는 동사 후보에만 허용'],
    'upward': ['sense_specific_spelling: upwards는 부사 후보에만 허용'],
    'a': ['grammar_review: an은 모음 소리 앞의 관사 형태이며 무조건 교환 가능한 철자가 아님'],
    'be': ['grammar_review: 시제·인칭 굴절형과 진행형 조동사를 구별해야 함'],
    'yes': ['register_review: yeah와 yep는 비격식 대답'],
    'funeral': ['sensitive_topic_review: 사별 소재의 연령 적합성 검토'],
    'revenge': ['sensitive_topic_review: 복수를 권하지 않는 문학 맥락이지만 소재 적합성 검토'],
    'starve': ['sensitive_topic_review: 굶주림과 생존 소재의 연령 적합성 검토'],
    'sacred': ['culture_review: 특정 신앙을 권하지 않는 문화 설명'],
}


def main():
    entries = {}
    for number, line in enumerate((HERE / 'codex-authored.txt').read_text().splitlines(), 1):
        if not line or line.startswith('#'):
            continue
        fields = line.split('|')
        require(len(fields) == 11, f'Line {number}: expected eleven fields')
        word, pos, slug, meaning, explanation, collocation, collocation_ko, en1, ko1, en2, ko2 = fields
        require(word in SOURCE, f'Unknown source headword: {word}')
        entry = entries.setdefault(word, {'headword': word, 'senseCandidates': [], 'flags': NOTES.get(word, []).copy()})
        require((pos, slug) not in {(c['pos'], c['senseSlug']) for c in entry['senseCandidates']},
                f'Duplicate candidate: {word}.{pos}.{slug}')
        primary = not entry['senseCandidates']
        spellings = [word, *SOURCE[word]['variants']]
        if (word == 'check' and pos != 'n') or (word == 'practice' and pos == 'n') or (word == 'upward' and pos == 'adj'):
            spellings = [word]
        entry['senseCandidates'].append({
            'pos': pos, 'senseSlug': slug, 'meaningKo': meaning, 'meaningKoAlt': [],
            'whyPrimary': (f"'{collocation_ko}' 맥락의 첫 학습 의미로 제안해요. 빈도 순위에 근거한 선정은 아니에요."
                           if primary else f"'{collocation_ko}' 용례를 대표 제안과 구별해 비교하기 위한 후보예요."),
            'isPrimaryProposal': primary, 'explanationKo': explanation,
            'collocation': collocation, 'collocationKo': collocation_ko,
            'examples': [{'en': en1, 'ko': ko1}, {'en': en2, 'ko': ko2}],
            'acceptedSpellings': spellings, 'confusableHeadwords': CONFUSABLES.get(word, []),
            'nearSynonymHeadwords': SYNONYMS.get(word, []),
        })
    sample = read_json(HERE / 'sample.json')
    require(set(entries) == {e['headword'] for e in sample['entries']}, 'Authored rows must match all 100 pilot headwords')
    for entry in entries.values():
        if len(entry['senseCandidates']) == 1:
            entry['flags'].append('single_sense_candidate')
    write_jsonl(HERE / 'codex.authored.jsonl', [entries[w] for w in sorted(entries)])
    print({'headwords': len(entries), 'senseCandidates': sum(len(e['senseCandidates']) for e in entries.values())})


if __name__ == '__main__':
    main()
