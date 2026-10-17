"""Deterministic checks. Unknown morphology is surfaced, never silently approved."""
import copy
import re
from collections import Counter, defaultdict
from difflib import SequenceMatcher

from .common import CONTENT, SOURCE, digest, read_json, read_jsonl, require, schema_validate, sources, write_jsonl

WORD = re.compile(r"[A-Za-z]+(?:['’-][A-Za-z]+)*|\d+")
HOMOGRAPHS = {"record", "read", "live", "lead", "present", "object", "close", "wind", "tear",
              "bow", "use", "minute", "produce", "refuse", "conduct", "content", "desert", "bass"}
# Style rules per audience. The middle-school profile keeps the original pilot rules.
MIDDLE = {'name': 'middle', 'tokens': (6, 14), 'ko': (r'요[.!?]?$', 'translation must use 해요체')}
HIGH = {'name': 'high', 'tokens': (6, 20), 'forms': 'sources/word_forms_high.json',
        'ko': (r'(?<!요)(다|까|가|냐|니|라|자|지)[.!?]?$', 'translation must use 평서체 (~다)')}


def forms_config(profile):
    config = read_json(CONTENT / "sources/word_forms.json")
    extra = profile.get('forms')
    if extra:
        extra = read_json(CONTENT / extra)
        config = {**config, 'allowedTokens': [*config['allowedTokens'], *extra['allowedTokens']],
                  'irregular': {**config['irregular'], **extra['irregular']},
                  'allowDigits': extra.get('allowDigits', False)}
    return config


def tokens(text):
    return WORD.findall(text.lower().replace("’", "'"))


class Lemmatizer:
    """Conservative lexicon-constrained English inflection/derivation rules.

    Exact lexical forms and explicit irregulars take precedence. Derivations are
    used for vocabulary scope only, never for target-word occurrence counting.
    Exceptions/extensions live in a versioned data file for editorial review.
    """
    def __init__(self, source_rows, config=None):
        self.config = config or read_json(CONTENT / "sources/word_forms.json")
        self.lexicon = {word.lower() for row in source_rows.values()
                        for word in [row['headword'], *row['variants'], *row.get('related_forms', [])]}
        # Words inside multiword headwords (per capita, vice versa) are in scope too.
        self.lexicon |= {part for word in list(self.lexicon) if ' ' in word for part in tokens(word)}
        self.allowed = {w.lower() for w in self.config["allowedTokens"]}

    def inflections(self, word):
        values = {word}
        values.update(self.config['irregular'].get(word, []))
        if word.endswith("'s"):
            values.add(word[:-2])
        if word.endswith('ies'):
            values.add(word[:-3] + 'y')
        if word.endswith('ied'):
            values.add(word[:-3] + 'y')
        for ending in ['s', 'es', 'ed', 'ing', 'er', 'est']:
            if word.endswith(ending) and len(word) > len(ending) + 1:
                stem = word[:-len(ending)]
                values.add(stem)
                if ending in {'ed', 'ing', 'er', 'est'}:
                    values.add(stem + 'e')
                    if len(stem) >= 2 and stem[-1] == stem[-2]:
                        values.add(stem[:-1])
                    if stem.endswith('i'):
                        values.add(stem[:-1] + 'y')
        return values

    def in_scope(self, word):
        if word in self.allowed or word in self.lexicon or (word.isdigit() and self.config.get('allowDigits')):
            return True
        forms = self.inflections(word)
        if forms & self.lexicon:
            return True
        # Explicit irregular derivations affect vocabulary scope, never target counts.
        for form in forms:
            if set(self.config.get('scopeDerivations', {}).get(form, [])) & self.lexicon:
                return True
        for form in forms:
            for prefix in self.config['prefixes']:
                if form.startswith(prefix) and form[len(prefix):] in self.lexicon:
                    return True
            for suffix in self.config['suffixes']:
                if form.endswith(suffix):
                    stem = form[:-len(suffix)]
                    candidates = {stem, stem + 'e'}
                    if stem.endswith('i'):
                        candidates.add(stem[:-1] + 'y')
                    if candidates & self.lexicon:
                        return True
        # Contractions require an explicit expansion; proper names are not auto allowed.
        expansion = self.config['contractions'].get(word)
        return bool(expansion and all(self.in_scope(part) for part in expansion))

    def target_count(self, text, spellings):
        sentence = tokens(text)
        matches = set()
        for spelling in spellings:
            parts = tokens(spelling)
            for index in range(len(sentence) - len(parts) + 1):
                if all(base in self.inflections(sentence[index + offset]) for offset, base in enumerate(parts)):
                    matches.add((index, len(parts)))
        return len(matches)


def normalize_meaning(text):
    return re.sub(r"[\s.,!?·~～()]+", "", text).casefold()


def exclusions(senses):
    """Connected groups avoid indirect A~B~C collisions as well as direct edges."""
    parent = {s['id']: s['id'] for s in senses}
    def root(value):
        while parent[value] != value:
            parent[value] = parent[parent[value]]
            value = parent[value]
        return value
    def union(a, b):
        parent[root(b)] = root(a)
    by_word, by_meaning = {}, {}
    for sense in senses:
        by_word.setdefault(sense['headword'].lower(), []).append(sense['id'])
        for meaning in [sense['meaningKo'], *sense.get('meaningKoAlt', [])]:
            key = normalize_meaning(meaning)
            if key in by_meaning:
                union(sense['id'], by_meaning[key])
            by_meaning[key] = sense['id']
    for sense in senses:
        for word in [sense['headword'], *sense.get('nearSynonymHeadwords', []), *sense.get('confusableHeadwords', [])]:
            for other in by_word.get(word.lower(), []):
                union(sense['id'], other)
    groups = {}
    for sense in senses:
        groups.setdefault(root(sense['id']), set()).add(sense['id'])
    return {s['id']: sorted(groups[root(s['id'])] - {s['id']}) for s in senses}


def validate_record(record, source_rows, lemmatizer=None, profile=MIDDLE):
    record = copy.deepcopy(record)
    data = record.get('data')
    errors = schema_validate(data, 'generation')
    warnings, flags = [], []
    if errors:
        record.update(status='needs_fix', autoValidation={'errors': errors, 'warnings': [], 'flags': []})
        return record
    word = data['headword']
    source = source_rows.get(word)
    if not source or record.get('headword') != word:
        errors.append('Headword missing from source or envelope mismatch')
    elif record.get('source') != source:
        errors.append('Source metadata does not match current source CSV')
    lemmatizer = lemmatizer or Lemmatizer(source_rows)
    if sum(c['isPrimaryProposal'] for c in data['senseCandidates']) != 1:
        errors.append('Exactly one primary sense proposal is required')
    if len(data['senseCandidates']) == 1:
        if 'single_sense_candidate' not in data['flags']:
            errors.append('A single candidate needs the single_sense_candidate editorial flag')
        else:
            warnings.append('Only one sense candidate proposed; confirm coverage during editorial review')
    identities = [(c['pos'], c['senseSlug']) for c in data['senseCandidates']]
    if len(set(identities)) != len(identities):
        errors.append('Duplicate sense candidate identifiers')
    for i, candidate in enumerate(data['senseCandidates']):
        label = f'senseCandidates.{i}'
        if source:
            spellings = set(candidate['acceptedSpellings'])
            if word not in spellings or not spellings <= {word, *source['variants']}:
                errors.append(f'{label}: accepted spellings must contain the headword and only source variants')
            # Source variants can be sense-specific (check/cheque, practice/practise).
            # Preserve the author's explicit subset; do not add them to every sense.
            candidate['acceptedSpellings'] = sorted(spellings)
        explanation = candidate['explanationKo']
        if len(explanation) > 40 or not re.search(r'요[.!?]?$', explanation):
            warnings.append(f'{label}: explanation must be <=40 characters and 해요체')
        for j, example in enumerate(candidate['examples']):
            text = example['en']
            low, high = profile['tokens']
            if not low <= len(tokens(text)) <= high:
                warnings.append(f'{label}.examples.{j}: expected {low}–{high} words')
            if lemmatizer.target_count(text, candidate['acceptedSpellings']) != 1:
                errors.append(f'{label}.examples.{j}: target must occur exactly once (inflections allowed)')
            outside = [w for w in tokens(text) if not lemmatizer.in_scope(w)]
            if outside:
                (errors if len(outside) > 1 else warnings).append(f'{label}.examples.{j}: out of scope: {", ".join(outside)}')
            pattern, message = profile['ko']
            if not re.search(pattern, example['ko']):
                warnings.append(f'{label}.examples.{j}: {message}')
            if re.search(r'\d|\b[A-Z]{2,}\b', text):
                flags.append('audio_numbers_or_abbreviations')
    if word.lower() in HOMOGRAPHS:
        flags.append('audio_homograph')
    record.update(data=data, status='auto_checked' if not errors else 'needs_fix', contentHash=digest(data),
                  autoValidation={'errors': errors, 'warnings': warnings, 'flags': sorted(set(flags))})
    return record


def validate_records(records, source_rows, profile=MIDDLE, lexicon_rows=None):
    lemmatizer = Lemmatizer(lexicon_rows or source_rows, forms_config(profile) if profile.get('forms') else None)
    checked = [validate_record(r, source_rows, lemmatizer, profile) for r in records]
    require(len({r['headword'] for r in checked}) == len(checked), 'Duplicate headwords in validation input')
    sentences, gram_index = [], defaultdict(list)
    for record in checked:
        if record['autoValidation']['errors']:
            continue
        seen = set()
        for candidate in record['data']['senseCandidates']:
            for example in candidate['examples']:
                sentence = ' '.join(tokens(example['en']))
                if sentence in seen:
                    continue
                seen.add(sentence)
                grams = {sentence[n:n+5] for n in range(max(1, len(sentence)-4))}
                candidates = Counter(index for gram in grams for index in gram_index[gram])
                for index, overlap in candidates.items():
                    previous, previous_sentence, previous_grams = sentences[index]
                    if previous['headword'] == record['headword']:
                        continue
                    if overlap < min(len(grams), len(previous_grams)) * .35:
                        continue
                    if abs(len(sentence) - len(previous_sentence)) > max(len(sentence), len(previous_sentence)) * .2:
                        continue
                    if SequenceMatcher(None, sentence, previous_sentence).ratio() >= .9:
                        for target, other in [(record, previous), (previous, record)]:
                            target['autoValidation']['errors'].append(f"Near-duplicate example with {other['headword']}")
                            target['status'] = 'needs_fix'
                for gram in grams:
                    gram_index[gram].append(len(sentences))
                sentences.append((record, sentence, grams))
    candidates = []
    for record in checked:
        if schema_validate(record.get('data'), 'generation'):
            continue
        for i, candidate in enumerate(record.get('data', {}).get('senseCandidates', [])):
            if 'meaningKo' in candidate:
                candidates.append({**candidate, 'id': f"{record['headword']}:{i}", 'headword': record['headword']})
    blocked = exclusions(candidates)
    for record in checked:
        record['distractorCandidateExclusions'] = {str(i): blocked.get(f"{record['headword']}:{i}", [])
                                                  for i in range(len(record.get('data', {}).get('senseCandidates', [])))}
    return checked


def run(input_path, output, source_path=SOURCE):
    inputs = read_jsonl(input_path)
    require(inputs, 'No drafts to validate')
    records = validate_records(inputs, sources(source_path))
    write_jsonl(output, records)
    return {'passed': sum(r['status'] == 'auto_checked' for r in records),
            'failed': sum(r['status'] == 'needs_fix' for r in records)}


def sense_hash(sense):
    return digest({k: v for k, v in sense.items() if k not in {
        'status', 'review', 'reviewHistory', 'contentHash', 'distractorExclusions'}})
