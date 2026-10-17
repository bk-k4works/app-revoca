"""Import the two user-supplied books without treating extraction as approval.

Source entries retain book identity, layout evidence and all printed meanings.
They are deliberately not emitted as approved, disambiguated learning senses.
"""
from __future__ import annotations

import argparse
import gzip
import json
import re
import sqlite3
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

from .common import CONTENT, digest, file_hash, read_json, sources, write_json, write_jsonl

VERSION = 'pdf-books-v1'
BLANK = '{{blank}}'
POS = {'ⓝ': 'n', 'ⓥ': 'v', 'ⓐ': 'adj', 'ⓡ': 'adv', 'ⓟ': 'prep',
       'ⓒ': 'conj', 'ⓘ': 'interj', '명': 'n', '동': 'v', '형': 'adj',
       '부': 'adv', '전': 'prep', '접': 'conj', '감': 'interj', '대': 'pron', '조': 'aux', 'ad': 'adv'}
BOOKS = {
    'sarang-csat-2000': {'title': '사랑 영단어 수능 2000', 'sourceAudience': 'high_school',
                        'expectedPages': 628, 'expectedEntries': 2000,
                        'expectedPdfSha256': '6f67f6c820a72c96e38d09acf20f4df1e2b69e2e465bc78f0384cdbe1e7a0177'},
    'ebs-middle-excerpt': {'title': 'EBS MY WORD COACH 중학 영단어 (첨부 발췌본)',
                           'sourceAudience': 'middle_school', 'expectedPages': 69,
                           'expectedEntries': 300,
                           'expectedPdfSha256': '87a3f8631df4132361b028a78a6bbe42964e47c86520db58eb03fe2d06a29785'},
}


def clean(value):
    return unicodedata.normalize('NFC', value).replace('\u00ad', '').strip()


def lines(words, tolerance=3.8):
    """Group by centre baseline, retaining mixed-font IPA and inline notes."""
    rows = []
    for word in sorted(words, key=lambda w: ((w['top'] + w['bottom']) / 2, w['x0'])):
        cy = (word['top'] + word['bottom']) / 2
        if rows and abs(rows[-1]['cy'] - cy) <= tolerance:
            rows[-1]['words'].append(word)
        else:
            rows.append({'cy': cy, 'words': [word]})
    for row in rows:
        tokens = sorted(row['words'], key=lambda w: w['x0'])
        text, previous = '', None
        for word in tokens:
            if previous and word['x0'] - previous['x1'] > min(previous['size'], word['size']) * .14:
                text += ' '
            text += word['text']
            previous = word
        row['text'] = clean(text)
        row['top'] = min(w['top'] for w in tokens)
        row['bottom'] = max(w['bottom'] for w in tokens)
        row['words'] = tokens
    return rows


def text_of(words):
    return '\n'.join(row['text'] for row in lines(words))


def join_lines(values):
    return re.sub(r'\s+', ' ', ' '.join(values)).strip()


def observed_day(text):
    # A side label can be interleaved with a four-digit entry number in PDF text.
    text = '\n'.join(line for line in text.splitlines() if '.indd' not in line and '.indb' not in line)
    duplicated = re.findall(r'DDAAYY\s+([0-9]{4})',text)
    for value in duplicated:
        if value[0]==value[1] and value[2]==value[3]:
            return int(value[0]+value[2])
    matches = re.findall(r'(?i)(?<![a-z])day\s+(\d{1,2})(?!\d)',text)
    return int(matches[-1]) if matches else None


def cache_layout(pdf_path, cache_dir):
    """Cache visible glyphs only: the CSAT PDF contains off-page duplicate text."""
    import pdfplumber
    pdf_path, cache_dir = Path(pdf_path), Path(cache_dir)
    sha = file_hash(pdf_path)
    cache_dir.mkdir(parents=True, exist_ok=True)
    target = cache_dir / f'{sha}.{VERSION}.jsonl.gz'
    if not target.exists():
        pending = target.with_suffix('.pending')
        with pdfplumber.open(pdf_path) as pdf, gzip.open(pending, 'wt', encoding='utf-8') as out:
            for i, original in enumerate(pdf.pages):
                page = original.filter(lambda c: c.get('x0', 0) >= 0 and
                                       c.get('x1', 0) <= original.width + .1 and
                                       c.get('top', 0) >= 0 and c.get('bottom', 0) <= original.height + .1)
                words = []
                for w in page.extract_words(extra_attrs=['fontname', 'size', 'non_stroking_color']):
                    words.append({'text': w['text'], **{k: round(w[k], 3) for k in
                                  ('x0', 'x1', 'top', 'bottom', 'size')},
                                  'font': w['fontname'].split('+')[-1],
                                  'color': w.get('non_stroking_color')})
                rules = [{'x0': round(e['x0'], 3), 'x1': round(e['x1'], 3), 'y': round(e['top'], 3)}
                         for e in page.edges if abs(e['top'] - e['bottom']) < .1
                         and 20 < e['x1'] - e['x0'] < 180]
                images = [{k: image.get(k) for k in ('name', 'x0', 'x1', 'top', 'bottom', 'srcsize')}
                          for image in page.images]
                record = {'page': i+1, 'width': page.width, 'height': page.height,
                          'words': words, 'rules': rules, 'images': images,
                          'text': page.extract_text() or ''}
                out.write(json.dumps(record, ensure_ascii=False) + '\n')
                original.close()
                if (i+1) % 100 == 0:
                    print(f'Cached {pdf_path.name}: {i+1}/{len(pdf.pages)} pages', flush=True)
        pending.replace(target)
    with gzip.open(target, 'rt', encoding='utf-8') as stream:
        return sha, [json.loads(line) for line in stream]


def base_entry(book, number, page, bbox, term):
    return {'id': f'{book}:{number:04}', 'bookId': book, 'sourceEntryNumber': number,
            'headword': clean(term), 'normalizedHeadword': clean(term).casefold(),
            'source': {'page': page, 'printedPage': page if book == 'sarang-csat-2000' else page+6,
                       'bbox': [round(x, 2) for x in bbox]},
            'sourceAudience': BOOKS[book]['sourceAudience'], 'recommendedGrade': None,
            'difficulty': None, 'curriculumVersion': None,
            'pronunciation': '', 'definitions': [], 'examples': [], 'collocations': [],
            'relatedWords': [], 'notes': [], 'warnings': [],
            'status': 'source_extracted', 'humanApproved': False,
            'senseAssignmentStatus': 'pending_full_review'}


def split_definitions(value, high=False):
    pattern = r'([ⓝⓥⓐⓡⓟⓒⓘ]|(?<!\w)ad(?=\s))' if high else r'(?<!\S)([명동형부전접감대조])(?=\s|$)'
    parts = re.split(pattern, value)
    result = []
    if parts[0].strip():
        result.append({'pos': 'phrase', 'meaningKo': parts[0].strip()})
    for i in range(1, len(parts)-1, 2):
        result.append({'pos': POS[parts[i]], 'meaningKo': parts[i+1].strip()})
    return [r for r in result if r['meaningKo']]


def high_entries(page):
    words = page['words']
    anchors = sorted([w for w in words if re.fullmatch(r'\d{3,4}', w['text'])
                      and w['font'] == 'NotoSansKR-Bold' and abs(w['size']-8) < .1
                      and w['x0'] < 60 and 60 < w['top'] < 590], key=lambda w: w['top'])
    entries = []
    for index, anchor in enumerate(anchors):
        y0 = anchor['top']-1
        y1 = anchors[index+1]['top']-1 if index+1 < len(anchors) else 615
        x = anchor['x0']
        block = [w for w in words if y0 <= w['top'] < y1 and w['x0'] >= x-.1]
        left = [w for w in block if w['x0'] < x+96]
        title = [w for w in left if w['font'] == 'NotoSansKR-Bold' and abs(w['size']-12) < .1]
        term = join_lines([r['text'] for r in lines(title)])
        entry = base_entry('sarang-csat-2000', int(anchor['text']), page['page'],
                           [x, y0, page['width'], y1], term)
        entry['day'] = (entry['sourceEntryNumber']-1)//40 + 1
        entry['part'] = None
        entry['half'] = 'FIRST HALF' if (entry['sourceEntryNumber']-1)%40 < 20 else 'SECOND HALF'
        entry['unitEvidence'] = {'method': 'entry_sequence_and_printed_day_pages',
                                 'unitPage': 5+(entry['day']-1)*12+(6 if entry['half']=='SECOND HALF' else 0)}
        entry['source']['printedEntryNumber'] = anchor['text']
        entry['pronunciation'] = join_lines([r['text'] for r in lines([w for w in left if 'NotoSerif' in w['font']])])
        right = [w for w in block if w['x0'] >= x+96]
        definition = [w for w in right if w['font'] == 'NotoSansKR-Medium']
        entry['definitionText'] = join_lines([r['text'] for r in lines(definition)])
        entry['definitions'] = split_definitions(entry['definitionText'], high=True)
        typed = []
        for kind, selected in [
            ('en', [w for w in right if w['font'] == 'NotoSans-Medium']),
            ('ko', [w for w in right if w['font'] == 'NotoSansKR-Regular' and abs(w['size']-7) < .1]),
            ('citation', [w for w in right if w['font'] == 'NotoSansKR-Regular' and abs(w['size']-6) < .1]),
        ]:
            typed.extend({'kind': kind, **r} for r in lines(selected))
        current = None
        for row in sorted(typed, key=lambda r: r['top']):
            if row['kind'] == 'en':
                if current is None or current['ko']:
                    current = {'en': [], 'ko': [], 'sourceLabels': []}
                    entry['examples'].append(current)
                current['en'].append(row['text'])
            elif current:
                current['ko' if row['kind']=='ko' else 'sourceLabels'].append(row['text'])
            else:
                entry['notes'].append({'kind': 'unassigned_text', 'text': row['text']})
        for example in entry['examples']:
            example['en'] = join_lines(example['en'])
            example['ko'] = join_lines(example['ko'])
            example['kind'] = 'printed_complete_sentence'
        entry['raw'] = {'left': text_of(left), 'right': text_of(right)}
        entries.append(entry)
    return entries


def insert_blanks(words, rules, x0, x1, y0, y1):
    selected = [w for w in words if x0 <= w['x0'] < x1 and y0 <= w['top'] < y1]
    seen = set()
    for rule in rules:
        key = (round(rule['x0'], 1), round(rule['x1'], 1), round(rule['y'], 1))
        if key in seen or not (x0 <= rule['x0'] < rule['x1'] <= x1 and y0 <= rule['y'] < y1):
            continue
        seen.add(key)
        selected.append({'text': BLANK, 'x0': rule['x0'], 'x1': rule['x1'],
                         'top': rule['y']-4.5, 'bottom': rule['y']+2.5,
                         'size': 9, 'font': 'blank_rule', 'color': None})
    return selected


def complete_cloze(template, headword, printed_answer=None):
    count = template.count(BLANK)
    basis = 'printed_answer' if printed_answer else 'entry_headword'
    if printed_answer:
        answers = [a.strip() for a in printed_answer.split(',')] if count>1 else [printed_answer]
    elif count==1:
        answers = [headword]
    elif re.search(r'\b[AB]\b', headword):
        answers = [a.strip() for a in re.split(r'\b[AB]\b',headword) if a.strip()]
        basis = 'entry_pattern_segments'
    elif headword == 'go -ing' and count==2:
        answers, basis = ['go','ing'], 'entry_pattern_segments'
    else:
        answers = []
    completed = template
    if count != len(answers) or count==0:
        completed = None
    else:
        for answer in answers:
            completed = completed.replace(BLANK,answer,1)
    return {'templateEn':template, 'answers':answers, 'answerBasis':basis,
            'printedAnswer':printed_answer, 'en':completed}


def answer_row(row):
    # The English article "A" is not an answer-key marker.
    return any(w['text']=='A' and w['font']=='NanumGothicOTFBold' and w['size']<7
               for w in row['words'])


def translation_words(rows):
    result = []
    for row in rows:
        if not any('YDVYGOStd' in w['font'] and abs(w['size']-8)<.1 for w in row['words']):
            continue
        star_x = min((w['x0'] for w in row['words'] if '★' in w['text']), default=float('inf'))
        result.extend(w for w in row['words'] if w['x0']<star_x and abs(w['size']-8)<.1
                      and ('YDVYGOStd' in w['font'] or w['font']=='Helvetica'))
    return result


def middle_entries(page):
    words = page['words']
    anchors = sorted([w for w in words if re.fullmatch(r'\d{4}', w['text'])
                      and w['font']=='DINPro-Bold' and 80 < w['x0'] < 130
                      and 90 < w['top'] < 725], key=lambda w: w['top'])
    entries = []
    for index, anchor in enumerate(anchors):
        x, y0 = anchor['x0'], anchor['top']-6
        y1 = anchors[index+1]['top']-6 if index+1<len(anchors) else 725
        left = insert_blanks(words, page['rules'], x-.1, x+146, y0, y1)
        right = insert_blanks(words, page['rules'], x+147, x+430, y0, y1)
        title = [w for w in left if w['font']=='Helvetica-Bold' and abs(w['size']-14)<.1]
        entry = base_entry('ebs-middle-excerpt', int(anchor['text']), page['page'],
                           [x, y0, x+430, y1], join_lines([r['text'] for r in lines(title)]))
        entry['day'] = (entry['sourceEntryNumber']-1)//20+1
        part_words = [w for w in words if w['x0']>535 and 90<w['top']<160]
        part_text = ''.join(w['text'] for w in sorted(part_words, key=lambda w:w['top']))
        part_match = re.search(r'PART(\d+)', part_text)
        entry['part'] = int(part_match[1]) if part_match else None
        entry['half'] = None
        entry['unitEvidence'] = {'method': 'entry_sequence_and_printed_day_pages',
                                 'partObservedOnPage': bool(part_match)}
        entry['pronunciation'] = join_lines([r['text'] for r in lines([w for w in left if 'CharisSIL' in w['font']])])
        for warning in ('발음주의', '철자주의'):
            if warning in text_of(left):
                entry['warnings'].append(warning)
        right_lines = lines(right)
        example_lines = [r for r in right_lines if any(w['font']=='Helvetica' and abs(w['size']-9)<.1 for w in r['words'])
                         and BLANK in r['text']]
        example_top = example_lines[0]['top'] if example_lines else y1
        definition_words = [w for w in right if w['top'] < example_top-3 and w['font']!='blank_rule']
        # Blue bold terms separate related words from the main definition.
        dlines = lines(definition_words)
        dtokens = [w for row in dlines for w in row['words']]
        related_groups = []
        for i, w in enumerate(dtokens):
            if w['font']=='Helvetica-Bold' and abs(w['size']-11)<.1:
                if related_groups and related_groups[-1][-1]==i-1 and w['color']==dtokens[i-1]['color']:
                    related_groups[-1].append(i)
                else:
                    related_groups.append([i])
        full_definition = join_lines([r['text'] for r in dlines])
        entry['definitionText'] = full_definition.replace('\ue2a5', '↔')
        marker = re.search(r'\s(?:=|↔)\s', entry['definitionText'])
        cut = marker.start() if marker else len(entry['definitionText'])
        for group in related_groups:
            at = entry['definitionText'].find(dtokens[group[0]]['text'])
            if at >= 0:
                cut = min(cut, at)
        main_definition = entry['definitionText'][:cut].strip()
        entry['definitions'] = split_definitions(main_definition)
        for i, group in enumerate(related_groups):
            term = join_lines([r['text'] for r in lines([dtokens[j] for j in group])])
            end = related_groups[i+1][0] if i+1<len(related_groups) else len(dtokens)
            suffix_words = dtokens[group[0]:end]
            before = join_lines([w['text'] for w in dtokens[:group[0]]]).replace('\ue2a5','↔').rstrip()
            relation = 'synonym' if before.endswith('=') else 'antonym' if before.endswith('↔') else 'related'
            if before.endswith('[') and entry['relatedWords']:
                relation = entry['relatedWords'][-1]['relation']
            source_text = text_of(suffix_words).replace('\ue2a5','↔').rstrip(' =↔[')
            gloss = source_text[len(term):].lstrip(' ]')
            entry['relatedWords'].append({'term': term, 'relation': relation,
                                          'glossText': gloss, 'sourceText': source_text})
        # Keep templates as printed, and a separate deterministic completion.
        answer_lines = [r['text'] for r in right_lines if answer_row(r)]
        answer = re.sub(r'^A\s+', '', answer_lines[0]) if answer_lines else None
        en_rows = [r for r in right_lines if r['top']>=example_top-3 and
                   any(w['font']=='Helvetica' and abs(w['size']-9)<.1 for w in r['words'])
                   and not answer_row(r)]
        # Definition labels and small glossary notes never belong to the sentence.
        en_words = [w for r in en_rows for w in r['words']
                    if (w['font']=='Helvetica' and abs(w['size']-9)<.1) or w['font']=='blank_rule']
        template = join_lines([r['text'] for r in lines(en_words)])
        ko_words = translation_words([r for r in right_lines if r['top']>example_top])
        ko = join_lines([r['text'] for r in lines(ko_words)])
        if template:
            entry['examples'].append({'kind': 'cloze', **complete_cloze(template,entry['headword'],answer),
                                      'ko': ko, 'sourceLabels': []})
        col_words = [w for w in left if (w['font']=='Helvetica' and abs(w['size']-9)<.1) or w['font']=='blank_rule']
        col_template = join_lines([r['text'] for r in lines(col_words)])
        col_ko = translation_words(lines([w for w in left if w['top']>anchor['bottom']+7]))
        if col_template:
            entry['collocations'].append({**complete_cloze(col_template,entry['headword']),
                                          'ko': join_lines([r['text'] for r in lines(col_ko)])})
        answer_words = [w for r in right_lines if answer_row(r) for w in r['words']]
        note_words = [w for w in right if w['top']>=example_top-3 and w not in en_words
                      and w not in ko_words and w not in answer_words]
        if note_words:
            entry['notes'].append({'kind': 'printed_note', 'text': text_of(note_words).replace('\ue2a5','↔')})
        left_extra = [w for w in left if w['top']>anchor['bottom']+14 and w not in col_words and w not in col_ko]
        if left_extra:
            entry['notes'].append({'kind': 'collocation_note', 'text': text_of(left_extra).replace('\ue2a5','↔')})
        entry['raw'] = {'left': text_of(left), 'right': text_of(right).replace('\ue2a5','↔')}
        entries.append(entry)
    return entries


def resources_for(book, pages, entries):
    entry_pages = defaultdict(list)
    for entry in entries:
        entry_pages[entry['source']['page']].append(entry)
    resources = []
    current_day = None
    for page in pages:
        text = page['text']
        number = page['page']
        half = None
        if book == 'sarang-csat-2000' and 5 <= number <= 604:
            current_day = (number-5)//12+1
            half = 'FIRST HALF' if (number-5)%12 < 6 else 'SECOND HALF'
        elif page_day := observed_day(text):
            current_day = page_day
        if (book == 'sarang-csat-2000' and number < 5) or (book == 'ebs-middle-excerpt' and number == 1):
            kind, current_day = 'front_matter', None
        elif number in entry_pages:
            kind = 'entry_page'
            current_day = entry_pages[number][0]['day']
        elif book == 'ebs-middle-excerpt' and number in (25, 49):
            kind = 'etymology'
        elif book == 'ebs-middle-excerpt' and number in (24, 48):
            kind = 'puzzle_and_review_answers'
        elif book == 'ebs-middle-excerpt' and number in (22, 23, 46, 47):
            kind = 'weekly_review'
        elif 'WORD TEST' in text or 'Check Up' in text or '정답' in text:
            kind = 'exercise'
        elif book=='sarang-csat-2000' and page['page']>=605:
            kind = 'index'
            current_day = None
        elif 'HALF' in text and book=='sarang-csat-2000' and page['page']>=5:
            kind = 'unit_overview'
        else:
            kind = 'front_matter'
        resource = {'id': f'{book}:page:{page["page"]}', 'bookId': book,
                    'page': page['page'], 'kind': kind, 'day': current_day, 'half': half,
                    'part': 1 if book == 'ebs-middle-excerpt' and number > 1 else None,
                    'text': text, 'images': page['images'],
                    'entryIds': [e['id'] for e in entry_pages.get(page['page'], [])]}
        if kind in ('weekly_review', 'puzzle_and_review_answers', 'etymology'):
            resource['reviewDayRange'] = [1, 5] if number <= 25 else [6, 10]
            resource['rangeEvidence'] = 'position_after_five_days_in_supplied_excerpt'
        resource['externalReferences'] = sorted(set(re.findall(r'(?:https?://)?(?:www\.)?[A-Za-z0-9.-]+\.(?:co\.kr|com|org|kr)(?:/[A-Za-z0-9_./?=&%-]*)?',text)))
        if kind in ('exercise', 'weekly_review', 'puzzle_and_review_answers'):
            resource['reuseIdeas'] = ['meaning_recall', 'spelling', 'cloze', 'unit_review']
            resource['itemParsingStatus'] = 'page_preserved_requires_question_answer_review'
        resources.append(resource)
    return resources


def study_supplements(path, resources):
    info = read_json(path)
    book = info['bookId']
    if info['pdfSha256'] != BOOKS[book]['expectedPdfSha256']:
        raise ValueError('Supplement source edition mismatch')
    by_id = {r['id']: r for r in resources}
    result = []
    for group in info['groups']:
        resource = by_id[f'{book}:page:{group["page"]}']
        if resource['kind'] != 'etymology':
            raise ValueError('Supplement page kind mismatch')
        for card in group['cards']:
            # The three diagram columns interleave in PDF reading order.
            # Require every transcribed token in order, allowing other columns between lines.
            for text in [card['headword']] + [v for ex in card['examples'] for v in (ex['en'], ex['ko'])]:
                pattern = '.*?'.join(re.escape(token) for token in text.split())
                if not re.search(pattern, resource['text'], re.DOTALL):
                    raise ValueError(f'Supplement transcription mismatch: {card["headword"]}')
            row = {'id': f'{book}:supplement:{group["root"]}:{card["headword"]}',
                   'bookId': book, 'kind': 'printed_etymology_card', **card,
                   'root': {k: group[k] for k in ('root', 'rootMeaningKo', 'rootMeaningEn')},
                   'source': {'page': group['page'], 'printedPage': group['printedPage'],
                              'resourceId': resource['id'], 'pdfSha256': info['pdfSha256']},
                   'transcriptionMethod': info['method'], 'reviewStatus': info['reviewStatus'],
                   'recommendedGrade': None, 'difficulty': None, 'humanApproved': False}
            row['contentHash'] = digest(row)
            result.append(row)
    return result


def high_index(pages, entries):
    by_term_page = {(e['normalizedHeadword'],e['source']['page']):e['id'] for e in entries}
    result = []
    for page in pages[605:]:
        for number in page['words']:
            if not (number['text'].isdigit() and number['font']=='NotoSansKR-Regular' and abs(number['size']-8)<.1):
                continue
            terms = [w for w in page['words'] if w['font']=='NotoSansKR-Medium' and abs(w['size']-8)<.1
                     and abs(w['top']-number['top'])<2 and number['x0']-120<w['x0']<number['x0']]
            term = join_lines([r['text'] for r in lines(terms)])
            if term:
                target_page = int(number['text'])
                result.append({'term':term,'targetPage':target_page,'indexPage':page['page'],
                               'entryId':by_term_page.get((term.casefold(),target_page))})
    if len(result)!=2000 or any(r['entryId'] is None for r in result) or len({r['entryId'] for r in result})!=2000:
        raise ValueError('The 2,000 index references do not match extracted headwords/pages one-to-one')
    return result


def apply_corrections(entries, correction_file):
    info = read_json(correction_file)
    by_id = {e['id']:e for e in entries}
    for change in info['corrections']:
        if change['entryId'] not in by_id:
            continue
        entry = by_id[change['entryId']]
        field = change['field']
        if entry[field]!=change['before'] or entry['source']['page']!=change['physicalPage']:
            raise ValueError(f'Stale extraction correction: {change["entryId"]}')
        entry[field+'Raw'] = entry[field]
        entry[field] = change['after']
        entry.setdefault('extractionCorrections',[]).append({**change,'method':info['method']})


def create_library(path, books, entries, resources, units, supplements):
    """A queryable source library; not the app's approved content database."""
    path = Path(path)
    pending = path.with_suffix('.pending.sqlite')
    if pending.exists():
        pending.unlink()
    with sqlite3.connect(pending) as db:
        db.execute('PRAGMA foreign_keys=ON')
        db.executescript('''
            CREATE TABLE books (id TEXT PRIMARY KEY, title TEXT NOT NULL, payload TEXT NOT NULL);
            CREATE TABLE source_entries (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id),
                term TEXT NOT NULL, normalized_term TEXT NOT NULL, day INTEGER NOT NULL,
                page INTEGER NOT NULL, payload TEXT NOT NULL);
            CREATE INDEX source_term ON source_entries(normalized_term);
            CREATE TABLE examples (entry_id TEXT NOT NULL REFERENCES source_entries(id), position INTEGER NOT NULL,
                en TEXT NOT NULL, ko TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(entry_id,position));
            CREATE TABLE collocations (entry_id TEXT NOT NULL REFERENCES source_entries(id), position INTEGER NOT NULL,
                en TEXT NOT NULL, ko TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(entry_id,position));
            CREATE TABLE related_words (entry_id TEXT NOT NULL REFERENCES source_entries(id), position INTEGER NOT NULL,
                term TEXT NOT NULL, relation TEXT NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(entry_id,position));
            CREATE TABLE resources (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id),
                page INTEGER NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL);
            CREATE TABLE units (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id), payload TEXT NOT NULL);
            CREATE TABLE unit_entries (unit_id TEXT NOT NULL REFERENCES units(id), entry_id TEXT NOT NULL REFERENCES source_entries(id),
                position INTEGER NOT NULL, PRIMARY KEY(unit_id,entry_id));
            CREATE TABLE study_supplements (id TEXT PRIMARY KEY, book_id TEXT NOT NULL REFERENCES books(id),
                resource_id TEXT NOT NULL REFERENCES resources(id), term TEXT NOT NULL, payload TEXT NOT NULL);
        ''')
        encode = lambda x:json.dumps(x,ensure_ascii=False,sort_keys=True)
        db.executemany('INSERT INTO books VALUES (?,?,?)',[(b['bookId'],b['title'],encode(b)) for b in books])
        for entry in entries:
            db.execute('INSERT INTO source_entries VALUES (?,?,?,?,?,?,?)',
                       (entry['id'],entry['bookId'],entry['headword'],entry['normalizedHeadword'],entry['day'],entry['source']['page'],encode(entry)))
            for table, field in [('examples','examples'),('collocations','collocations')]:
                db.executemany(f'INSERT INTO {table} VALUES (?,?,?,?,?)',
                    [(entry['id'],i,r['en'] or '',r['ko'],encode(r)) for i,r in enumerate(entry[field])])
            db.executemany('INSERT INTO related_words VALUES (?,?,?,?,?)',
                [(entry['id'],i,r['term'],r['relation'],encode(r)) for i,r in enumerate(entry['relatedWords'])])
        db.executemany('INSERT INTO resources VALUES (?,?,?,?,?)',
                       [(r['id'],r['bookId'],r['page'],r['kind'],encode(r)) for r in resources])
        db.executemany('INSERT INTO study_supplements VALUES (?,?,?,?,?)',
                       [(s['id'],s['bookId'],s['source']['resourceId'],s['headword'],encode(s)) for s in supplements])
        for unit in units:
            db.execute('INSERT INTO units VALUES (?,?,?)',(unit['id'],unit['bookId'],encode(unit)))
            db.executemany('INSERT INTO unit_entries VALUES (?,?,?)',[(unit['id'],eid,i) for i,eid in enumerate(unit['entryIds'])])
        if db.execute('PRAGMA foreign_key_check').fetchall() or db.execute('PRAGMA integrity_check').fetchone()[0]!='ok':
            raise ValueError('Source library integrity failure')
    pending.replace(path)


def validate_entries(book, entries):
    numbers = [e['sourceEntryNumber'] for e in entries]
    expected = list(range(1, BOOKS[book]['expectedEntries']+1))
    if sorted(numbers) != expected:
        missing = sorted(set(expected)-set(numbers))
        duplicates = [n for n,c in Counter(numbers).items() if c>1]
        raise ValueError(f'{book}: entry sequence mismatch, missing={missing}, duplicates={duplicates}')
    issues = []
    for entry in entries:
        flags = list(entry.get('sourceWarnings',[]))
        if not entry['headword'] or not re.search(r'[A-Za-z]',entry['headword']):
            flags.append('missing_headword')
        if not entry['definitions'] or not all(re.search(r'[가-힣]',d['meaningKo']) for d in entry['definitions']):
            flags.append('definition_requires_review')
        if not entry['examples']:
            flags.append('missing_example')
        for i, example in enumerate(entry['examples']):
            if not example['en'] or not example['ko']:
                flags.append(f'example_{i+1}_pair_incomplete')
            if example['kind']=='cloze' and (not example['en'] or example['templateEn'].count(BLANK)!=len(example['answers'])):
                flags.append(f'example_{i+1}_unresolved_blanks')
        for i, collocation in enumerate(entry['collocations']):
            if not collocation['en'] or not collocation['ko']:
                flags.append(f'collocation_{i+1}_pair_incomplete')
        if book == 'ebs-middle-excerpt' and len(entry['collocations']) != 1:
            flags.append('collocation_count_requires_review')
        if '�' in json.dumps({k:v for k,v in entry.items() if k not in ('raw','pronunciationRaw','extractionCorrections')},ensure_ascii=False):
            flags.append('unmapped_pdf_glyph')
        if entry.get('extractionCorrections'):
            flags.append('visually_transcribed_ipa_needs_phonetic_review')
        if len(entry['definitions'])>1:
            flags.append('multiple_printed_pos_or_meanings')
        if any(';' in d['meaningKo'] for d in entry['definitions']):
            flags.append('printed_meanings_need_sense_split')
        entry['qualityFlags'] = flags
        if flags:
            issues.append({'entryId':entry['id'], 'headword':entry['headword'],
                           'page':entry['source']['page'], 'flags':flags})
    return issues


def import_books(high_path, middle_path, output, cache_dir):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=True)
    all_entries, all_resources, manifests, all_issues, index = [], [], [], [], []
    corrections = CONTENT/'sources/user-provided/extraction-corrections.json'
    for book, path, extractor in [('sarang-csat-2000', high_path, high_entries),
                                   ('ebs-middle-excerpt', middle_path, middle_entries)]:
        if file_hash(path)!=BOOKS[book]['expectedPdfSha256']:
            raise ValueError(f'{book}: different PDF edition; register it under a separate book identity')
        sha, pages = cache_layout(path, cache_dir)
        if len(pages) != BOOKS[book]['expectedPages']:
            raise ValueError(f'{book}: unsupported PDF page count')
        entries = [e for page in pages for e in extractor(page)]
        # Propagate only an observed Part, never infer a school grade.
        if book=='ebs-middle-excerpt':
            observed = {e['part'] for e in entries if e['part'] is not None}
            if len(observed)==1:
                for entry in entries:
                    if entry['part'] is None:
                        entry['part'] = next(iter(observed))
                        entry['unitEvidence']['partInheritedFromSameExcerpt'] = True
        apply_corrections(entries,corrections)
        if book=='sarang-csat-2000':
            index = high_index(pages,entries)
        for entry in entries:
            actual_day = observed_day(pages[entry['source']['page']-1]['text'])
            entry['unitEvidence']['observedDayOnEntryPage'] = actual_day
            if actual_day and actual_day!=entry['day']:
                entry.setdefault('sourceWarnings',[]).append('printed_page_day_conflicts_with_unit_sequence')
            if book=='sarang-csat-2000':
                unit_text = pages[entry['unitEvidence']['unitPage']-1]['text']
                unit_day = observed_day(unit_text)
                if unit_day!=entry['day'] or entry['half'] not in unit_text:
                    raise ValueError(f'Unit overview mismatch: {entry["id"]}')
        issues = validate_entries(book, entries)
        resources = resources_for(book, pages, entries)
        all_entries.extend(entries)
        all_resources.extend(resources)
        all_issues.extend(issues)
        manifests.append({'bookId':book, **BOOKS[book], 'inputPath':str(Path(path).resolve()),
                          'pdfSha256':sha, 'pageCount':len(pages), 'entryCount':len(entries),
                          'days':sorted({e['day'] for e in entries}),
                          'parts':sorted({e['part'] for e in entries if e['part'] is not None}),
                          'exampleCount':sum(len(e['examples']) for e in entries),
                          'rightsStatus':'not_verified_for_distribution',
                          'rightsNotice': next(('EBS의 허락없이'+p['text'].split('EBS의 허락없이',1)[1].split('\n')[0]
                                                for p in pages if 'EBS의 허락없이' in p['text']), None)})
        print(f'Extracted {book}: {len(entries)} entries, {sum(len(e["examples"]) for e in entries)} examples', flush=True)
    source = sources()
    aliases = defaultdict(list)
    for headword, row in source.items():
        for alias in row['variants']+row['related_forms']:
            aliases[alias.casefold()].append(headword)
    for entry in all_entries:
        term = entry['normalizedHeadword']
        entry['curriculumMatch'] = {'kind':'exact', 'headwords':[term]} if term in source else {
            'kind':'variant_or_related' if term in aliases else 'outside_representative_list',
            'headwords':sorted(set(aliases[term]))}
        entry['contentHash'] = digest(entry)
    by_id = {e['id']:e for e in all_entries}
    for issue in all_issues:
        issue['contentHash'] = by_id[issue['entryId']]['contentHash']
    units = defaultdict(list)
    for entry in all_entries:
        unit = (entry['bookId'],entry['day'],entry['part'],entry['half'])
        units[unit].append(entry['id'])
    unit_rows = [{'id':f'{b}:day:{d:02}:{h or "whole"}', 'bookId':b, 'day':d,'part':p,'half':h,
                 'entryIds':ids, 'suggestedStudyBatchSize':5, 'gradeAssignment':None}
                for (b,d,p,h),ids in units.items()]
    for unit in unit_rows:
        unit['resourceIds'] = [r['id'] for r in all_resources if r['bookId']==unit['bookId']
                               and r['day']==unit['day'] and r['half']==unit['half']
                               and r['kind'] in ('exercise','weekly_review','unit_overview',
                                                 'puzzle_and_review_answers','etymology')]
    supplements_path = CONTENT/'sources/user-provided/study-supplements.json'
    supplements = study_supplements(supplements_path, all_resources)
    by_term = defaultdict(list)
    for entry in all_entries:
        by_term[entry['normalizedHeadword']].append(entry['id'])
    write_jsonl(output/'entries.jsonl', all_entries)
    write_jsonl(output/'pages.jsonl', all_resources)
    write_jsonl(output/'review-queue.jsonl', all_issues)
    write_json(output/'units.json', unit_rows)
    write_json(output/'source-index.json',index)
    write_jsonl(output/'study-supplements.jsonl', supplements)
    write_json(output/'overlap.json', {
        'uniqueHeadwordCount':len(by_term),
        'duplicates':{k:v for k,v in by_term.items() if len(v)>1},
        'curriculumMatchCounts':dict(Counter(e['curriculumMatch']['kind'] for e in all_entries)),
        'mergePolicy':'same spelling is a lookup group, not proof of semantic identity'})
    create_library(output/'library.sqlite',manifests,all_entries,all_resources,unit_rows,supplements)
    manifest = {'formatVersion':VERSION, 'extractionToolSha256':file_hash(__file__),
                'books':manifests,'entryCount':len(all_entries),'uniqueHeadwordCount':len(by_term),
                'exampleCount':sum(len(e['examples']) for e in all_entries),
                'collocationCount':sum(len(e['collocations']) for e in all_entries),
                'relatedWordCount':sum(len(e['relatedWords']) for e in all_entries),
                'resourcePageCount':len(all_resources), 'resourceKinds':dict(Counter(r['kind'] for r in all_resources)),
                'unitCount':len(unit_rows), 'sourceIndexReferencesVerified':len(index),
                'extractionCorrectionsSha256':file_hash(corrections),
                'studySupplementsSourceSha256':file_hash(supplements_path),
                'supplementCardCount':len(supplements),
                'supplementExampleCount':sum(len(s['examples']) for s in supplements),
                'reviewQueueEntryCount':len(all_issues),
                'reviewFlagCounts':dict(Counter(f for r in all_issues for f in r['flags'])),
                'humanApproved':0,'gradeClassificationStatus':'deferred_by_user',
                'appReleaseInstalled':False,
                'files':{p.name:file_hash(p) for p in sorted(output.iterdir()) if p.name in
                         ('entries.jsonl','pages.jsonl','review-queue.jsonl','units.json','overlap.json',
                          'source-index.json','study-supplements.jsonl','library.sqlite')}}
    write_json(output/'manifest.json',manifest)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--high',type=Path,required=True)
    parser.add_argument('--middle',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--cache',type=Path,required=True)
    args = parser.parse_args()
    result = import_books(args.high,args.middle,args.output,args.cache)
    print(json.dumps({k:v for k,v in result.items() if k!='books'},ensure_ascii=False,indent=2))


if __name__ == '__main__':
    main()
