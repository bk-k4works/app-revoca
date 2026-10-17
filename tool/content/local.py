"""Import content authored and reviewed in Codex, without pretending an API ran."""
from pathlib import Path
from html import escape

from .common import (CONTENT, SOURCE, digest, file_hash, now, read_json, read_jsonl,
                     require, schema_validate, sources, write_jsonl, atomic_write)
from .validate import validate_records


def import_drafts(input_path, output, source_path=SOURCE):
    require(Path(input_path).resolve() != Path(output).resolve(), 'Keep the authored source file')
    data = read_jsonl(input_path)
    rows = sources(source_path)
    require(data and len({r['headword'] for r in data}) == len(data), 'Empty or duplicate draft headwords')
    authored_hash = file_hash(input_path)
    schema_hash = digest(read_json(CONTENT / 'schema/generation.schema.json'))
    source_hash = digest(rows)
    records = []
    for entry in data:
        errors = schema_validate(entry, 'generation')
        require(not errors, f"{entry['headword']}: {'; '.join(errors)}")
        require(entry['headword'] in rows, 'Draft headword absent from curriculum source')
        records.append({'headword': entry['headword'], 'data': entry, 'status': 'draft',
                        'source': rows[entry['headword']], 'generation': {
                            'model': 'codex-session', 'method': 'codex-local-authoring',
                            'promptVersion': 'codex_pilot_v1', 'generatedAt': now(),
                            'authoredFileSha256': authored_hash,
                            'schemaHash': schema_hash,
                            'sourceHash': source_hash, 'externalApiUsed': False,
                        }})
    write_jsonl(output, records)
    return {'imported': len(records), 'method': 'codex-local-authoring'}


def import_reviews(input_path, reviews_path, output, source_path=SOURCE):
    require(Path(output).resolve() not in {Path(input_path).resolve(), Path(reviews_path).resolve()},
            'Keep the checked input and authored review files')
    originals = read_jsonl(input_path)
    require(originals and all(r.get('status') == 'auto_checked' for r in originals),
            'Local review requires S3-checked drafts')
    checked = validate_records(originals, sources(source_path))
    require(all(r['status'] == 'auto_checked' and r['contentHash'] == old.get('contentHash')
                for r, old in zip(checked, originals)), 'Automatic checks failed or input changed')
    reviews = read_jsonl(reviews_path)
    by_word = {r['headword']: r for r in reviews}
    require(len(by_word) == len(reviews) and set(by_word) == {r['headword'] for r in checked},
            'Supply exactly one local review for every input headword')
    review_hash = file_hash(reviews_path)
    for record in checked:
        local = by_word[record['headword']]
        require(local['inputHash'] == record['contentHash'], 'Local review is stale')
        review = local['review']
        errors = schema_validate(review, 'review')
        require(not errors, '; '.join(errors))
        require(review['headword'] == record['headword'], 'Review headword mismatch')
        refs = local.get('references', [])
        require(isinstance(refs, list) and all(isinstance(v, str) and v.startswith('https://') for v in refs),
                'Review references must be HTTPS URLs')
        ratings = [c['rating'] for c in review['criteria'].values()]
        severity = 'fail' if 'fail' in ratings or review['criticalError'] else 'warn' if 'warn' in ratings else 'pass'
        record.update(status='llm_reviewed', llmReview={**review, 'severity': severity,
            'inputHash': record['contentHash'], 'provenance': {
                'model': 'codex-session', 'method': 'codex-local-review', 'reviewedAt': now(),
                'independentModel': False, 'externalApiUsed': False,
                'reviewFileSha256': review_hash, 'references': refs,
            }})
    write_jsonl(output, checked)
    return {'reviewed': len(checked), 'method': 'codex-local-review',
            'humanApproved': 0, 'independentModel': False}


def preview(input_path, output):
    records = read_jsonl(input_path)
    require(records and all(r.get('status') == 'llm_reviewed' for r in records), 'Preview requires reviewed records')
    cards = []
    for record in records:
        data = record['data']
        require(record['contentHash'] == digest(data) == record['llmReview']['inputHash'], 'Stale preview input')
        flags = data['flags']
        attention = any(f != 'single_sense_candidate' for f in flags)
        candidates = []
        for index, sense in enumerate(data['senseCandidates']):
            examples = ''.join(f'<li><p lang="en">{escape(e["en"])}</p><p class="translation">{escape(e["ko"])}</p></li>'
                               for e in sense['examples'])
            candidates.append(f'''<details {'open' if sense['isPrimaryProposal'] else ''}>
<summary>{'대표 제안' if sense['isPrimaryProposal'] else '추가 후보'} · {index} · {escape(sense['pos'])} · {escape(sense['meaningKo'])}</summary>
<p>{escape(sense['explanationKo'])}</p><p class="expression">{escape(sense['collocation'])} <span>{escape(sense['collocationKo'])}</span></p>
<ol>{examples}</ol><p class="meta">허용 철자: {escape(', '.join(sense['acceptedSpellings']))}</p></details>''')
        note = record['llmReview']['criteria']['semanticAlignment']['reason']
        refs = record['llmReview'].get('provenance', {}).get('references', [])
        references = ' · '.join(f'<a href="{escape(url, quote=True)}" target="_blank" rel="noopener">참고 {i + 1}</a>'
                                 for i, url in enumerate(refs))
        flag_list = ''.join(f'<li>{escape(f)}</li>' for f in flags)
        search = ' '.join([record['headword'], *[s['meaningKo'] for s in data['senseCandidates']]])
        cards.append(f'''<article data-search="{escape(search, quote=True)}" data-attention="{str(attention).lower()}" data-single="{str(len(data['senseCandidates']) == 1).lower()}">
<header><h2>{escape(record['headword'])}</h2><span class="badge">{'추가 확인' if attention else '초안 검토 완료'}</span></header>
<p class="meta">원천 {record['source']['source_page']}쪽 · {escape(record['source']['original'])} · 사람 승인 전</p>
{''.join(candidates)}<aside><strong>Codex 검토 메모</strong><p>{escape(note)}</p>{references}
{'<details><summary>주의 사항</summary><ul>' + flag_list + '</ul></details>' if flags else ''}</aside></article>''')
    count = len(records)
    senses = sum(len(r['data']['senseCandidates']) for r in records)
    page = f'''<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>기본 어휘 {count}개 · Codex 파일럿 검토</title>
<style>
*{{box-sizing:border-box}}body{{margin:0;background:#f5f6f2;color:#20251f;font:16px/1.65 system-ui,-apple-system,sans-serif}}
main{{max-width:980px;margin:auto;padding:36px 20px 80px}}h1{{font-size:30px;line-height:1.3}}h2{{margin:0;font-size:25px}}.intro{{color:#4e584c}}
.stats{{display:flex;gap:12px;flex-wrap:wrap;margin:24px 0}}.stats b{{background:#e4efc8;border-radius:12px;padding:12px 18px}}
.controls{{position:sticky;top:0;background:#f5f6f2f5;display:flex;gap:10px;padding:16px 0;z-index:1;flex-wrap:wrap}}
input,select{{font:inherit;border:1px solid #bac3b3;border-radius:8px;padding:10px;background:white}}input{{flex:1;min-width:180px}}
article{{background:white;border:1px solid #dce1d6;border-radius:16px;padding:24px;margin:16px 0}}article header{{display:flex;justify-content:space-between;align-items:center;gap:12px}}
.badge{{font-size:12px;background:#edf1e5;border-radius:20px;padding:5px 10px;white-space:nowrap}}.meta{{color:#64705e;font-size:13px}}
details{{border-top:1px solid #e7ebe2;padding:14px 0 3px}}summary{{cursor:pointer;font-weight:650}}details p{{margin:10px 0}}
ol{{padding-left:22px}}ol li{{padding:4px 0}}ol p{{margin:3px 0!important}}.translation{{color:#53614a}}.expression{{font-weight:650}}.expression span{{font-weight:400;margin-left:12px}}
aside{{background:#f4f7ef;padding:15px;border-radius:10px;margin-top:16px;font-size:14px}}aside p{{margin:6px 0}}a{{color:#355e25}}[hidden]{{display:none!important}}
@media(max-width:540px){{main{{padding:20px 12px 50px}}article{{padding:18px}}h1{{font-size:25px}}.expression span{{display:block;margin-left:0}}}}
</style><main><p class="meta">FOCUS VOCA · CONTENT PILOT · 2026-10-16</p><h1>기본 어휘 {count}개 검토</h1>
<p class="intro">Codex에서 작성하고 자동 검사·내용 검토를 마친 초안입니다. 최종 승인 전이며, 같은 Codex 대화의 검토를 별도 독립 모델의 검수로 표시하지 않았습니다.</p>
<div class="stats"><b>{count}개 표제어</b><b>{senses}개 의미 후보</b><b>{senses * 2}개 예문</b><b>자동 검사 {count}개 통과</b></div>
<p>이 화면은 읽기 전용입니다. 승인·수정은 <a href="codex.review.csv">검수 CSV</a>에서 작성합니다. <a href="../../sources/curriculum_2022_basic.pdf">원천 PDF</a>도 함께 확인할 수 있습니다.</p>
<p class="meta">선택지 검토 결과는 각 원고의 검토 기록과 별도 앱 선택지 보고서에 기록합니다. 단일 후보의 의미 범위, 직접 평가 항목과 편집 주의 사항은 최종 검수에서 확인해 주세요.</p>
<div class="controls"><input id="search" type="search" aria-label="단어 또는 뜻 검색" placeholder="단어 또는 뜻 검색"><select id="filter" aria-label="검토 범위"><option value="all">전체</option><option value="attention">추가 확인 사항 있음</option><option value="single">의미 후보 1개</option></select></div>
<p id="count" aria-live="polite">{count}개 표시</p>{''.join(cards)}</main>
<script>
const rows=Array.from(document.querySelectorAll('article'));
function filterRows(){{const term=document.querySelector('#search').value.trim().toLowerCase();const mode=document.querySelector('#filter').value;let n=0;
for(const row of rows){{row.hidden=!(row.dataset.search.toLowerCase().includes(term)&&(mode==='all'||row.dataset[mode]==='true'));if(!row.hidden)n++;}}
document.querySelector('#count').textContent=n+'개 표시';}}
document.querySelector('#search').addEventListener('input',filterRows);document.querySelector('#filter').addEventListener('change',filterRows);
</script></html>'''
    atomic_write(output, page)
    return {'preview': str(output), 'headwords': count, 'senseCandidates': senses}
