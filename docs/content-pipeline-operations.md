# 기본 어휘 파이프라인 실행 안내

구현 기준: 2026-10-16. 설계는 [content-pipeline.md](content-pipeline.md), 진입점은 `python -m tool.content`다. 저장소 루트에서 실행한다. 모든 JSON/JSONL은 UTF-8, 검수 CSV는 Excel에서 한글을 읽을 수 있도록 UTF-8 BOM을 쓴다. **현재 기본 작업 방식은 API 키 없이 Codex 내부에서 작성·검토하는 방식**이다. 외부 배치 API는 선택 가능한 기존 경로로 남긴다.

## 구현 상태와 실제 콘텐츠 상태

| 항목 | 현재 상태 |
| --- | --- |
| S0 원천 | 지정된 교육청 게시 PDF 보존, CSV 3,000행 추출, 초등 `*` 800개·공통 `**` 1,200개 검사 통과 |
| 원문 대조 | 두 사람의 대조 기록 없음. `awaiting_two_human_checks` |
| S1 의미 ID | 변경 불가 레지스트리, 추가 ID 발급·폐기 매핑, 기존 30개 마이그레이션 표 |
| S2–S4 | Opus 5.5 배치 요청 준비·전송·상태·수집·재시도, 구조화 출력, 캐시, 자동 검사, 독립 검수 프롬프트 |
| 문체 참고 | 기존 30개 + 새 초안 20개 = 50개. **전문가가 승인한 골드셋이 아님**. 승인 원고는 `gold-promote`로 별도 승격 |
| S5 | CSV 선택·편집·승인·반려, S3 재검사, 10% 독립 재검수, 일치율·무수정 승인율 |
| S6 | Google REST 어댑터, SSML, 해시 캐시, ffmpeg 정규화/AAC, faster-whisper ASR, 청취 CSV |
| S7 | 승인 검증, 20개 단어장 편성, SQLite, 첫 단어장 번들 음성, 단어장별 ZIP, 체크섬·버전 |
| 앱 | 표제어/의미 분리, 진도 이전, 콘텐츠 DB 부분 읽기, 안전한 오답 선택지, 음성 팩 설치·다운로드·기기 TTS 대체 |
| 실제 배포 원고·음성 | 아직 없음. 유료 API 호출·TTS 합성·사람 검수·팩 업로드는 수행하지 않음 |
| 제공 PDF 원천 | 본문 2,300개·예문 3,642쌍·표현 300개·관련어 153개·어원 카드 6개. 단원·쪽수와 697쪽 전체 보존, 학년 분류·전수 편집 검사·배포 이용 확인 전 |
| Codex 내부 파일럿 | 표제어 100개·의미 후보 154개·예문 308개 작성, S3 전부 통과, Codex 내용 검토 및 사람 검수 CSV 준비. 사람 승인 0개 |

현재 `assets/content/content.sqlite`는 Codex 파일럿 **100개 표제어·154개 의미·308개 예문·9개 단어장**을 담은 개발 전용 데이터다. 앱은 release 모드에서 개발 전용 카탈로그를 거부한다. 출시 원고를 승인하고 아래 `build` → `install`을 실행해야 출시 데이터로 바뀐다.

2026-10-16 [학년·레벨 점검](content-grade-level-plan.md)에서 기존 300개 출시 계획을 대체했다. 전체 3,000개를 제작 대상으로 검토하되 중학 준비·중1·중2·중3·고교 연결의 의미 범위를 근거에 따라 편성한다. 현재 파일럿은 학년별 표본이 아니며, 학년·레벨 메타데이터와 정식 다의어 패키징은 아직 미구현이다. 아래 기존 빌드가 성공하더라도 이 새 편성 기준을 충족했다는 뜻은 아니다.

## 제공 PDF 가져오기: 현재 우선 작업

사용자 요청에 따라 단어 데이터를 먼저 확보하고 학년·난이도는 전수검사 중 별도 정리한다. [PDF 확보 결과와 Day·Part 활용안](pdf-content-import.md)에 범위·산출물·검사 결과를 기록했다. 중학 PDF는 1,200개 전체가 아닌 Day 1–15의 300개다.

```sh
.venv-content/bin/python -m tool.content.pdf_books \
  --high content/sources/user-provided/sarang-csat-2000.pdf \
  --middle content/sources/user-provided/ebs-middle-excerpt.pdf \
  --output content/imports/pdf-books-v1 \
  --cache content/imports/.layout-cache
```

결과는 원천 데이터이며 기존 `local-draft-import`나 `install`에 바로 넣는 승인 스키마가 아니다. 본문 전수검사·의미 분리 후 기존 sense ID와 연결해야 한다. 재추출은 파생 파일을 덮어쓰므로 편집·학년 검토 결과는 별도 원장에 저장한다. API 키나 외부 모델 호출은 필요하지 않다.

## 원문에서 확인한 설계 보완

- 링크된 PDF는 영어과 교육과정 전체가 아니라 KICE Word Lister 안내 자료다. 원문 고시 pp.254–290을 인용하며, 해당 PDF의 실제 7–36쪽에 **3단** 목록이 있다. CSV `source_page`는 이 PDF의 물리적 쪽수(1부터 시작)다.
- `/`로 나뉜 철자는 `variants`, 괄호 속 단어군은 `related_forms`로 분리한다. 예: `color / colour`는 철자 변형, `able (disabled)`는 파생 관계다. 파생어를 철자 정답으로 자동 추가하지 않는다.
- 기존 MVP의 `review`, `identify`, `environment`, `opportunity`는 각각 `view`, `identity`, `environ`, `opportune`의 괄호 안 단어군에 있다. 새 대표 표제어의 뜻으로 임의 연결하지 않는다. 기존 sense ID와 기록은 유지하며, 출시 원고의 대표 의미 선정 때 별도 검토한다.
- 출시 버전에서 잠시 빠진 기존 의미의 진도·답안·시험 범위는 사용자 DB에 남는다. 해당 의미가 포함된 진행 중 세션은 `suspended_session:*`으로 보존하고, 후속 콘텐츠가 준비되었을 때 복구한다. 의미가 다른 카드에 진도를 합치지 않는다.

## 설치

Python 3.11 이상과 Flutter가 필요하다.

```sh
python3 -m venv .venv-content
.venv-content/bin/python -m pip install -r tool/content/requirements.txt
.venv-content/bin/python -m tool.content --help
flutter pub get
```

현재 작업 환경은 Codex에 번들된 Python 3.12를 이용해 `.venv-content`를 만들었다. 다른 환경에서는 위 명령으로 재생성한다. 음성 작업에는 별도로 `ffmpeg`, `ffprobe`와 아래 패키지가 필요하다.

```sh
.venv-content/bin/python -m pip install -r tool/content/requirements-audio.txt
```

API 인증은 환경 변수만 사용한다. Anthropic은 `ANTHROPIC_API_KEY`, Google TTS는 `GOOGLE_CLOUD_ACCESS_TOKEN`이다. 키를 JSON·CSV·프롬프트에 넣지 않는다. 코드·테스트 실행에는 키가 필요하지 않다.

## S0–S1: 원천과 의미 ID

```sh
.venv-content/bin/python -m tool.content ingest
```

원문 PDF·CSV·manifest를 함께 보존한다. 재추출 결과가 같으면 기존 대조 기록을 유지하고 달라지면 무효화한다. CSV를 사람이 수정한 경우 첫 `source-check`가 수량을 다시 검사하고 이전 검수 기록을 이력으로 옮긴다. 두 사람이 실제 대조를 마친 뒤 각자 기록한다.

```sh
.venv-content/bin/python -m tool.content source-check --reviewer EDITOR_A --note '전체 목록·표시·변형·쪽수 대조 완료'
.venv-content/bin/python -m tool.content source-check --reviewer EDITOR_B --note '독립 대조 완료'
```

위 검수자 값은 예시다. 실제 수행자만 기록한다. 같은 이름의 두 번 승인은 인정되지 않는다.

```sh
.venv-content/bin/python -m tool.content sense-issue --headword bank --pos n --slug money
.venv-content/bin/python -m tool.content sense-issue --headword bank --pos n --slug river --additional
```

처음 발급한 ID는 내용 수정·재생성 시 유지한다. 새 의미는 새 ID로 발급한다. 실제 후속 의미로 대체하는 경우에만 `sense-retire --old ... --successor ...`를 사용한다. 폐기 ID 재사용·자기 참조·순환 매핑을 금지한다. 1차 빌드는 표제어별 대표 의미 하나만 허용한다.

## S2–S4: 100개 파일럿과 배치 처리

### 현재 경로: API 없이 Codex 내부 작성·검토

사용자의 2026-10-16 지시에 따라 외부 API 인증 없이 Codex에서 원천 목록·코드·필요한 사전 사실을 확인하며 작성하고 검토했다. `local-draft-import`와 `local-review-import`는 로컬 파일만 처리한다. 같은 대화에서 작성·검토했으므로 `independentModel: false`와 `externalApiUsed: false`를 기록하며, 특정 Claude 모델이나 사람의 승인 이력으로 바꾸지 않는다.

결과는 `content/pilots/pilot-v1/`에 있다.

- `codex-authored.txt`, `codex.authored.jsonl`: 독자 작성한 100개 초안. 의미 후보 154개와 영어·한국어 예문 308쌍이다.
- `codex.checked.jsonl`: 자동 검사 100개 통과. 어휘 범위·문장 길이·해요체 경고는 없으며, 의미 후보 1개인 46개에는 범위 확인 경고를 남겼다.
- `codex-review-notes.txt`, `codex.reviews.jsonl`: 표제어별 검토 메모와 6개 기준의 판단. 검토는 정확한 `inputHash`에 연결되며 원고가 바뀌면 이전 검토를 가져올 수 없다.
- `codex.reviewed.jsonl`: 내용 검토를 합친 원고. 2차 검토에서 앱의 154개 문제를 대조했다. 객관식 후보는 현재 선택지의 유일성을 검토했으며 직접 평가 항목은 객관식 승인 대상이 아니다. 이는 API 또는 사람 검수가 완료됐다는 뜻이 아니다.
- `codex.review.csv`: 사람이 후보 선택·수정·승인·반려를 기록할 100행 표. 검수자와 결정 칸은 비어 있다.
- `review.html`: 검색·추가 확인 항목·단일 후보 필터가 있는 읽기 전용 검토 화면.
- `history/first-pass/`: 첫 자동 검사 결과와 수정 전 원고를 보존했다.

같은 작성 원고를 다시 변환·검사하는 명령은 다음과 같다. 원고를 수정했다면 내용 검토도 다시 수행하고 새로운 해시에 대한 `codex.reviews.jsonl`을 작성해야 한다. 기존 메모의 해시만 자동 교체하지 않는다.

```sh
PYTHONPATH=. .venv-content/bin/python content/pilots/pilot-v1/build_codex_drafts.py
.venv-content/bin/python -m tool.content local-draft-import --input content/pilots/pilot-v1/codex.authored.jsonl --output content/pilots/pilot-v1/codex.drafts.jsonl
.venv-content/bin/python -m tool.content validate --input content/pilots/pilot-v1/codex.drafts.jsonl --output content/pilots/pilot-v1/codex.checked.jsonl
.venv-content/bin/python -m tool.content local-review-import --input content/pilots/pilot-v1/codex.checked.jsonl --reviews content/pilots/pilot-v1/codex.reviews.jsonl --output content/pilots/pilot-v1/codex.reviewed.jsonl
.venv-content/bin/python -m tool.content review-export --input content/pilots/pilot-v1/codex.reviewed.jsonl --output content/pilots/pilot-v1/codex.review.csv
.venv-content/bin/python -m tool.content local-review-preview --input content/pilots/pilot-v1/codex.reviewed.jsonl --output content/pilots/pilot-v1/review.html
```

`review-export`는 빈 검수표를 다시 만들므로 사람이 이미 작성한 CSV에는 새 출력 경로를 지정한다. 실제 검수표 작성 후 기존 S5 가져오기를 사용한다.

```sh
.venv-content/bin/python -m tool.content review-import --input content/pilots/pilot-v1/codex.reviewed.jsonl --csv content/pilots/pilot-v1/codex.review.csv --output content/pilots/pilot-v1/codex.human.jsonl
```

파일럿 실행에서 다음 검증 문제도 수정했다.

- 한 의미밖에 제안하지 못한 단어를 억지로 2개로 나누지 않는다. 스키마는 1~3개를 받되 단일 후보에 `single_sense_candidate`를 의무화하고 경고를 남긴다. API 생성 프롬프트도 `generate_v2`로 버전을 올렸다.
- 원천 variants를 모든 의미에 자동 합치지 않는다. 의미·품사별로 작성한 철자 부분집합을 보존하고 원천에 없는 철자는 거절한다. `check/cheque`, `practice/practise`, `upward/upwards`의 차이를 검토했다.
- `these/more/less/blew/wound` 같은 굴절형과 `freedom/scientist/solution` 같은 불규칙 파생형을 명시적으로 보완했다. 파생형은 어휘 범위 검사에만 허용하며 표제어 출현 횟수에는 포함하지 않는다.

### 준비된 파일럿 v1 (2026-10-16)

`content/pilots/pilot-v1/`에 아래 자료도 보존했다. 이 외부 API 비교 요청은 **미전송**이며 현재 Codex 내부 작업에는 사용하지 않는다. `preparation.json`은 전환 이전의 준비 상태를 기록한 파일이다.

- `sample.json`: 고정 표본 100개, 선정 이유, 원천 해시. 원천 비율을 반올림해 초등 표시 27개·공통과목 표시 40개·나머지 33개를 뽑았다. 다의어·동형이의어·기능어·철자 변형·기존 의미 ID 검토 사례를 포함하고 원문 7–36쪽 전체를 포괄한다. 빈도 순위나 출시 학습 순서를 뜻하지 않는다.
- `generate.medium.requests.jsonl`, `generate.high.requests.jsonl`: **같은 100개**의 effort 비교용 요청. 각 100건이며 총 200건이 준비되어 있다. 각 요청의 `.manifest.json`에 입력·프롬프트 해시와 전송 상태를 보존한다. 먼저 medium을 실행하고 high는 별도 비교 실행으로 취급한다.
- `source-comparison-a.csv`, `source-comparison-b.csv`: 각 3,000행의 독립 원문 대조용 보조표. PDF의 물리적 쪽수·원문 표기·철자 변형·단어군·표시와 현재 CSV 해시를 담고, 검수자·판정·메모는 비워 두었다. 이 표를 채우는 것만으로 승인이 등록되지는 않는다. 실제 대조가 끝나면 S0의 `source-check`로 기록한다.
- `preparation.json`: 준비 시점의 상태와 다음 작업. 이후 실제 전송 상태는 각 요청의 manifest와 `batch-status`로 확인한다.

새 표본 패키지가 필요할 때는 아래 명령을 쓴다. 기존 디렉터리는 덮어쓰지 않으므로 새 경로를 지정해야 한다. 이 명령 자체는 API를 호출하지 않는다.

```sh
.venv-content/bin/python -m tool.content pilot-prepare --output content/pilots/pilot-v2
```

로컬 실행 환경에 `ANTHROPIC_API_KEY`를 설정한 뒤 준비된 medium 요청을 다음 순서로 실행한다. 키를 저장소나 검수표에 넣지 않는다. 배치가 `ended`가 되기 전에는 수집하지 않는다.

```sh
.venv-content/bin/python -m tool.content batch-submit content/pilots/pilot-v1/generate.medium.requests.jsonl
.venv-content/bin/python -m tool.content batch-status content/pilots/pilot-v1/generate.medium.requests.jsonl
.venv-content/bin/python -m tool.content batch-collect content/pilots/pilot-v1/generate.medium.requests.jsonl --output content/pilots/pilot-v1/medium.jsonl
.venv-content/bin/python -m tool.content validate --input content/pilots/pilot-v1/medium.jsonl --output content/pilots/pilot-v1/medium.checked.jsonl
.venv-content/bin/python -m tool.content review --input content/pilots/pilot-v1/medium.checked.jsonl --output content/pilots/pilot-v1/review.medium.requests.jsonl
.venv-content/bin/python -m tool.content batch-submit content/pilots/pilot-v1/review.medium.requests.jsonl
.venv-content/bin/python -m tool.content batch-status content/pilots/pilot-v1/review.medium.requests.jsonl
.venv-content/bin/python -m tool.content batch-collect content/pilots/pilot-v1/review.medium.requests.jsonl --output content/pilots/pilot-v1/medium.reviewed.jsonl
.venv-content/bin/python -m tool.content review-export --input content/pilots/pilot-v1/medium.reviewed.jsonl --output content/pilots/pilot-v1/medium.review.csv
```

생성 실패나 자동 검사 실패 항목은 재시도·수정 후 같은 100개 표본에 합친다. 통과한 항목만으로 분모를 줄여 승인율을 계산하지 않는다. 최종 100개에 대한 실제 사람 검수를 마친 뒤 무수정 승인율 80%를 판단한다. high 비교 결과는 별도 파일로 보존하고, 두 실험 결과를 하나의 승인 파일에 섞지 않는다.

### 일반 배치 명령

`content/config.json`의 기본값은 `claude-opus-5-5`, adaptive thinking, medium, 영어 음성이다. 남아 있는 `releaseSize: 300`은 현재 코드에서 사용하지 않는 기존 계획 값이며 출시 범위를 뜻하지 않는다. 모델·스키마·프롬프트·출처·요청 본문이 해시 입력에 포함된다. 기본 목록 전체는 고정 시스템 접두사에 넣어 캐시하고, 단어별 정보는 마지막 user 메시지에 넣는다. 따라서 실제 토큰 수는 설계 문서의 4K 가정과 다를 수 있으며 수집된 usage로 비용을 계산해야 한다.

```sh
.venv-content/bin/python -m tool.content generate --limit 100 --output content/drafts/pilot.requests.jsonl
.venv-content/bin/python -m tool.content batch-submit content/drafts/pilot.requests.jsonl
.venv-content/bin/python -m tool.content batch-status content/drafts/pilot.requests.jsonl
.venv-content/bin/python -m tool.content batch-collect content/drafts/pilot.requests.jsonl --output content/drafts/pilot.jsonl
.venv-content/bin/python -m tool.content validate --input content/drafts/pilot.jsonl --output content/drafts/pilot.checked.jsonl
.venv-content/bin/python -m tool.content review --input content/drafts/pilot.checked.jsonl --output content/review/pilot.requests.jsonl
.venv-content/bin/python -m tool.content batch-submit content/review/pilot.requests.jsonl
.venv-content/bin/python -m tool.content batch-collect content/review/pilot.requests.jsonl --output content/review/llm_pilot.jsonl
```

- `generate`/`review`는 파일만 만든다. `batch-submit`이 실제 과금 요청이다. 완료 전 `batch-collect`는 중단되므로 나중에 재실행한다.
- `--effort high`로 비교 실험, `--only achieve prepare ...`로 동일 표본을 지정한다. 요청은 1–500개로 제한한다.
- 정상 결과는 배열 순서 대신 `custom_id`로 대조한다. 일반 표제어는 그대로 사용하고 API 문자 제한에 걸리는 표제어는 해시 ID와 manifest 매핑을 쓴다.
- 원본 응답, 모델·프롬프트·usage, `.summary.json`, `.failures.jsonl`, `.retry.jsonl`과 재시도 manifest를 남긴다. refusal, 출력 잘림, API 오류, 누락 결과는 승인 데이터로 들어가지 않는다.
- 전송 성공 여부를 알 수 없는 연결 오류 후에는 같은 유료 요청을 자동 재전송하지 않는다. 공급자 콘솔에서 배치 ID를 확인한 뒤 `batch-submit ... --adopt-batch-id msgbatch_...`로 연결한다.
- `--cache-dir content/drafts`는 같은 요청의 성공 결과를 건너뛴다. 내용 수정이 필요한 항목은 `generate --input ...checked.jsonl --output ...correction.requests.jsonl`로 이전 초안과 실패 사유를 포함해 재생성한다. 사람의 `needs_fix` 결과도 같은 방식이다.
- 자동 검사 실패가 있으면 `validate`는 결과 파일을 쓰고 종료 코드 1을 반환한다. S4는 그 파일의 `auto_checked` 항목만 받는다.
- 외부에서 받은 API 결과는 `batch-collect ... --results saved_results.jsonl`로 같은 검증을 거쳐 가져올 수 있다.

자동 형태 분석은 버전 관리된 불규칙형·축약형 사전과 기본 목록에 제한된 굴절·파생 규칙이다. 문맥 품사 분석기를 대신하지 않는다. 알려지지 않은 형태는 밖의 어휘로 기록하며, 토큰 1개면 경고, 2개 이상이면 실패한다. 표제어 출현 횟수에는 파생형을 허용하지 않고 굴절형만 허용한다. 한국어 유의어·혼동어 관계는 연결된 그룹 전체를 오답에서 제외한다.

## S5: 사람 검수

```sh
.venv-content/bin/python -m tool.content review-export --input content/review/llm_pilot.jsonl --output content/review/pilot.csv
```

`candidatesJson`, `llmReviewJson`, `autoWarningsJson`, 기존 ID·뜻을 읽고 다음 열을 채운다.

| 열 | 입력 |
| --- | --- |
| `senseIndex` / `exampleIndex` | **0부터 시작**하는 의미 후보·예문 번호 |
| `editsJson` | 선택한 의미에 적용할 JSON. 예: `{"meaningKo":"달성하다","meaningKoAlt":["성취하다"]}`. 예문 수정은 `examples` 두 항목을 모두 포함 |
| `decision` | `human_approved`, `needs_fix`, `rejected`. 빈칸은 보류 |
| `reviewer` / `note` | 실제 검수자와 판단 근거 |
| `identityConfirmed` | 기존 ID가 있다면 동일한 의미임을 확인하고 `true`. 의미가 바뀌면 먼저 새 ID 발급·명시적 폐기 연결 |

`inputHash` 등 원본 열을 수정하지 않는다. 오래된 표·중복 행·검수자 누락·잘못된 수정은 거절된다. 수정한 내용은 다시 S3 검사하고, 처리 중 오류가 나면 승인 파일을 쓰지 않는다.

```sh
.venv-content/bin/python -m tool.content review-import --input content/review/llm_pilot.jsonl --csv content/review/pilot.csv --output content/review/human_pilot.jsonl
.venv-content/bin/python -m tool.content secondary-export --input content/approved/senses.jsonl --output content/review/secondary.csv
```

재검수 표의 다른 검수자가 `agree`, `criticalError`를 `true`/`false`로 입력한다. 표본은 sense ID 해시로 결정하므로 재실행할 때 바뀌지 않으며, 총량의 10%를 올림한다. 승인 원고가 바뀌면 표본을 다시 내보낸다.

```sh
.venv-content/bin/python -m tool.content secondary-import --input content/approved/senses.jsonl --csv content/review/secondary.csv --output content/review/secondary.jsonl
.venv-content/bin/python -m tool.content gold-promote --input content/approved/senses.jsonl
```

사람 검수 결과의 `.metrics.json`에 무수정 승인율·수정 필요·반려 건수를 기록한다. 의미 제안이나 첫 예문 선택을 바꾼 것도 수정으로 계산한다. 100개 이상에서 무수정 승인율 80% 이상이어야 파일럿 목표를 달성한 것으로 표시한다. 임계값 미달 시 프롬프트를 새 버전으로 수정해 비교한다.

## S6: 음성

Google은 구현된 **후보 어댑터**다. 공급자 확정과 파일 재배포 권한 확인은 남아 있다. 실제 검토 후 `config.json`의 `tts.distributionApproval`에 `allowed: true`, `reviewer`, `reviewedAt`, 원문 `termsUrl`을 기록해야 합성할 수 있다. 한국어 파일이 필요하면 `includeKorean: true`, 동형이의어는 `phonemes`에 sense ID별 IPA를 지정한다.

```sh
.venv-content/bin/python -m tool.content tts-plan
.venv-content/bin/python -m tool.content tts-synthesize
.venv-content/bin/python -m tool.content tts-asr --model small
.venv-content/bin/python -m tool.content listen-export --input content/audio_manifest.jsonl --output content/review/listening.csv
```

합성 파일명에는 텍스트·음색·엔진·SSML 발음·정규화/인코딩 설정의 SHA-1을 사용한다. 파일 무결성은 별도 SHA-256으로 검사한다. 같은 텍스트·설정은 재사용하며, 의미의 다른 필드가 바뀌어도 같은 음성을 다시 과금해 합성하지 않는다. 필요한 청취 승인은 새 의미 맥락에 맞게 무효화한다.

ffmpeg로 앞뒤 무음을 정리하고 약 -16 LUFS, 모노 AAC 40kbps로 만든다. 시간·무음 이상치, 동형이의어, 숫자·약어, ASR 불일치 및 결정론적 표본은 청취 대상으로 표시한다. ASR 모델의 첫 실행에는 모델 다운로드가 필요할 수 있다. 듣기 표를 실제로 들은 뒤 `reviewer`, `decision`(`approved`/`rejected`), `note`를 채운다.

```sh
.venv-content/bin/python -m tool.content listen-import --input content/audio_manifest.jsonl --csv content/review/listening.csv
```

## 반복 제작과 변경 검수

[2차 검토 결과와 증분 검수 절차](content-editorial-review.md)를 따른다. `audit --package ... --previous .../snapshot.json --output ...`으로 새·수정 원고와 영향을 받은 기존 선택지만 추린다. 자동 검사는 전체 실행하고, 미해결 판단은 별도 검토 기록에서 이어간다.

## 개발용 파일럿 앱 미리보기

```sh
.venv-content/bin/python -m tool.content dev-preview --input content/pilots/pilot-v1/codex.reviewed.jsonl --identities content/pilots/pilot-v1/preview-identities.json --output content/previews/pilot-v2
.venv-content/bin/python -m tool.content dev-install content/previews/pilot-v2
```

이 경로는 사람 승인·음성 합성을 요구하지 않는 개발용 미리보기다. 입력을 S3로 다시 검사하고 내용 검토 해시가 일치하는지 확인한다. `developmentOnly: true`를 유지하므로 release 앱에서는 열리지 않는다. 기존 `build`·`install`의 출시 검증은 그대로이며, `dev-install`은 설치된 출시 데이터를 덮어쓰지 않는다. 같은 입력은 같은 빌드 해시를 사용하고, 수정한 입력은 새 출력 디렉터리로 빌드한다.

모든 의미 후보를 별도 카드로 편성하며 두 예문을 모두 SQLite에 담는다. 학습·연속 듣기는 첫 예문을 사용하고, 단어 상세의 ‘다른 예문’에서 두 번째 예문과 번역·기기 TTS를 확인한다. API 호출이나 음성 팩 없이 기기 TTS를 사용한다.

`preview-identities.json`은 기존 의미와 직접 대조한 5개 의미의 ID를 유지한다. `practice`의 명사는 동사 진도를 물려받지 않는다. 나머지 후보는 `preview.` 접두사의 개발용 ID를 쓰며 정식 ID 레지스트리는 변경하지 않는다. 출시 시 의미 동일성 검수 후 명시적인 ID 이전이 필요하다. 이번 표본에 없는 기존 카드의 진도와 세션은 사용자 DB의 기존 보존 로직을 따른다.

의미별 허용 철자는 초기 색인과 상세 읽기 모두 동일하게 유지한다. 뜻 문제에는 품사와 연어를 표시해 다의어의 문맥을 구분한다. 안전한 같은 품사 오답이 3개 미만인 12개 카드는 뜻을 먼저 떠올린 후 펼치고 ‘기억했어요’/‘다시 익힐게요’로 직접 평가한다. 뜻을 펼치는 것만으로 정답을 기록하지 않는다. 사람 승인 파일과 검수 CSV는 변경하지 않는다.

## S7: 빌드·설치

```sh
.venv-content/bin/python -m tool.content build --secondary content/review/secondary.jsonl --version 2026.10.1 --output content/releases/2026.10.1
.venv-content/bin/python -m tool.content install content/releases/2026.10.1
```

현재 CLI·함수에 남은 기본 기대 수량은 300개 **의미**이며, 표제어당 하나만 허용하므로 표제어 수도 같다. 이는 기존 구현값으로 새 출시 기준이 아니다. 분량 변경은 `--expected-count`로 명시할 수 있지만, 학년·레벨 편성 검사와 다의어 정식 빌드는 별도로 구현해야 한다. `--audio-base-url https://.../2026.10.1`을 설정하면 단어장 팩 URL이 생성된다. 업로드는 별도 운영 작업이며 이 도구가 수행하지 않는다. URL이 없으면 앱은 준비된 번들 음성과 기기 TTS를 사용하고 다운로드 준비 중으로 표시한다.

빌드는 다음을 모두 확인한다: 현재 CSV에 대한 두 사람 대조, 모든 원고의 현재 해시와 `human_approved`, 발급된 대표 ID, 원고 전체 재검증·중복 검사, 10% 독립 재검수와 치명 오류 0건, 각 의미마다 같은 품사의 안전한 오답 3개 이상, 영어 단어·예문 음성, ASR·필수 청취 승인, 실제 파일 무결성. 어느 하나라도 없으면 최종 패키지를 만들지 않는다.

초등 권장과 나머지를 분리하고 품사 균형·선택지 충돌을 고려해 최대 20개씩 편성한다. 각 그룹의 마지막 단어장은 남은 수량만 담는다. 확인된 라이선스의 내부 빈도 자료가 있으면 `--frequency-ranks`로 `{표제어: 순위}` JSON을 제공한다. 없으면 품사 균형과 표제어 순서만 이용하며, 순위 값은 앱에 넣지 않는다. NGSL 데이터는 포함하지 않았다.

결과는 `content.sqlite`, `catalog.json`, `id_migrations.json`, 첫 단어장의 `audio_bundle/`, 전체 단어장의 `packs/*.zip`이다. SQLite는 사용자 DB와 별개이며 텍스트 검색·단어장/의미별 부분 읽기를 지원한다. 앱은 가벼운 검색·퀴즈 색인만 먼저 읽고, 학습 5개·상세·듣기 단위로 본문을 읽는다. UI의 짧은 단어장 검색은 이 색인에서 수행한다.

같은 버전·같은 입력의 빌드는 기존 결과를 재사용한다. 같은 버전에 다른 입력을 넣으면 실패한다. 새 버전은 새 디렉터리에 만든다. `install`은 앱 자산에 텍스트 DB·첫 음성만 복사하고 다운로드 ZIP은 포함하지 않는다. 네트워크 팩은 HTTPS·전체/개별 SHA-256·크기·경로를 검사한 뒤 설치한다.

## 검증

```sh
.venv-content/bin/python -m unittest discover -s tool/content/tests -v
flutter analyze
flutter test
flutter test integration_test/persistence_test.dart -d <ios-simulator-id>
flutter build apk --debug
```

실제 API 과금 요청과 실제 합성 음성 품질은 로컬 자동 테스트의 대상이 아니다. 테스트의 가짜 검수자·가짜 음성은 임시 디렉터리에만 생성되며 배포 자산에 포함하지 않는다. 현재 실제 승인 데이터는 비어 있다.

개발 fixture 재생성은 `.venv-content/bin/python -m tool.content.bootstrap`이다. 설치된 출시 패키지가 있으면 덮어쓰지 않는다.

## API 근거

- [Anthropic Message Batches](https://platform.claude.com/docs/en/build-with-claude/batch-processing)
- [Anthropic 구조화 출력](https://platform.claude.com/docs/en/build-with-claude/structured-outputs)
- [Anthropic 모델 ID](https://platform.claude.com/docs/en/models/overview)
- [Google TTS REST](https://docs.cloud.google.com/text-to-speech/docs/reference/rest/v1/text/synthesize)
- [Google SSML](https://docs.cloud.google.com/text-to-speech/docs/ssml)

위 링크는 API 사용 근거다. 음성 재배포 권한 확인을 대신하지 않는다.
