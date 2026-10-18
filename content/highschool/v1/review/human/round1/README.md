# 사람 검수 1차 반영 (고등 트랙 v1)

- 검수: 웹 승인 화면(2026-10-18), 검수자 BK. 전체 2,594개 중 승인 2,439, 수정 필요 155, 반려 0.
- 반영: 2026-10-18, Claude. 수정 필요 155건을 모두 반영했다. 150건은 원고 수정, 5건은 표제어 표기(아래)다.
- 반영한 뜻은 `inputHash`가 바뀌어 승인 화면에 '원고 바뀜'으로 다시 나온다. Codex 판정도 다시 받아야 한다.

## 파일

- `patch.tsv`: `tool/content/hs_patch.py` 형식의 수정 목록(뜻 149개, 216곳)
- `changes-round1.jsonl`: 적용 기록(이전 값·새 값·이유). 마지막 줄은 former의 품사 변경이다.
- `patch-forms.tsv`, `changes-forms.jsonl`: 표기 5건에 맞춘 원고 수정(with respect to 연어·예문, customs·belongings 설명)

## 검수 의견과 다르게 반영한 곳

- quarrel(명사·동사): '사소한' 제한은 뺐지만, argument·argue와 대표 뜻이 겹치지 않도록 '언쟁; 말다툼', '언쟁하다; 말다툼하다' 순서로 두었다. 철자 문제에서 정답이 둘이 되지 않게 하는 원고 규칙 때문이다.
- doze: '조신다'는 '졸다'의 바른 높임형이고, 제안된 '주무신다'는 '자다'라서 뜻이 바뀐다. 대신 '졸곤 하신다'로 다듬었다.
- attach, elderly, remind: 고교 트랙 번역은 평서체(~다·~라) 규칙이라 '첨부해라', '양보해 드려라', '알려 달라'로 썼다.
- lung, reflection: 제안 예문의 gills·shimmered는 예문 어휘 범위 밖이라 같은 뜻을 범위 안의 말로 썼다.
- former: 품사를 대명사로 바꿨다. 뜻 ID가 `hs.former.n.first-of-two`에서 `hs.former.pron.first-of-two`로 바뀐다(고교 개발 패키지는 ID 이전을 쓰지 않는다).

## 표제어 표기 5건

교재 목록의 표제어(목록 키)와 뜻 ID는 그대로 두고, 앱에 보이는 표기만 뜻 단위로 바꿨다. 표기는 `content/highschool/v1/display_forms.json`에 있다.

| 뜻 | 화면 표기 | 철자 정답 |
| --- | --- | --- |
| antarctica\|n\|south-pole-continent | Antarctica | antarctica (대소문자 무관) |
| atlantic\|adj\|ocean | Atlantic | atlantic (대소문자 무관) |
| belonging\|n\|possessions | belongings | belonging, belongings |
| custom\|n\|border-control | customs | custom, customs |
| in respect to\|phrase\|concerning | with respect to | in respect to, with respect to |

- 같은 표제어의 다른 뜻(custom 관습, belonging 소속감)은 단수 표기와 단수 철자만 쓴다.
- 표기는 검토 대상이라 이 5개 뜻의 `inputHash`에 들어간다(다른 뜻의 해시는 그대로다). 승인 화면에서 '원고 바뀜'으로 다시 나온다.

## 결정 가져오기

2026-10-18 승인 화면의 결정 2,594건(승인 2,439, 수정 필요 155)을 `hs-review-web-import`로 `review/human/decisions.jsonl`에 넣었다.

- 승인 2,439건은 모두 기록됐다(원고가 바뀌지 않은 뜻이다).
- 수정 필요 154건은 원고를 고쳐 해시가 달라졌으므로 '오래된 결정'으로 건너뛰었다. former는 품사 변경으로 키가 `former|pron|first-of-two`가 되어 가져오기 파일에서 뺐다.
- 남은 일: 이 155개 뜻은 Codex 재검토 후 승인 화면에서 사람이 다시 결정해야 출시 패키지에 들어간다.

## 재승인 (2026-10-18)

- 1차 수정 155건은 Codex 6·7차 재검토를 모두 받은 뒤(ok 147, minor 7, fix 1), BK가 채팅에서 일괄 승인을 지시했다. 카드별로 다시 확인한 승인은 아니라서 `decisions.jsonl`에 `via: "chat"`과 그 사실을 적은 note, 당시 Codex 판정(`codexVerdict`)을 함께 남겼다.
- 남은 Codex 지적(minor 7건, fix 1건: apparent의 뜻 '분명해 보이는')은 승인 화면의 'Codex 지적 있음' 필터로 볼 수 있다.
- 이로써 뜻 2,594개 모두 사람 승인 상태이고, `hs-release`가 통과한다.
