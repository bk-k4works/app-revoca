# 고등 영단어 트랙 (high-v1)

기준일: 2026-10-16. 앱의 1차 대상을 **고등학생(내신·수능)**으로 정했다. 중학 영단어는 앱에서 '준비 중'으로 표시한다.

## 콘텐츠 원칙

제공 PDF 『사랑 영단어 수능 2000』에서는 **표제어 목록만** 참고한다. 나머지는 앱의 방향에 맞춰 새로 만든다.

| 사용함 | 사용하지 않음 |
| --- | --- |
| 표제어 2,000개(철자) | 교재의 뜻풀이·예문·번역·연어 표현 |
| | 모의고사·수능 출처 예문(`06모고` 등) |
| | Day 1–50·FIRST/SECOND HALF 순서와 쪽 구성 |

- 단계는 공개된 교육과정 기본 어휘 목록의 표시를 기준으로 나눈다. 단계 안의 순서는 공개 빈도 자료 [wordfreq](https://pypi.org/project/wordfreq/)로 정한다. 교재의 단원 순서와 관계없는 우리만의 구성이다.
- 뜻·설명·연어·예문 2개·번역은 표제어만 보고 직접 작성한다. 교재 원문과 대조하는 작업은 하지 않았다.
- 교재 항목 ID와의 연결은 로컬 대조용 `content/sources/highschool_v1.provenance.json`에만 남긴다. 이 정보는 앱 패키지에 넣지 않는다.
- 이는 저작권 위험을 줄이는 편집 방침이다. 법률 검토를 대신하지 않는다. 출시 전에 목록 활용 범위를 한 번 더 확인한다.

## 단계

| 단계 | 기준 | 표제어 |
| --- | --- | ---: |
| 고교 기본 (`basic`) | 교육과정 목록 `**` 표시와 정확히 일치 | 540 |
| 아는 단어, 새로운 뜻 (`familiar`) | 교육과정 목록 `*`(초등) 표시와 정확히 일치 | 59 |
| 고교 핵심 (`core`) | 목록 무표시 일치, 변형·관련형 일치, 목록 밖이지만 빈도 Zipf 4.0 이상 | 881 |
| 핵심 숙어 (`phrase`) | 띄어쓰기가 있는 숙어·구 (예: in order to, get along with) | 89 |
| 수능 심화 (`advanced`) | 목록 밖이고 빈도 Zipf 4.0 미만 | 431 |

**아는 단어, 새로운 뜻:** book·room·class처럼 초등에서 배운 단어다. 고등학생이 이미 아는 기본 뜻(책·방·수업)은 학습 카드에서 빼고, 수능에서 중요한 확장 의미(예약하다·여지·계층)를 대표 뜻으로 가르친다. 기본 뜻은 설명 첫머리에 `'책' 외에 …`처럼 한 번 언급한다. 뺀 기본 뜻 원고 27개는 `content/highschool/v1/reserve/familiar-first-senses.txt`에 보존한다. 이 원고는 앱에 넣지 않으며, 중학 트랙에서 다시 검토해 쓸 수 있다. 확장 의미가 마땅치 않은 단어(`any`, `change` 등)는 기본 뜻을 유지한다.

**핵심 숙어:** 빈도 자료가 여러 단어로 된 구의 빈도를 높게 잡는다. 그래서 숙어를 단어와 섞으면 고교 핵심 상위가 숙어로 채워진다. 이를 피하려고 숙어는 별도 단계로 분리했다.

- **철자 채점:** 숙어 전체를 입력한다. 대소문자, 앞뒤·중간의 여러 칸 띄어쓰기, 굽은 따옴표(’)는 무시한다. 단어가 빠지거나 붙여 쓰면 오답이다. 철자 화면에는 '구 · 3단어 표현'처럼 단어 수 힌트가 나온다.
- **예문 검사:** 숙어는 예문에 끊김 없이 정확히 한 번 나와야 한다. 활용형(are supposed to, got along with, hung up)은 인정한다. 중간에 다른 단어가 끼면(get along **well** with, are **not** supposed to, take **it** for granted) 인정하지 않으므로, 예문은 끊기지 않는 형태로 쓴다.
- **객관식:** 숙어끼리만 선택지를 구성한다. 뜻이 같은 단어(despite ↔ in spite of)와 유의 숙어(instead of ↔ rather than)는 오답 선택지에서 제외한다.

단어장은 단계별로 **20단어씩** 묶는다. 한 단어의 뜻은 여러 단어장에 나누지 않는다. 마지막 묶음이 5단어 미만이면 따로 두지 않고 앞 단어장에 합친다(예: 21단어). 예: `고교 기본 01 · 20단어 · 뜻 50개`.

## 작성 형식과 문체

- 원고: `content/highschool/v1/authored/part-*.txt`
- 형식: `표제어|품사|slug|뜻(;대체 뜻)|설명|연어|연어 뜻|예문1|번역1|예문2|번역2|유의어(쉼표, 선택)`
- 한 단어에 뜻은 1–3개. 수능·내신에서 중요한 확장 의미(예: book 예약하다, room 여지, matter 물질)를 포함한다.
- 영어 예문: 6–20단어. 표제어(활용형 포함)는 정확히 한 번 나온다. 실존 인물·브랜드는 피한다.
- 번역: 평서체(`~다`). 설명: 40자 이내의 해요체.
- 철자 채점은 교육과정 목록의 변형 철자(labour, favour, licence 등)를 함께 인정한다. 단, `technic`처럼 별개의 단어는 `NOT_SPELLINGS`로 제외한다.
- 어휘 범위 검사는 교육과정 3,000개와 고교 2,000개를 합친 목록으로 한다. 일상 합성어와 불규칙형은 `content/sources/word_forms_high.json`에 따로 확장했다. 범위 밖 단어가 1개면 경고, 2개 이상이면 오류다.

## 현재 상태

| 항목 | 값 |
| --- | --- |
| 작성 완료 | **2,000개 전체** (뜻 2,594개, 예문 5,188개). 고교 기본 540, 아는 단어 59, 고교 핵심 881, 핵심 숙어 89, 수능 심화 431 |
| 단어장 | 고교 기본 01–27, 아는 단어, 새로운 뜻 01–03, 고교 핵심 01–44, 핵심 숙어 01–05, 수능 심화 01–22 (총 101개) |
| 자동 검사 | 2,000단어 모두 통과. 범위 밖 단어 1개 등의 경고는 남음. 같은 품사 대표 뜻·연어·설명 중복은 테스트로 막음 |
| 검토 | 작성자 전체 재검토 1회(2026-10-17, [수정 목록](highschool-review-2026-10.md)). Codex 독립 검토 7회차 완료(2026-10-18, 사람 검수 1차 반영분 포함 뜻 2,594개 전부, [기록](../content/highschool/v1/review/codex-v1/README.md)). 사람 승인 0건 |
| 앱 설치 | `assets/content/`에 개발용(`developmentOnly`)으로 설치. release 빌드는 기존처럼 차단됨 |

이전 중학 파일럿(100개 표제어)은 `content/previews/pilot-v2/`와 `content/pilots/pilot-v1/`에 그대로 보존했다.

## 명령

```sh
# 1) 고교 원천 목록 (교재 표제어 + 교육과정 단계 + 빈도 순서)
.venv-content/bin/python -m tool.content hs-source

# 2) 원고 변환과 자동 검사
.venv-content/bin/python -m tool.content hs-draft \
  --input content/highschool/v1/authored --output content/highschool/v1/drafts.jsonl

# 3) 개발 패키지 만들기 (새 출력 폴더) 및 앱에 설치
.venv-content/bin/python -m tool.content hs-preview \
  --input content/highschool/v1/drafts.jsonl --output content/previews/high-NEXT
.venv-content/bin/python -m tool.content dev-install content/previews/high-NEXT
```

## 검토와 승인

출시 패키지는 아래 세 단계를 모두 거친 뜻만 담는다. 개발용 `hs-preview`와 달리 `hs-release`는 하나라도 빠지면 빌드를 멈춘다.

1. **자동 검사** (`hs-draft`): 예문 길이·표제어 출현·어휘 범위·문체 규칙.
2. **Codex 독립 검토**: 원고를 쓰지 않은 다른 모델(OpenAI Codex CLI, 읽기 전용)이 뜻마다 `ok`·`minor`·`fix`·`reject`를 판정하고 빠진 중요 뜻을 제안한다. 판정은 뜻 텍스트의 해시(`inputHash`)에 묶여 있어서 원고를 고치면 그 뜻은 다시 검토받아야 한다. 검토 기준은 `content/highschool/v1/review/codex-v1/prompt.md`에 있다.
3. **사람 승인**: 웹 승인 화면(아래)이나 검수표(CSV)에서 뜻마다 `human_approved`·`needs_fix`·`rejected`를 고르고 실제 검수자 이름을 적는다. 수정·반려에는 이유가 필요하고, 기계 검토자 이름(codex, claude 등)은 받지 않는다. 결정은 `review/human/decisions.jsonl`에 쌓이며, 원고가 바뀐 뒤의 오래된 행은 거절된다.

```sh
# Codex 검토 묶음 만들기 → 실행 → 판정 합치기
.venv-content/bin/python -m tool.content hs-review-prepare
cd content/highschool/v1/review/codex-v1 && cat prompt.md batches/batch-01.txt | \
  codex exec -s read-only --ephemeral --output-schema schema.json -o results/batch-01.json -
.venv-content/bin/python -m tool.content hs-review-merge

# 사람 검수표 내보내기 → 채운 뒤 가져오기 → 현황
.venv-content/bin/python -m tool.content hs-review-export
.venv-content/bin/python -m tool.content hs-review-import --csv content/highschool/v1/review/human/review.csv
.venv-content/bin/python -m tool.content hs-review-status

# 웹 승인 화면: 데이터 만들기 → 화면에서 결정 → '결정 파일 받기' JSON 가져오기
.venv-content/bin/python -m tool.content hs-review-web-export
.venv-content/bin/python -m tool.content hs-review-web-import --json ~/Downloads/revoca-decisions-*.json

# 모든 뜻의 결정이 끝나면 출시 패키지
.venv-content/bin/python -m tool.content hs-release --input content/highschool/v1/drafts.jsonl \
  --output content/releases/high-1.0.0 --version high-1.0.0
.venv-content/bin/python -m tool.content install content/releases/high-1.0.0
```

### 표제어 표기

교재 목록의 표제어는 소문자·단수로 정규화되어 있다. 고유명사(Antarctica)나 복수형으로만 쓰는 뜻(customs 세관), 표준 표현이 다른 숙어(with respect to)는 `content/highschool/v1/display_forms.json`에 뜻(`headword|pos|slug`)별 표기를 적는다. 목록 키와 뜻 ID는 바뀌지 않고, 앱은 그 뜻에서만 이 표기를 보여 주고 철자 정답으로도 받는다. 표기는 그 뜻의 검토 해시에 들어간다.

### 웹 승인 화면

`tool/review-web/index.html`은 claude.ai Artifact로 게시하는 승인 화면이다. 뜻 카드마다 뜻·설명·연어·예문 2개·유의어와 Codex 지적을 보여 주고 **승인**·**수정 필요**·**반려**를 누른다(키보드 `J`/`K`로 이동, `A`·`F`·`R`로 결정). 수정·반려는 이유를 적어야 저장된다.

- 데이터: `hs-review-web-export`가 만든 `build/review-web/senses.json`을 화면과 함께 게시한다(저장소에는 넣지 않는다). 원고를 고치면 다시 만들어 게시한다.
- 저장: 결정은 Artifact 저장소 `review/<part>/decisions/<뜻 id>`에 `{senseKey, inputHash, decision, note, reviewerId, decidedAt}`로 남는다. 검수자는 처음에 자기 이름을 `reviewers/<계정 id>`에 저장하고, 그 문서는 본인만 고칠 수 있다.
- 원고가 바뀐 뜻은 해시가 달라 화면에 '원고 바뀜'으로 표시되고 미결정으로 센다.
- 권한: 소유자와 기여자(Contributor) 이상만 결정을 남긴다. 다른 검수자에게는 Share 메뉴에서 기여자 권한을 준다.
- 가져오기: 화면의 **결정 파일 받기**로 받은 JSON을 `hs-review-web-import`로 `decisions.jsonl`에 더한다. 해시가 다른 결정은 건너뛰어 보고하고, 이미 기록된 같은 결정은 다시 쓰지 않으므로 같은 파일을 여러 번 가져와도 된다. 기계 검토자 이름은 여기서도 받지 않는다.

## 다음 작업

1. 사람 승인: 웹 승인 화면(또는 `review/human/review.csv`)에서 뜻 2,594개의 결정을 기록한다. 모두 결정되면 `hs-release`로 출시 패키지를 만든다.
2. 철자 문제에서 뜻이 같은 다른 표제어(예: nevertheless·nonetheless)를 쓰면 오답 대신 안내하는 방식을 검토한다. 원고에서는 같은 품사의 대표 뜻을 모두 구분했지만, 진짜 유의어는 뜻만으로 완전히 가를 수 없다.
