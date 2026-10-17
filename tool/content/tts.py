"""Approved text -> content-addressed audio -> ASR -> attributable listening review."""
import base64
import hashlib
import json
import os
import re
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from xml.sax.saxutils import escape, quoteattr

from .common import (CONTENT, canonical, digest, file_hash, now, read_json, read_jsonl,
                     require, safe_relative, schema_validate, write_jsonl)
from .review_io import read_csv, write_csv
from .validate import HOMOGRAPHS, sense_hash, tokens


def approved_senses(path):
    senses = read_jsonl(path)
    require(senses, 'No approved content')
    require(len({s['id'] for s in senses}) == len(senses), 'Duplicate approved sense IDs')
    for sense in senses:
        errors = schema_validate(sense, 'sense')
        require(not errors, '; '.join(errors))
        require(sense_hash(sense) == sense['contentHash'] == sense['review']['contentHash'],
                f"{sense['id']}: approval is stale")
    return senses


def plan(approved_path, output, config_path=CONTENT / 'config.json'):
    config = read_json(config_path)['tts']
    existing = {r['assetId']: r for r in read_jsonl(output)}
    assets = []
    for sense in approved_senses(approved_path):
        text_by_kind = {'word': ('en-US', sense['headword']),
                        'example': ('en-US', sense['examples'][sense['selectedExampleIndex']]['en'])}
        if config['includeKorean']:
            text_by_kind['meaning'] = ('ko-KR', sense['meaningKo'])
        for kind, (language, text) in text_by_kind.items():
            phoneme = config['phonemes'].get(sense['id']) if kind == 'word' else None
            settings = {'engine': config['engine'], 'provider': config['provider'],
                        'speakingRate': config['speakingRate'], 'pitch': config['pitch'],
                        'bitrate': config['bitrate'], 'lufs': config['lufs'], 'phoneme': phoneme,
                        'wordSilenceMs': 120 if kind == 'word' else 0, 'pipelineVersion': 1}
            voice = config['voices'][language]
            audio_hash = hashlib.sha1(canonical({'text': text, 'voice': voice, 'settings': settings}).encode()).hexdigest()
            asset_id = f"{sense['id']}:{kind}"
            relative = f"audio/{language[:2]}/{kind}/{audio_hash}.m4a"
            risks = []
            if sense['headword'].lower() in HOMOGRAPHS:
                risks.append('homograph')
            if re.search(r'\d|\b[A-Z]{2,}\b', text):
                risks.append('numbers_or_abbreviations')
            if int(digest(asset_id)[:8], 16) / 0xffffffff < config['listenSampleRate']:
                risks.append('random_sample')
            asset = {'assetId': asset_id, 'senseId': sense['id'], 'kind': kind, 'language': language,
                     'text': text, 'voice': voice, 'settings': settings, 'hash': audio_hash,
                     'path': relative, 'contentHash': sense['contentHash'], 'risks': risks, 'status': 'planned'}
            previous = existing.get(asset_id)
            if previous and previous['hash'] == audio_hash:
                asset = {**previous, **{k: v for k, v in asset.items() if k != 'status'}}
                # Reuse identical bytes and ASR even when another content field
                # changed. Semantic context changes invalidate listening approval.
                asset['risks'] = sorted(set(previous['risks'] + risks))
                if previous['contentHash'] != sense['contentHash']:
                    asset.pop('listeningReview', None)
                    if asset.get('asr'):
                        asset['status'] = 'awaiting_listening' if asset['risks'] else 'auto_verified'
            assets.append(asset)
    write_jsonl(output, assets)
    return {'assets': len(assets), 'characters': sum(len(a['text']) for a in assets),
            'missingPhonemes': [a['assetId'] for a in assets if 'homograph' in a['risks'] and a['kind'] == 'word' and not a['settings']['phoneme']]}


def ssml(asset):
    text = escape(asset['text'])
    if asset['settings']['phoneme']:
        text = f'<phoneme alphabet="ipa" ph={quoteattr(asset["settings"]["phoneme"])}>{text}</phoneme>'
    if asset['kind'] == 'word':
        text = f'<break time="120ms"/>{text}<break time="120ms"/>'
    return f'<speak>{text}</speak>'


def google_synthesize(asset):
    token = os.environ.get('GOOGLE_CLOUD_ACCESS_TOKEN')
    require(token, 'Set GOOGLE_CLOUD_ACCESS_TOKEN in the environment')
    request = urllib.request.Request('https://texttospeech.googleapis.com/v1/text:synthesize',
        data=canonical({'input': {'ssml': ssml(asset)},
                        'voice': {'languageCode': asset['language'], 'name': asset['voice']},
                        'audioConfig': {'audioEncoding': 'LINEAR16', 'speakingRate': asset['settings']['speakingRate'],
                                        'pitch': asset['settings']['pitch']}}).encode(),
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}, method='POST')
    with urllib.request.urlopen(request, timeout=90) as response:
        return base64.b64decode(json.load(response)['audioContent'], validate=True)


def run_command(command):
    return subprocess.run(command, check=True, capture_output=True, text=True)


def synthesize(manifest_path, audio_root, config_path=CONTENT / 'config.json',
               approved_path=CONTENT / 'approved/senses.jsonl'):
    config = read_json(config_path)['tts']
    approval = config.get('distributionApproval')
    require(approval and all(approval.get(k) for k in ['reviewer', 'reviewedAt', 'termsUrl'])
            and approval.get('allowed') is True, 'Record provider distribution-rights review in tts.distributionApproval first')
    require(config['provider'] == 'google', 'This adapter supports Google Cloud TTS; configure another adapter explicitly')
    current = {s['id']: s for s in approved_senses(approved_path)}
    assets = read_jsonl(manifest_path)
    require(assets, 'No audio plan')
    for asset in assets:
        sense = current.get(asset['senseId'])
        require(sense and sense['contentHash'] == asset['contentHash'], 'Approval changed/revoked; replan audio')
        expected = {'word': sense['headword'], 'example': sense['examples'][sense['selectedExampleIndex']]['en'],
                    'meaning': sense['meaningKo']}
        require(expected.get(asset['kind']) == asset['text'], 'Planned text differs from approved text')
        expected_hash = hashlib.sha1(canonical({'text': asset['text'], 'voice': asset['voice'], 'settings': asset['settings']}).encode()).hexdigest()
        require(asset['hash'] == expected_hash and Path(asset['path']).name == expected_hash + '.m4a', 'Audio plan hash changed')
    run_command(['ffmpeg', '-version'])
    run_command(['ffprobe', '-version'])
    for asset in assets:
        target = Path(audio_root) / safe_relative(asset['path'])
        if asset.get('fileSha256') and target.exists() and file_hash(target) == asset['fileSha256']:
            continue
        require(asset['settings']['provider'] == config['provider'], 'Replan after changing provider')
        require(not (asset['kind'] == 'word' and 'homograph' in asset['risks']) or asset['settings']['phoneme'],
                f"{asset['assetId']}: supply sense-specific IPA phoneme before synthesis")
        target.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=target.parent) as tmp:
            wav, m4a = Path(tmp) / 'raw.wav', Path(tmp) / 'normalized.m4a'
            wav.write_bytes(google_synthesize(asset))
            run_command(['ffmpeg', '-y', '-i', str(wav), '-af',
                         f"silenceremove=start_periods=1:start_duration=0.02:start_threshold=-50dB,areverse,"
                         f"silenceremove=start_periods=1:start_duration=0.02:start_threshold=-50dB,areverse,"
                         f"loudnorm=I={asset['settings']['lufs']}:TP=-1.5:LRA=11",
                         '-ac', '1', '-ar', '24000', '-c:a', 'aac', '-b:a', asset['settings']['bitrate'], str(m4a)])
            info = json.loads(run_command(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(m4a)]).stdout)
            duration = float(info['format']['duration'])
            stream = info['streams'][0]
            require(stream['codec_name'] == 'aac' and stream['channels'] == 1 and duration > 0, 'Invalid encoded audio')
            audio_check = run_command(['ffmpeg', '-i', str(m4a), '-af', 'silencedetect=noise=-45dB:d=0.25', '-f', 'null', '-']).stderr
            silence = sum(float(x) for x in re.findall(r'silence_duration: ([0-9.]+)', audio_check))
            if duration < .15 or duration > max(3, len(asset['text']) * .25):
                asset['risks'] = sorted(set(asset['risks'] + ['duration_outlier']))
            if silence > duration * .35:
                asset['risks'] = sorted(set(asset['risks'] + ['excess_silence']))
            os.replace(m4a, target)
        asset.update(fileSha256=file_hash(target), bytes=target.stat().st_size, durationSeconds=duration,
                     silenceSeconds=silence, synthesizedAt=now(), status='synthesized', distributionApproval=approval)
        asset.pop('asr', None)
        asset.pop('listeningReview', None)
        write_jsonl(manifest_path, assets)
    return {'synthesized': sum('fileSha256' in a for a in assets)}


def word_error_rate(reference, hypothesis):
    # Korean audio must also be compared; English tokenizer would drop Hangul.
    normalize = lambda text: re.findall(r"[a-z0-9가-힣]+", text.lower())
    a, b = normalize(reference), normalize(hypothesis)
    row = list(range(len(b) + 1))
    for i, left in enumerate(a, 1):
        next_row = [i]
        for j, right in enumerate(b, 1):
            next_row.append(min(row[j] + 1, next_row[-1] + 1, row[j-1] + (left != right)))
        row = next_row
    return row[-1] / max(1, len(a))


def asr(manifest_path, audio_root, model_name='small'):
    from faster_whisper import WhisperModel
    model = WhisperModel(model_name, device='cpu', compute_type='int8')
    assets = read_jsonl(manifest_path)
    for asset in assets:
        target = Path(audio_root) / safe_relative(asset['path'])
        require(target.exists() and file_hash(target) == asset.get('fileSha256'), 'Missing/changed audio; synthesize first')
        if asset.get('asr', {}).get('fileSha256') == asset['fileSha256'] and asset['asr'].get('model') == model_name:
            continue
        segments, _ = model.transcribe(str(target), language=asset['language'][:2], beam_size=5)
        transcript = ' '.join(s.text.strip() for s in segments)
        wer = word_error_rate(asset['text'], transcript)
        asset['asr'] = {'model': model_name, 'engine': 'faster-whisper', 'transcript': transcript,
                        'wordErrorRate': wer, 'fileSha256': asset['fileSha256'], 'checkedAt': now()}
        asset['risks'] = [r for r in asset['risks'] if r != 'asr_mismatch']
        if wer > 0:
            asset['risks'].append('asr_mismatch')
        asset.pop('listeningReview', None)
        asset['status'] = 'awaiting_listening' if asset['risks'] else 'auto_verified'
        write_jsonl(manifest_path, assets)
    return {'listeningRequired': sum(bool(a['risks']) for a in assets)}


def export_listening(manifest_path, output):
    assets = read_jsonl(manifest_path)
    require(assets and all('asr' in a for a in assets), 'Run ASR on all audio first')
    rows = [{'assetId': a['assetId'], 'fileSha256': a['fileSha256'], 'path': a['path'], 'text': a['text'],
             'risks': '|'.join(a['risks']), 'transcript': a['asr']['transcript'], 'reviewer': '', 'decision': '', 'note': ''}
            for a in assets if a['risks']]
    fields = ['assetId', 'fileSha256', 'path', 'text', 'risks', 'transcript', 'reviewer', 'decision', 'note']
    write_csv(output, rows, fields)
    return {'listeningRequired': len(rows)}


def import_listening(manifest_path, csv_path):
    assets = read_jsonl(manifest_path)
    by_id = {a['assetId']: a for a in assets}
    seen = set()
    for row in read_csv(csv_path):
        require(row['assetId'] in by_id and row['assetId'] not in seen, 'Unknown/duplicate audio ID')
        seen.add(row['assetId'])
        asset = by_id[row['assetId']]
        require(asset.get('asr') and row['fileSha256'] == asset['fileSha256'], 'Stale/unverified audio')
        require(row['reviewer'].strip() and row['decision'] in {'approved', 'rejected'}, 'Listening decision and reviewer required')
        asset['listeningReview'] = {'reviewer': row['reviewer'].strip(), 'reviewedAt': now(), 'decision': row['decision'],
                                    'note': row['note'], 'fileSha256': asset['fileSha256']}
        asset['status'] = 'human_verified' if row['decision'] == 'approved' else 'rejected'
    write_jsonl(manifest_path, assets)
    return {'reviewed': len(seen)}


def require_publishable(asset, sense, audio_root):
    require(asset['contentHash'] == sense['contentHash'], 'Audio belongs to an older content revision')
    target = Path(audio_root) / safe_relative(asset['path'])
    require(target.is_file() and file_hash(target) == asset.get('fileSha256'), 'Audio file missing/changed')
    asr_result = asset.get('asr', {})
    require(asr_result.get('fileSha256') == asset['fileSha256'] and asr_result.get('model')
            and isinstance(asr_result.get('wordErrorRate'), (int, float)), 'ASR check missing/stale')
    require(asset['status'] in {'auto_verified', 'human_verified'}, 'Audio not approved')
    if asset['risks'] or asr_result['wordErrorRate'] > 0 or sense['headword'].lower() in HOMOGRAPHS or re.search(r'\d|\b[A-Z]{2,}\b', asset['text']):
        review = asset.get('listeningReview', {})
        require(review.get('decision') == 'approved' and review.get('reviewer')
                and review.get('fileSha256') == asset['fileSha256'], 'Required listening review missing/stale')
    require(asset.get('distributionApproval', {}).get('allowed') is True, 'Audio distribution rights not reviewed')
