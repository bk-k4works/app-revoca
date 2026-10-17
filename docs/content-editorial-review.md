# 파일럿 2차 콘텐츠 검토와 이후 증분 검수

2026-10-16, Codex 세션에서 100개 표제어·154개 의미·308개 영한 예문 쌍과 현재 뜻 문제를 검토했다. 같은 작성 계열 모델의 검토이며 사람 승인이나 독립 검수로 간주하지 않는다. 앱은 개발 전용 상태를 유지한다.

## 이번 수정

- `be`: 정체와 상태를 모두 설명하도록 뜻을 보완하고, 첫 예문은 학생이라는 신분을 서술하도록 수정했다.
- `can`: 능력 후보에서 요청으로 읽힐 수 있는 질문을 능력 서술문으로 바꿨다.
- `close`: 형용사 예문을 명확한 서술 형용사 구조로 바꿨다. 기존 문장을 비문으로 판정한 것은 아니다.
- `congress`: 선택된 의미에 맞게 한국어 뜻을 ‘학술 대회’로 구체화했다. 의회 의미를 제외한 대표 의미 선정은 최종 편집 판단이 남는다.
- `environ`: 문어적 표현임을 설명에 표시했다.
- `minute`: 대화상 ‘잠깐’의 번역을 보완하고, 퀴즈 연어는 `ten minutes`로 바꿔 시간 단위 의미를 분명히 했다.
- `revive`: 사람·팀의 활력 회복을 보여 주는 연어와 예문으로 수정했다. 활성화 후보와의 최종 통합 여부는 보류했다.
- `starve`: 단순한 공복으로 오해하지 않게 설명을 보완했다.
- `quite`: 정도 용법의 지역·문맥 차이를 설명에 추가했다.
- `that`: 한정사의 보조 뜻에 ‘그’를 추가했다.
- `brilliant/neat/vivid`: 문맥상 해석이 겹치는 후보를 상호 오답에서 제외했다.

`pat`의 쓰다듬는 번역은 사전의 용법 범위에도 포함되어 유지했다. 사전 정의는 사실 확인에만 참고했으며 예문을 복사하지 않았다. 참고: [pat](https://www.merriam-webster.com/dictionary/pat), [close](https://www.merriam-webster.com/dictionary/close), [revive](https://www.merriam-webster.com/dictionary/revive), [quite](https://www.merriam-webster.com/dictionary/quite).

뜻 길이가 같은 오답 후보를 매번 알파벳 순서로 선택하던 규칙은 의미 ID에 따른 결정론적 분산으로 바꿨다. 같은 문제는 같은 선택지를 유지하되 여러 문제에서 특정 세 단어만 반복되는 현상을 줄인다. 같은 품사·유의어 제외·뜻 중복 방지 조건은 유지한다. 154개 문제 중 142개는 객관식, 12개는 안전한 오답 수가 부족해 직접 평가다. 객관식 전체의 실제 Dart 선택지와 Python 감사 결과가 같은지 테스트한다.

현재 선택지에서 대체 정답을 발견하지 못했으나, 난이도·학습 효과가 검증됐다는 뜻은 아니다. 일부 문제는 오답이 쉬우며 파일럿 확장 후에도 품질 검토가 필요하다. `congress/environ`의 초급 적합성, `revive` 후보 통합, 단일 후보 46개 범위, 소재 관련 기존 플래그, 동형이의어 기기 TTS 발음은 최종 검수 대상으로 남는다. 전체 사람 승인 건수는 0이다.

## 새 단어가 추가될 때

1. 새·수정 원고를 작성하고 자동 검사를 실행한다. 형식·범위·중복·허용 철자 검사는 저비용이므로 전체 입력에 실행한다.
2. 새·수정 항목의 뜻·품사·연어·두 예문·번역을 Codex에서 검토한다. 내용이 바뀐 항목의 이전 검토 해시는 재사용하지 않는다.
3. 개발 패키지를 만든 뒤 `audit`으로 이전 스냅샷과 비교한다. 기존 문제라도 오답이나 문맥이 바뀌면 선택지 검수 대상으로 올라온다.
4. 변경 대상과 이전의 미해결 판단 항목을 함께 검토한다. 출시용 사람 승인·원천 대조·음성 검수는 기존 절차대로 별도로 기록한다.
5. 같은 결과를 다시 비교할 때 새로운 내용·문제 검수는 생기지 않는다. 다만 검수 규칙이나 출제 코드가 바뀌면 전체를 재검토한다.

```sh
.venv-content/bin/python -m tool.content audit \
  --package content/previews/NEXT_VERSION \
  --previous content/pilots/pilot-v1/audit-editorial-v2/snapshot.json \
  --output content/audits/NEXT_VERSION
```

`NEXT_VERSION`은 새 출력 디렉터리 이름으로 바꾼다. 결과는 `snapshot.json`(내용·문제 해시와 실제 선택지), `queue.json`(추가·변경·삭제·규칙 변경), `review.md`(검토할 원고·예문·선택지)다. 이전 스냅샷은 보존하고 새로운 경로로 출력한다. `audit`은 검수 대상을 추리는 도구이며, 실행하거나 스냅샷을 만들었다고 승인 상태가 바뀌지 않는다. 미해결 판단은 `editorial-ledger-v2.jsonl` 및 사람 검수표와 함께 이어서 관리해야 한다.

이번 `audit-baseline-v2`는 수정 전 원고를 **새 선택지 규칙으로 재계산한 비교 기준**이다. 같은 규칙에서 원고 수정만 비교하면 내용 16개·문제 15개가 바뀐다. 기존 앱의 옛 선택지와 비교한 수치가 아니다. 이번에는 출제 규칙도 바뀌었으므로 전체 154개를 검토했다. `audit-unchanged-v2`는 수정본을 다시 비교했을 때 신규 검수 대상이 0개임을 확인한다.

## 기록

- 수정 전 원고: `content/pilots/pilot-v1/history/before-editorial-v2/`
- 원고 변경 내역: `content/pilots/pilot-v1/editorial-changes-v2.json`
- 단어별 검토 메모: `content/pilots/pilot-v1/editorial-notes-v2.json`
- 의미별 검토와 미해결 항목: `content/pilots/pilot-v1/editorial-ledger-v2.jsonl`
- 앱 선택지: `content/pilots/pilot-v1/audit-editorial-v2/snapshot.json`
- 수정본 개발 패키지: `content/previews/pilot-v2/`

기존 사람 검수표는 작성된 결정이 없는 것을 확인한 뒤 원본을 이력으로 보존하고, 새 입력 해시에 맞는 빈 표를 생성했다. 원천 비교·사람 승인 기록은 추가하지 않았다.
