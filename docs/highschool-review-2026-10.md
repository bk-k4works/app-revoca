# 고등 트랙 원고 전체 검토 수정 목록

- 검토일: 2026-10-17
- 대상: `content/highschool/v1/authored/part-01.txt` ~ `part-30.txt` (표제어 2,000개)
- 결과 패키지: `content/previews/high-v12` (뜻 2,587개, 예문 5,174개, 단어장 101개)

## 요약

| 구분 | 고친 항목 수 |
| --- | ---: |
| 빠진 중요 뜻 추가 | 9 |
| 숙어 표제어와 겹친 뜻 정리 | 5 |
| 단어장 사이에 겹친 연어 교체 | 35 |
| 단어장 사이에 겹친 예문 교체 | 41 |
| 뜻이 비슷한 단어의 같은 설명 구분 | 29 |
| 같은 품사의 같은 대표 뜻 구분 | 289 |
| 어색한 예문 교체 | 12 |
| 번역투·어색한 번역 다듬기 | 65 |
| **합계** | **485** |

항목 수는 뜻 카드 하나를 한 번으로 셌어요. 한 카드에서 예문과 번역을 함께 고친 것도 1건이에요.

### 이번에 일부러 고치지 않은 것

- 번역의 "그녀"(약 580곳): 영어 주어를 그대로 보여 주는 학습용 번역이라 남겼어요. 다만 "그는 ~ 그의"처럼 한 문장에서 겹친 대명사는 줄였어요.
- 뜻이 같은 진짜 유의어(despite·in spite of, immediately·right away 등): 품사가 달라 철자 문제 화면에서 구분돼서 그대로 두었어요.
- 같은 품사 안의 대표 뜻 중복은 0건이 되도록 고쳤고, 다시 생기지 않게 검사 테스트를 추가했어요.

## 빠진 중요 뜻 추가 (9)

수능·내신 지문에 자주 나오지만 원고에 없던 뜻을 새 뜻 카드로 넣었어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| term | 뜻, 설명 | 조건; 관점<br>in terms of처럼 계약 조건이나 관점을 말해요. | 조건; (사람 사이의) 관계<br>계약의 조건이나 사람 사이의 관계를 말해요. | 숙어 'in terms of'와 겹치던 '관점' 대신 시험에 자주 나오는 'be on good terms(사이가 좋다)' 뜻을 넣음 |
| resort | 새 뜻 (v) | — | **(~에) 의지하다; 호소하다**<br>We should never resort to violence to solve problems.<br>문제를 해결하려고 폭력에 의지해서는 절대 안 된다. | 수능 지문에 자주 나오는 동사 용법 'resort to(~에 의지하다)'가 없어 추가 |
| conflict | 새 뜻 (v) | — | **상충하다; 맞지 않다**<br>His story conflicts with what the witness said.<br>그의 이야기는 목격자의 말과 맞지 않는다. | 지문에 자주 나오는 동사 용법(conflict with, conflicting)이 없어 추가 |
| desire | 새 뜻 (v) | — | **바라다; 원하다**<br>The plan did not produce the desired result.<br>그 계획은 원하던 결과를 내지 못했다. | 명사 뜻만 있고 자주 쓰는 동사 뜻(desired result 등)이 없어 추가 |
| stretch | 새 뜻 (n) | — | **(길·시간의) 구간; 기간**<br>This stretch of road is dangerous at night.<br>이 도로 구간은 밤에 위험하다. | 동사 뜻만 있고 지문에 자주 나오는 명사 뜻(구간·기간)이 없어 추가 |
| dawn | 새 뜻 (v) | — | **(사실이) 분명해지다; 문득 깨닫게 되다**<br>It suddenly dawned on me that I had left my keys at home.<br>열쇠를 집에 두고 왔다는 것을 문득 깨달았다. | 독해에 자주 나오는 동사 용법 'dawn on(문득 깨닫다)'이 없어 추가 |
| progress | 새 뜻 (v) | — | **진행되다; 나아지다**<br>Work on the new bridge is progressing well.<br>새 다리 공사가 잘 진행되고 있다. | 명사 뜻만 있고 동사 뜻(진행되다)이 없어 추가 |
| aid | 새 뜻 (v) | — | **돕다; 도움이 되다**<br>Pictures can aid students in learning new words.<br>그림은 학생들이 새 단어를 익히는 데 도움이 될 수 있다. | 명사 뜻만 있고 동사 뜻(돕다)이 없어 추가 |
| subject | 새 뜻 (n) | — | **(실험) 대상자; 피험자**<br>The subjects in the study were asked to sleep less.<br>그 연구의 대상자들은 잠을 덜 자 달라는 요청을 받았다. | 수능 실험 지문에 자주 나오는 '실험 대상자' 뜻이 없어 추가 |

## 숙어 표제어와 겹친 뜻 정리 (5)

같은 내용이 단어 카드와 숙어 카드에 두 번 나오던 경우예요. 완전히 같은 뜻은 단어 쪽을 지우고, 겹치기만 한 것은 단어 쪽 연어·예문을 바꿨어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| account | 뜻 삭제 (v) | 설명하다; 차지하다 | — | 숙어 표제어 'account for'와 뜻·예문 역할이 완전히 같아 동사 뜻을 삭제 |
| hang | 뜻 삭제 (v) | (전화를) 끊다 | — | 숙어 표제어 'hang up'과 뜻·연어가 완전히 같아 삭제 |
| suppose | 뜻 삭제 (v) | (be supposed to) ~하기로 되어 있다 | — | 숙어 표제어 'be supposed to'와 뜻이 완전히 같아 삭제 |
| charge | 설명 | in charge of처럼 일을 맡아 관리하는 것이에요. | 어떤 일을 맡아 관리하는 것이에요. | 숙어 표제어 'in charge of'를 앞세우던 설명 교체 |
| depend | 설명, 연어, 연어 번역, 예문 1, 예문 1 번역, 예문 2, 예문 2 번역 | depend on으로 의존하거나 조건에 따라 달라질 때 써요.<br>depend on<br>~에 달려 있다<br>Our plan depends on the weather.<br>우리 계획은 날씨에 달려 있다.<br>Babies depend on their parents for everything.<br>아기는 모든 것을 부모에게 의존한다. | 'It depends.'처럼 상황에 따라 달라질 때 써요.<br>it depends<br>상황에 따라 다르다<br>Can you come tomorrow? It depends.<br>내일 올 수 있니? 상황에 따라 다르다.<br>Depending on the weather, we will go to the beach or the museum.<br>날씨에 따라 우리는 해변이나 박물관에 갈 것이다. | 숙어 표제어 'depend on'과 같던 설명을 단독 용법 중심으로 교체 |

## 단어장 사이에 겹친 연어 교체 (35)

두 표제어가 같은 연어를 쓰던 경우 한쪽을 그 단어다운 다른 연어로 바꿨어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| right | 연어, 연어 번역 | right now<br>지금 바로 | right next to<br>바로 옆에 | 숙어 표제어 'right now'와 같은 연어를 다른 연어로 교체 |
| whole | 연어, 연어 번역 | as a whole<br>전체로서 | on the whole<br>대체로 | 숙어 표제어 'as a whole'과 겹쳐 예문 2의 표현으로 교체 |
| board | 연어, 연어 번역 | a notice board<br>게시판 | on the board<br>칠판에 | notice의 연어 'a notice board'와 겹쳐 교체 |
| form | 연어, 연어 번역 | fill out a form<br>서식을 작성하다 | an application form<br>신청서 | 숙어 표제어 'fill out'과 같은 연어를 교체 |
| view | 연어, 연어 번역 | point of view<br>관점 | in my view<br>내 생각에는 | 숙어 표제어 'point of view'와 겹쳐 예문 1의 표현으로 교체 |
| political | 연어, 연어 번역 | a political party<br>정당 | political views<br>정치적 견해 | party의 연어 'a political party'와 겹쳐 교체 |
| improvement | 연어, 연어 번역 | room for improvement<br>개선의 여지 | a big improvement<br>큰 향상 | room의 연어 'room for improvement'와 겹쳐 교체 |
| damage | 연어, 연어 번역 | cause damage<br>피해를 일으키다 | serious damage<br>심각한 피해 | cause의 연어 'cause damage'와 겹쳐 교체 |
| notice | 연어, 연어 번역 | a notice board<br>게시판 | give notice<br>미리 알리다 | board와 같은 연어 'a notice board'를 예문 2의 표현으로 교체 |
| leading | 연어, 연어 번역 | a leading role<br>주연 | a leading cause<br>주요 원인 | role의 연어 'a leading role'과 겹쳐 교체 |
| factor | 연어, 연어 번역 | a key factor<br>핵심 요인 | an important factor<br>중요한 요인 | key의 연어 'a key factor'와 겹쳐 교체 |
| crime | 연어, 연어 번역 | commit a crime<br>범죄를 저지르다 | a serious crime<br>심각한 범죄 | commit의 연어 'commit a crime'과 겹쳐 교체 |
| species | 연어, 연어 번역 | endangered species<br>멸종 위기종 | a rare species<br>희귀종 | endangered와 같은 연어 'endangered species'를 교체 |
| organ | 연어, 연어 번역 | internal organs<br>내장 기관 | organ donation<br>장기 기증 | internal의 연어 'internal organs'와 겹쳐 교체 |
| positive | 연어, 연어 번역 | a positive attitude<br>긍정적인 태도 | stay positive<br>긍정적인 마음을 유지하다 | attitude의 연어 'a positive attitude'와 겹쳐 예문 1의 표현으로 교체 |
| grab | 연어, 연어 번역 | grab a bite<br>간단히 먹다 | grab someone's arm<br>~의 팔을 붙잡다 | bite와 같은 연어 'grab a bite'를 교체 |
| bite | 연어, 연어 번역 | grab a bite<br>간단히 먹다 | take a bite<br>한 입 먹다 | grab과 같은 연어를 예문 1의 표현으로 교체 |
| natural | 연어, 연어 번역 | natural resources<br>천연자원 | natural beauty<br>자연의 아름다움 | resource의 연어 'natural resources'와 겹쳐 교체 |
| scare | 연어, 연어 번역 | be scared of<br>~을 무서워하다 | scare away<br>겁주어 쫓아 버리다 | scared와 같은 연어 'be scared of'를 교체 |
| disappoint | 연어, 연어 번역 | be disappointed with<br>~에 실망하다 | disappoint the fans<br>팬들을 실망시키다 | disappointed와 같은 연어 'be disappointed with'를 교체 |
| economic | 연어, 연어 번역 | economic growth<br>경제 성장 | economic problems<br>경제 문제 | growth와 같은 연어 'economic growth'를 교체 |
| weakness | 연어, 연어 번역 | strengths and weaknesses<br>강점과 약점 | a weakness for<br>~을 몹시 좋아함 | strength와 같은 연어를 교체 |
| chemical | 연어, 연어 번역 | a chemical reaction<br>화학 반응 | chemical products<br>화학 제품 | reaction과 같은 연어 'a chemical reaction'을 교체 |
| fuel | 연어, 연어 번역 | fossil fuels<br>화석 연료 | save fuel<br>연료를 아끼다 | fossil과 같은 연어 'fossil fuels'를 교체 |
| thread | 연어, 연어 번역 | a needle and thread<br>바늘과 실 | lose the thread<br>맥락을 놓치다 | needle과 같은 연어 'a needle and thread'를 교체 |
| volcanic | 연어, 연어 번역 | volcanic ash<br>화산재 | volcanic activity<br>화산 활동 | ash와 같은 연어 'volcanic ash'를 교체 |
| sense | 연어, 연어 번역 | make sense<br>이치에 맞다 | in a sense<br>어떤 의미에서는 | 숙어 표제어 'make sense'와 같은 연어를 교체 |
| term | 연어, 연어 번역 | in terms of<br>~의 면에서 | on good terms<br>사이가 좋은 | 숙어 표제어 'in terms of'와 같은 연어를 교체 |
| charge | 연어, 연어 번역 | in charge of<br>~을 담당하는 | take charge<br>책임을 맡다 | 숙어 표제어 'in charge of'와 같은 연어를 교체 |
| return | 연어, 연어 번역 | in return<br>보답으로 | a high return<br>높은 수익 | 숙어 표제어 'in return'과 같은 연어를 교체 |
| range | 연어, 연어 번역 | a wide range of<br>폭넓은 | an age range<br>연령대 | 숙어 표제어 'a range of'와 겹치는 연어를 교체 |
| purpose | 연어, 연어 번역 | on purpose<br>일부러 | the purpose of<br>~의 목적 | 숙어 표제어 'on purpose'와 같은 연어를 교체 |
| mate | 연어, 연어 번역 | a classmate<br>반 친구 | my mates<br>내 친구들 | 표제어가 들어 있지 않은 연어 'a classmate'를 교체 |
| variety | 연어, 연어 번역 | a variety of<br>다양한 | for variety<br>변화를 주려고 | 숙어 표제어 'a variety of'와 같은 연어를 교체 |
| contrast | 연어, 연어 번역 | in contrast<br>대조적으로 | a sharp contrast<br>뚜렷한 대조 | 숙어 표제어 'in contrast'와 같은 연어를 교체 |

## 단어장 사이에 겹친 예문 교체 (41)

다른 표제어와 6단어 이상 똑같이 겹치거나 내용이 거의 같은 예문을 바꿨어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| right | 예문 1, 예문 1 번역 | I need to leave right now, or I will miss the bus.<br>지금 바로 떠나야 한다. 안 그러면 버스를 놓칠 것이다. | Call me right after the meeting ends.<br>회의가 끝나면 바로 나에게 전화해라. | 숙어 표제어 'right now'와 겹치는 예문 교체 |
| whole | 예문 1, 예문 1 번역 | The team must work as a whole to succeed.<br>팀이 성공하려면 하나로 움직여야 한다. | The whole is greater than the sum of its parts.<br>전체는 부분의 합보다 크다. | 숙어 표제어 'as a whole'을 그대로 쓰던 예문 교체 |
| species | 예문 2, 예문 2 번역 | The tiger is an endangered species.<br>호랑이는 멸종 위기종이다. | Scientists discovered a new species of frog.<br>과학자들은 새로운 종의 개구리를 발견했다. | endangered 예문과 겹치는 '멸종 위기종' 예문 교체 |
| natural | 예문 1, 예문 1 번역 | It is natural to feel nervous before a test.<br>시험 전에 긴장하는 것은 당연하다. | It is natural for parents to worry about their children.<br>부모가 자녀를 걱정하는 것은 당연하다. | quite의 예문과 6단어가 똑같이 겹쳐 교체 |
| sense | 예문 1, 예문 1 번역 | His explanation does not make sense to me.<br>그의 설명은 나에게 이해가 되지 않는다. | In a sense, every mistake is a lesson.<br>어떤 의미에서는 모든 실수가 교훈이다. | 숙어 'make sense'를 그대로 쓰던 예문 교체 |
| term | 예문 2, 예문 2 번역 | In terms of price, this phone is a good choice.<br>가격 면에서 이 휴대전화는 좋은 선택이다. | I am on good terms with all my neighbors.<br>나는 이웃들 모두와 사이가 좋다. | 숙어 'in terms of' 예문을 '관계' 뜻 예문으로 교체 |
| charge | 예문 1, 예문 1 번역 | Who is in charge of the project?<br>그 프로젝트는 누가 담당하니? | She has charge of the school library.<br>그녀는 학교 도서관을 맡고 있다. | 숙어 'in charge of'를 그대로 쓰던 예문 교체 |
| return | 예문 1, 예문 1 번역 | He helped me, so I helped him in return.<br>그가 나를 도와주어서 나도 보답으로 그를 도왔다. | Farmers get a small return for their hard work.<br>농부들은 고된 노동에 비해 적은 보답을 받는다. | 숙어 'in return'을 그대로 쓰던 예문 교체 |
| effect | 예문 2, 예문 2 번역 | The medicine had no side effects.<br>그 약에는 부작용이 없었다. | The new rule had little effect on students' behavior.<br>새 규칙은 학생들의 행동에 별 영향을 주지 못했다. | 숙어 표제어 'side effects'를 그대로 쓰던 예문 교체 |
| range | 예문 1, 예문 1 번역 | The store sells a wide range of books.<br>그 가게는 다양한 책을 판다. | Children in the age range of six to ten can join.<br>6세에서 10세 연령대의 아이들이 참여할 수 있다. | 숙어 'a range of'와 같은 '다양한' 용법 예문을 '범위' 뜻 예문으로 교체 |
| purpose | 예문 2, 예문 2 번역 | He did not break the cup on purpose.<br>그는 일부러 컵을 깬 것이 아니었다. | What is the purpose of your visit?<br>방문 목적이 무엇입니까? | 숙어 'on purpose'를 그대로 쓰던 예문 교체 |
| pop | 예문 1, 예문 1 번역 | She is one of the most famous pop singers.<br>그녀는 가장 유명한 대중 가수 중 한 명이다. | Pop songs are often about love and friendship.<br>대중가요는 흔히 사랑과 우정을 노래한다. | influential의 예문과 6단어가 겹쳐 교체 |
| stick | 예문 2, 예문 2 번역 | The car got stuck in the deep snow.<br>차가 깊은 눈 속에 꼼짝없이 갇혔다. | Wet sand sticks to your feet at the beach.<br>해변에서는 젖은 모래가 발에 달라붙는다. | mud의 예문과 겹치고 '꼼짝 못 하다'라는 다른 뜻이던 예문을 '달라붙다' 예문으로 교체 |
| medicine | 예문 2, 예문 2 번역 | Keep all medicine away from children.<br>모든 약은 아이들이 닿지 않는 곳에 두어라. | The doctor gave me some medicine for my cough.<br>의사가 기침약을 지어 주었다. | reach 예문(약을 아이 손이 닿지 않게)과 내용이 겹치고, 새 예문도 side effects 예문과 겹치지 않게 교체 |
| regard | 예문 2, 예문 2 번역 | With regard to your question, I will answer later.<br>네 질문에 관해서는 나중에 답하겠다. | The decision was made without regard for safety.<br>그 결정은 안전을 고려하지 않고 내려졌다. | 숙어 'in respect to' 예문과 6단어가 겹쳐 교체 |
| absolutely | 예문 2, 예문 2 번역 | The view from the top was absolutely beautiful.<br>정상에서 본 경치는 정말 아름다웠다. | I absolutely love this song.<br>나는 이 노래가 정말 좋다. | marvelous의 예문과 6단어가 겹쳐 교체 |
| variety | 예문 1, 예문 1 번역 | The shop sells a variety of fruits.<br>그 가게는 다양한 과일을 판다. | We changed the lunch menu for variety.<br>우리는 변화를 주려고 점심 메뉴를 바꾸었다. | 숙어 'a variety of'의 예문('다양한 과일을 판다')과 거의 같아 교체 |
| contrast | 예문 2, 예문 2 번역 | In contrast to her brother, she is very quiet.<br>남동생과 대조적으로 그녀는 매우 조용하다. | The white snow made a beautiful contrast with the blue sky.<br>하얀 눈이 파란 하늘과 아름다운 대조를 이루었다. | 숙어 'in contrast'를 그대로 쓰던 예문 교체 |
| roughly | 예문 1, 예문 1 번역 | Roughly half of the students walk to school.<br>학생의 대략 절반이 걸어서 학교에 간다. | Roughly thirty people came to the meeting.<br>대략 서른 명이 회의에 왔다. | quarter 예문과 6단어가 겹쳐 교체 |
| wherever | 예문 2, 예문 2 번역 | You can sit wherever you like.<br>원하는 곳 어디에든 앉아도 된다. | Wherever you live, you can learn online.<br>어디에 살든 온라인으로 배울 수 있다. | anywhere 예문('원하는 곳 어디에든 앉아도 된다')과 거의 같아 교체 |
| attraction | 예문 1, 예문 1 번역 | I do not understand the attraction of horror movies.<br>나는 공포 영화의 매력을 이해하지 못한다. | The attraction of city life is hard to resist.<br>도시 생활의 매력은 거부하기 어렵다. | appeal 예문('공포 영화의 매력을 이해하지 못한다')과 거의 같아 교체 |
| strict | 예문 2, 예문 2 번역 | The school has strict rules on phones.<br>그 학교는 휴대전화에 관해 엄격한 규칙이 있다. | The library has strict rules about noise.<br>그 도서관은 소음에 관한 규칙이 엄격하다. | policy 예문('휴대전화에 관한 엄격한 방침')과 내용이 겹쳐 교체 |
| accomplish | 예문 2, 예문 2 번역 | She accomplished her goal of running a marathon.<br>그녀는 마라톤을 완주하겠다는 목표를 이루었다. | The team accomplished the task in half the time.<br>그 팀은 절반의 시간 만에 과제를 완수했다. | achieve 예문('마라톤 완주 목표')과 6단어가 겹쳐 교체 |
| creativity | 예문 2, 예문 2 번역 | The job requires a lot of creativity.<br>그 일에는 많은 창의성이 필요하다. | Children show great creativity when they play.<br>아이들은 놀 때 대단한 창의력을 보여 준다. | physical 예문과 6단어가 겹쳐 교체 |
| grasp | 예문 2, 예문 2 번역 | It took me a while to grasp the main idea.<br>요점을 이해하는 데 시간이 좀 걸렸다. | Some students could not grasp the main idea.<br>몇몇 학생은 요점을 이해하지 못했다. | digest 예문과 6단어가 겹쳐 교체 |
| needle | 예문 1, 예문 1 번역 | She sewed the button with a needle and thread.<br>그녀는 바늘과 실로 단추를 달았다. | Can you put the thread through the needle for me?<br>바늘에 실을 꿰어 줄 수 있니? | thread 예문('흰 실로 단추를 달았다')과 거의 같아 교체 |
| nonetheless | 예문 1, 예문 1 번역 | The task was hard; nonetheless, she did not give up.<br>그 일은 어려웠지만 그녀는 그래도 포기하지 않았다. | The road was icy. Nonetheless, the bus arrived on time.<br>길이 얼어 있었다. 그렇더라도 버스는 제시간에 도착했다. | nevertheless 예문('일은 어려웠지만 끝냈다')과 구조·내용이 같아 교체 |
| absurd | 예문 2, 예문 2 번역 | The price of the ticket was absurd.<br>그 표 가격은 말도 안 됐다. | The idea sounded absurd at first, but it worked.<br>그 생각은 처음엔 터무니없게 들렸지만 효과가 있었다. | outrageous 예문('표 가격이 ~했다')과 6단어가 겹쳐 교체 |
| deprive | 예문 1, 예문 1 번역 | The noise deprived me of sleep.<br>그 소음 때문에 나는 잠을 못 잤다. | The war deprived millions of people of their homes.<br>전쟁은 수백만 명에게서 집을 빼앗았다. | rob 예문('소음 때문에 잠을 설쳤다')과 내용이 같아 교체 |
| relieve | 예문 2, 예문 2 번역 | I was relieved to hear that you were safe.<br>네가 무사하다는 소식을 듣고 안심했다. | Talking to a friend can relieve your worries.<br>친구와 이야기하면 걱정을 덜 수 있다. | 형용사 relieved 예문과 6단어가 같은 예문이라 동사 용법으로 교체 |
| harmless | 예문 2, 예문 2 번역 | It was just a harmless joke.<br>그것은 그저 악의 없는 농담이었다. | Do not worry; the medicine is harmless to children.<br>걱정하지 마라. 그 약은 아이들에게 해롭지 않다. | merely 예문('그저 농담이었다')과 거의 같아 교체 |
| tendency | 예문 2, 예문 2 번역 | There is a growing tendency to shop online.<br>온라인으로 쇼핑하는 경향이 커지고 있다. | People have a natural tendency to avoid risk.<br>사람에게는 위험을 피하려는 본능적인 경향이 있다. | trend 예문('~로 가는 경향이 커지고 있다')과 거의 같아 교체 |
| rigid | 예문 2, 예문 2 번역 | The school has rigid rules about uniforms.<br>그 학교는 교복에 대해 엄격한 규칙이 있다. | He is too rigid to accept new ideas.<br>그는 너무 융통성이 없어서 새로운 생각을 받아들이지 못한다. | policy·code 예문과 같은 '학교 규칙' 소재라 교체 |
| exhaustion | 예문 1, 예문 1 번역 | The runner collapsed from exhaustion.<br>그 주자는 극도의 피로로 쓰러졌다. | After the long climb, we were close to exhaustion.<br>긴 등반 끝에 우리는 녹초가 되기 직전이었다. | collapse 예문('주자가 쓰러졌다')과 거의 같아 교체 |
| accustomed | 예문 1, 예문 1 번역 | I am not accustomed to getting up so early.<br>나는 그렇게 일찍 일어나는 데 익숙하지 않다. | Farm animals are accustomed to people.<br>농장 동물들은 사람에게 익숙하다. | used 예문('일찍 일어나는 데 익숙하다')과 거의 같아 교체 |
| showy | 예문 1, 예문 1 번역 | The bird has showy red feathers.<br>그 새는 화려한 빨간 깃털을 가지고 있다. | She wore a showy hat with big flowers.<br>그녀는 큰 꽃이 달린 화려한 모자를 썼다. | distinctive 예문('그 새는 빨간 깃털이 있다')과 거의 같아 교체 |
| quarrel | 예문 2, 예문 2 번역 | The quarrel ended when their mother came in.<br>엄마가 들어오시자 말다툼이 끝났다. | A small quarrel can ruin a friendship.<br>사소한 다툼이 우정을 망칠 수 있다. | argument 예문('선생님이 들어오시자 말다툼이 끝났다')과 거의 같아 교체 |
| terrify | 예문 1, 예문 1 번역 | The thunder terrified the little dog.<br>천둥소리가 작은 개를 몹시 겁먹게 했다. | The horror movie terrified my little brother.<br>그 공포 영화는 내 남동생을 몹시 겁에 질리게 했다. | scare 예문('천둥소리가 아이들을 겁먹게 했다')과 거의 같아 교체 |
| lethally | 예문 1, 예문 1 번역 | Some mushrooms are lethally poisonous.<br>어떤 버섯은 치명적인 독이 있다. | Some snakes are lethally poisonous.<br>어떤 뱀은 치명적인 독을 지니고 있다. | poisonous 예문('어떤 버섯은 독이 있다')과 거의 같아 교체 |
| rent | 예문 2, 예문 2 번역 | They pay their rent at the end of each month.<br>그들은 매달 말에 집세를 낸다. | We pay the rent on the first day of every month.<br>우리는 매달 1일에 집세를 낸다. | salary 예문('매달 말에')과 6단어가 겹쳐 교체 |
| widen | 예문 2, 예문 2 번역 | The gap between rich and poor has widened.<br>빈부 격차가 커졌다. | The river widens as it gets closer to the sea.<br>강은 바다에 가까워질수록 넓어진다. | gap 예문('빈부 격차')과 6단어가 겹쳐 교체 |

## 뜻이 비슷한 단어의 같은 설명 구분 (29)

유의어끼리 설명이 글자까지 같아 차이를 알 수 없던 것을 고쳤어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| permit | 설명 | 무엇을 해도 된다고 할 때 써요. | 규칙이나 법이 공식적으로 허락할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| complex | 설명 | 여러 부분이 얽혀 이해하기 어려운 것이에요. | 여러 부분이 맞물려 구조가 복잡한 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| complicated | 설명 | 여러 부분이 얽혀 이해하기 어려운 것이에요. | 얽혀서 이해하거나 다루기 까다로운 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| transport | 설명 | 사람이나 물건을 다른 곳으로 옮길 때 써요. | 차량 등으로 사람·물건을 실어 나를 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| mixture | 설명 | 여러 가지가 섞인 것이에요. | 여러 재료가 섞여 만들어진 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| mix | 설명 | 여러 가지가 섞인 것이에요. | 여러 가지가 한데 어우러진 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| severe | 설명 | 아주 나쁘거나 정도가 심한 것이에요. | 병이나 피해가 매우 심각한 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| in place of | 설명 | 원래 것을 다른 것으로 바꿀 때 써요. | 원래 것 자리에 다른 것을 쓸 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| objective | 설명 | 이루려고 하는 것이에요. | 계획이나 활동이 이루려는 구체적 목표예요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| rage | 설명 | 몹시 화가 난 감정이에요. | 참을 수 없을 만큼 격한 분노예요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| relieve | 설명 | 고통이나 걱정을 줄여 줄 때 써요. | 아픔이나 부담을 덜어 한결 낫게 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| frighten | 설명 | 무섭게 해서 놀라게 할 때 써요. | 갑자기 겁에 질리게 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| considering | 설명 | 어떤 사실을 생각해 볼 때를 나타내요. | 어떤 점을 따져 보면 ~라고 말할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| given | 설명 | 어떤 사실을 생각해 볼 때를 나타내요. | 주어진 사정을 감안할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| immediately | 설명 | 기다리지 않고 바로를 뜻해요. | 시간을 끌지 않고 곧바로 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| right away | 설명 | 기다리지 않고 바로를 뜻해요. | 말이 끝나자마자 지금 당장 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| wherever | 설명 | 어떤 장소든 상관없음을 나타내요. | 가는 곳이 어디든 상관없을 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| concerning | 설명 | 어떤 주제에 대해 말할 때 써요. | 어떤 일과 관련된 내용을 말할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| when it comes to | 설명 | 어떤 주제에 대해 말할 때 써요. | 어떤 분야라면 ~라고 말할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| in addition | 설명 | 앞 내용에 더할 때 써요. | 앞의 내용에 다른 사실을 덧붙일 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| necessity | 설명 | 꼭 있어야 하는 것이에요. | 살아가는 데 꼭 필요한 것이에요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| merchandise | 설명 | 사고파는 물건이에요. | 가게에서 파는 물품 전체를 말해요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| prohibit | 설명 | 법이나 규칙으로 못 하게 할 때 써요. | 법으로 공식적으로 금지할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| optimal | 설명 | 가장 알맞고 좋은 것이에요. | 조건이 가장 알맞은 상태예요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| absent | 설명 | 있어야 할 곳에 없는 것이에요. | 학교나 모임에 나오지 않은 상태예요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| motivate | 설명 | 하고 싶은 마음이 들게 할 때 써요. | 무엇을 할 의욕이 생기게 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| tempt | 설명 | 하고 싶은 마음이 들게 할 때 써요. | 하면 안 될 일을 하고 싶게 할 때 써요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| consequently | 설명 | 앞의 일 때문에 생긴 결과를 말할 때 써요. | 앞 일의 결과로 이어지는 내용을 말해요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |
| a variety of | 설명 | 여러 종류를 말할 때 써요. | 종류가 서로 다른 여러 가지를 말해요. | 뜻이 비슷한 단어와 설명이 똑같아 차이가 드러나게 고침 |

## 같은 품사의 같은 대표 뜻 구분 (289)

철자 문제는 뜻과 품사만 보여 주기 때문에, 같은 품사의 대표 뜻이 같으면 정답이 둘이 되어요. 동음이의어(구조·성인·부족·입장·시인 등)는 다른 낱말로 바꾸고, 유의어는 순서를 바꾸거나 쓰임을 괄호로 밝혀 구분했어요.

| 단어 | 이전 뜻 | 바꾼 뜻 | 이유 |
| --- | --- | --- | --- |
| fabric | 구조; 기본 틀 | (사회의) 구조; 기본 틀 | 동음이의 구분 |
| saint | 성인; 성자 | 성자; 성인(聖人) | 동음이의 구분 |
| tribe | 부족; 종족 | 종족; 부족(部族) | 동음이의 구분 |
| admission | 입장; 입학 | 입장 허가; 입학 | 동음이의 구분 |
| admission | 인정; 시인 | 자백; 시인 | 동음이의 구분 |
| version | 판; 형태 | (변형된) 판; 버전 | 동음이의 구분 |
| union | 조합; 연합 | 노동조합; 연합 | 동음이의 구분 |
| generation | 발생; 생성 | 생성; 발생 | 동음이의 구분 |
| filter | 거르다; 여과하다 | 여과하다; 거르다 | 동음이의 구분 |
| skip | 거르다; 건너뛰다 | 건너뛰다; 거르다 | 동음이의 구분 |
| attract | 끌다; 끌어들이다 | 끌어들이다; 끌다 | 동음이의 구분 |
| host | 주인; 진행자 | (손님을 맞는) 주인; 진행자 | 동음이의 구분 |
| identify | 확인하다; 알아보다 | 찾아내다; 확인하다 | 유의어 뜻 구분 |
| attend | 처리하다; 돌보다 | 보살피다; 처리하다 | 유의어 뜻 구분 |
| means | 재산; 수입 | 재력; 수입 | 동음이의 구분 |
| remains | 나머지; 남은 것 | 남은 것; 나머지 | 동음이의 구분 |
| still | 그럼에도 불구하고 | 그래도; 그럼에도 | 유의어 뜻 구분 |
| nonetheless | 그럼에도 불구하고 | 그렇더라도; 그럼에도 불구하고 | 유의어 뜻 구분 |
| persist | 지속되다; 고집하다 | 끈질기게 계속되다; 고집하다 | 유의어 뜻 구분 |
| part | 역할; 몫 | (맡은) 역할; 몫 | 유의어 뜻 구분 |
| switch | 바꾸다; 전환하다 | 전환하다; 바꾸다 | 유의어 뜻 구분 |
| alter | 바꾸다; 고치다 | 고치다; 바꾸다 | 유의어 뜻 구분 |
| convert | 바꾸다; 개조하다 | 개조하다; 전환하다 | 유의어 뜻 구분 |
| head | 우두머리; 책임자 | 책임자; 우두머리 | 유의어 뜻 구분 |
| command | 명령; 지휘 | 지휘; 명령 | 유의어 뜻 구분 |
| run | 작동하다; 운행하다 | 운행하다; 작동하다 | 유의어 뜻 구분 |
| operate | 작동하다; 운영하다 | (기계를) 작동하다; 운영하다 | 유의어 뜻 구분 |
| issue | 문제; 쟁점 | 쟁점; 문제 | 유의어 뜻 구분 |
| matter | 물질 | (물리적) 물질 | 유의어 뜻 구분 |
| substance | 물질 | (특정한) 물질 | 유의어 뜻 구분 |
| touch | 감동시키다 | (마음을) 움직이다; 감동시키다 | 유의어 뜻 구분 |
| measure | 조치; 대책 | 대책; 조치 | 유의어 뜻 구분 |
| request | 요청하다 | (정식으로) 요청하다 | 유의어 뜻 구분 |
| fairly | 꽤; 상당히 | 어느 정도; 꽤 | 유의어 뜻 구분 |
| absolutely | 완전히; 절대적으로 | 절대적으로; 완전히 | 유의어 뜻 구분 |
| chief | 주요한; 최고의 | 최고의; 주요한 | 유의어 뜻 구분 |
| present | 현재의; 참석한 | 참석한; 현재의 | 유의어 뜻 구분 |
| opportunity | 기회 | (좋은) 기회 | 유의어 뜻 구분 |
| likelihood | 가능성 | (일어날) 가능성 | 유의어 뜻 구분 |
| accident | 우연 | (by accident) 우연 | 유의어 뜻 구분 |
| expense | 비용; 지출 | (드는) 비용; 지출 | 유의어 뜻 구분 |
| instant | 순간 | 찰나; 순간 | 유의어 뜻 구분 |
| strength | 힘; 체력 | 체력; 힘 | 유의어 뜻 구분 |
| troop | 군대; 무리 | (troops) 병력; 무리 | 유의어 뜻 구분 |
| account | 설명; 이야기 | 이야기; 설명 | 유의어 뜻 구분 |
| contain | 포함하다; 들어 있다 | 들어 있다; 포함하다 | 유의어 뜻 구분 |
| involve | 포함하다; 수반하다 | 수반하다; 포함하다 | 유의어 뜻 구분 |
| document | 기록하다 | (문서로) 기록하다 | 유의어 뜻 구분 |
| share | 나누다; 공유하다 | 공유하다; 나누다 | 유의어 뜻 구분 |
| regard | 여기다; 간주하다 | 간주하다; 여기다 | 유의어 뜻 구분 |
| worth | 가치 | (진정한) 가치; ~어치 | 유의어 뜻 구분 |
| cherish | 소중히 여기다 | 아끼다; 소중히 간직하다 | 유의어 뜻 구분 |
| proof | 증거; 증명 | 증명; 증거 | 유의어 뜻 구분 |
| proportion | 비율; 부분 | (전체 중) 비율; 부분 | 유의어 뜻 구분 |
| proportion | 균형; 조화 | 조화; 균형 | 유의어 뜻 구분 |
| rate | 평가하다 | (등급·점수로) 평가하다 | 유의어 뜻 구분 |
| assess | 평가하다 | (가치·상황을) 판단하다; 평가하다 | 유의어 뜻 구분 |
| put up with | 참다; 견디다 | (불쾌한 것을) 참고 견디다 | 유의어 뜻 구분 |
| position | 입장; 처지 | 처지; 입장 | 유의어 뜻 구분 |
| quantity | 양; 수량 | 수량; 양 | 유의어 뜻 구분 |
| drive | 욕구; 추진력 | 의욕; 욕구 | 유의어 뜻 구분 |
| exchange | 교환하다; 주고받다 | 주고받다; 교환하다 | 유의어 뜻 구분 |
| hatred | 증오; 혐오 | (깊은) 증오; 혐오 | 유의어 뜻 구분 |
| fortune | 재산; 큰돈 | 큰돈; 재산 | 유의어 뜻 구분 |
| item | 물품; 항목 | 항목; 물품 | 유의어 뜻 구분 |
| code | 규칙; 규범 | 규범; 규정 | 유의어 뜻 구분 |
| staff | 직원; 사원 | 직원들; 직원진 | 유의어 뜻 구분 |
| profession | 직업; 전문직 | 전문직; 직업 | 유의어 뜻 구분 |
| loss | 패배 | (경기에서) 짐; 패배 | 유의어 뜻 구분 |
| offer | 제안하다; 제공하다 | (하겠다고) 제의하다; 제공하다 | 유의어 뜻 구분 |
| offer | 제안; 제의 | 제의; 제안 | 유의어 뜻 구분 |
| misery | 고통; 비참함 | 비참함; 고통 | 유의어 뜻 구분 |
| admire | 존경하다; 감탄하다 | 감탄하다; 존경하다 | 유의어 뜻 구분 |
| respect | 측면; 점 | (어떤) 점; 측면 | 유의어 뜻 구분 |
| fee | 요금; 수수료 | 수수료; 요금 | 유의어 뜻 구분 |
| charge | 책임; 담당 | 담당; 책임 | 유의어 뜻 구분 |
| blame | 책임; 비난 | 비난; 책임 | 유의어 뜻 구분 |
| effect | 영향; 효과 | 효과; 영향 | 유의어 뜻 구분 |
| permit | 허락하다; 허용하다 | (공식적으로) 허가하다; 허락하다 | 유의어 뜻 구분 |
| allow | 가능하게 하다 | ~할 수 있게 하다; 가능하게 하다 | 유의어 뜻 구분 |
| focus | 집중하다 | 초점을 맞추다; 집중하다 | 유의어 뜻 구분 |
| former | 이전의; 전(前)~ | 전(前)~; 이전의 | 유의어 뜻 구분 |
| prior | 이전의; 사전의 | 사전의; 이전의 | 유의어 뜻 구분 |
| reach | 연락하다 | (연락이) 닿다; 연락하다 | 유의어 뜻 구분 |
| drop | 감소; 방울 | 하락; 방울 | 유의어 뜻 구분 |
| drop | 그만두다; 내려 주다 | (수강 등을) 그만두다; 내려 주다 | 유의어 뜻 구분 |
| decline | 감소; 쇠퇴 | 쇠퇴; 감소 | 유의어 뜻 구분 |
| reduction | 감소; 할인 | 축소; 감소 | 유의어 뜻 구분 |
| link | 연결하다; 관련짓다 | 관련짓다; 연결하다 | 유의어 뜻 구분 |
| seek | 찾다; 구하다 | 구하다; 찾다 | 유의어 뜻 구분 |
| claim | 주장하다 | (사실이라고) 주장하다 | 유의어 뜻 구분 |
| maintain | 주장하다 | (계속) 주장하다; 고수하다 | 유의어 뜻 구분 |
| argue | 주장하다; 논하다 | 논하다; 주장하다 | 유의어 뜻 구분 |
| insist | 주장하다; 고집하다 | 고집하다; (강하게) 주장하다 | 유의어 뜻 구분 |
| argument | 주장; 논거 | 논거; 주장 | 유의어 뜻 구분 |
| secretary | 장관 | (미국의) 장관 | 유의어 뜻 구분 |
| abundant | 풍부한 | (양이) 아주 많은; 풍부한 | 유의어 뜻 구분 |
| impair | 손상시키다; 약화시키다 | (기능을) 떨어뜨리다; 손상시키다 | 유의어 뜻 구분 |
| spot | 발견하다; 알아채다 | 알아채다; 발견하다 | 유의어 뜻 구분 |
| detect | 발견하다; 감지하다 | 탐지하다; 발견하다 | 유의어 뜻 구분 |
| tip | 조언; 비결 | 요령; 조언 | 유의어 뜻 구분 |
| comment | 언급하다; 논평하다 | 논평하다; 언급하다 | 유의어 뜻 구분 |
| refer | 언급하다; 가리키다 | 지칭하다; 언급하다 | 유의어 뜻 구분 |
| object | 목적; 목표 | (이루려는) 목적 | 유의어 뜻 구분 |
| objective | 목표; 목적 | (달성할) 목표; 목적 | 유의어 뜻 구분 |
| complicated | 복잡한 | (얽혀서) 복잡한; 까다로운 | 유의어 뜻 구분 |
| admit | 인정하다; 자백하다 | (잘못을) 인정하다; 시인하다 | 유의어 뜻 구분 |
| recognize | 인정하다 | (공식적으로) 인정하다 | 유의어 뜻 구분 |
| emerge | 나타나다; 드러나다 | 드러나다; 나타나다 | 유의어 뜻 구분 |
| characteristic | 특징; 특성 | 특성; 특징 | 유의어 뜻 구분 |
| finance | 자금을 대다 | (돈을) 조달하다; 자금을 대다 | 유의어 뜻 구분 |
| fix | 해결책 | (간단한) 해결 방법; 임시방편 | 유의어 뜻 구분 |
| shy | 꺼리는; 조심하는 | 조심하는; 꺼리는 | 유의어 뜻 구분 |
| unwilling | 꺼리는; 마지못한 | ~할 마음이 없는; 꺼리는 | 유의어 뜻 구분 |
| earn | 얻다; 받을 만하다 | (노력으로) 얻다; 받을 만하다 | 유의어 뜻 구분 |
| obtain | 얻다; 획득하다 | 획득하다; 얻다 | 유의어 뜻 구분 |
| acquire | 얻다; 습득하다 | 습득하다; 얻다 | 유의어 뜻 구분 |
| boost | 증가; 격려 | 활력; 증가 | 유의어 뜻 구분 |
| feed | 공급하다; 제공하다 | (계속) 대 주다; 공급하다 | 유의어 뜻 구분 |
| correct | 정확한; 옳은 | 옳은; 정확한 | 유의어 뜻 구분 |
| precise | 정확한; 정밀한 | 정밀한; 정확한 | 유의어 뜻 구분 |
| firm | 단단한; 확고한 | 확고한; 단단한 | 유의어 뜻 구분 |
| enhance | 향상시키다; 높이다 | (질·가치를) 높이다; 향상시키다 | 유의어 뜻 구분 |
| impact | 영향을 주다 | (큰) 영향을 미치다; 충격을 주다 | 유의어 뜻 구분 |
| notion | 개념; 생각 | 생각; 개념 | 유의어 뜻 구분 |
| glue | 붙이다 | (풀로) 붙이다 | 유의어 뜻 구분 |
| attach | 붙이다; 첨부하다 | 첨부하다; 붙이다 | 유의어 뜻 구분 |
| nurture | 기르다; 육성하다 | 양육하다; 육성하다 | 유의어 뜻 구분 |
| pose | (문제를) 제기하다; 일으키다 | (위험·문제를) 일으키다; 제기하다 | 유의어 뜻 구분 |
| imply | 암시하다; 넌지시 말하다 | 넌지시 말하다; 암시하다 | 유의어 뜻 구분 |
| cure | 치료하다; 고치다 | (병을) 낫게 하다; 고치다 | 유의어 뜻 구분 |
| presence | 존재; 참석 | (어떤 곳에) 있음; 참석 | 유의어 뜻 구분 |
| highlight | 강조하다; 형광펜으로 표시하다 | 부각하다; 강조하다 | 유의어 뜻 구분 |
| emphasize | 강조하다 | 힘주어 말하다; 강조하다 | 유의어 뜻 구분 |
| proper | 적절한; 제대로 된 | 제대로 된; 적절한 | 유의어 뜻 구분 |
| shift | 옮기다; 바뀌다 | 바뀌다; 옮기다 | 유의어 뜻 구분 |
| migration | 이동; 이주 | 이주; 이동 | 유의어 뜻 구분 |
| awful | 끔찍한; 지독한 | 지독한; 끔찍한 | 유의어 뜻 구분 |
| limitation | 한계; 제한 | 한계점; 제약 | 유의어 뜻 구분 |
| restrict | 제한하다 | 제약하다; 제한하다 | 유의어 뜻 구분 |
| survey | 조사하다; 둘러보다 | (설문으로) 조사하다; 둘러보다 | 유의어 뜻 구분 |
| appeal | 매력 | 호감; 매력 | 유의어 뜻 구분 |
| attraction | 매력; 끌림 | 끌림; 매력 | 유의어 뜻 구분 |
| inner | 내부의; 마음속의 | 마음속의; 내부의 | 유의어 뜻 구분 |
| conduct | 수행하다; 실시하다 | 실시하다; 수행하다 | 유의어 뜻 구분 |
| perform | 수행하다; 해내다 | 해내다; 수행하다 | 유의어 뜻 구분 |
| apparent | 명백한; 겉보기의 | 분명해 보이는; 겉보기의 | 유의어 뜻 구분 |
| tie | 유대; 관계 | 관계; 유대 | 유의어 뜻 구분 |
| enroll | 등록하다; 입학하다 | (학교·강좌에) 등록하다; 입학하다 | 유의어 뜻 구분 |
| replace | 대신하다; 교체하다 | 교체하다; 대신하다 | 유의어 뜻 구분 |
| accomplish | 성취하다; 완수하다 | 완수하다; 성취하다 | 유의어 뜻 구분 |
| suppose | 가정하다; 생각하다 | 생각하다; 가정하다 | 유의어 뜻 구분 |
| ruin | 망치다; 파괴하다 | 파괴하다; 망치다 | 유의어 뜻 구분 |
| shift | 변화; 전환 | 전환; 변화 | 유의어 뜻 구분 |
| transformation | 변화; 변신 | (완전한) 변화; 변신 | 유의어 뜻 구분 |
| excuse | 용서하다; 면제하다 | 너그러이 봐주다; 면제하다 | 유의어 뜻 구분 |
| professional | 전문가; 직업인 | 전문직 종사자; 프로 | 유의어 뜻 구분 |
| object | 반대하다 | 이의를 제기하다; 반대하다 | 유의어 뜻 구분 |
| foster | 촉진하다; 기르다 | 북돋우다; 촉진하다 | 유의어 뜻 구분 |
| outstanding | 뛰어난; 두드러진 | 두드러진; 뛰어난 | 유의어 뜻 구분 |
| accomplished | 뛰어난; 숙달된 | 숙달된; 뛰어난 | 유의어 뜻 구분 |
| crash | 충돌; 추락 | 추락; 충돌 | 유의어 뜻 구분 |
| arrange | 준비하다; 정하다 | 마련하다; 정하다 | 유의어 뜻 구분 |
| capture | 붙잡다; 포착하다 | 포획하다; 포착하다 | 유의어 뜻 구분 |
| instant | 즉각적인; 즉석의 | 즉석의; 즉각적인 | 유의어 뜻 구분 |
| prompt | 즉각적인; 신속한 | 신속한; 즉각적인 | 유의어 뜻 구분 |
| shade | 색조; 음영 | 음영; 색조 | 유의어 뜻 구분 |
| quarrel | 말다툼하다 | (사소한 일로) 다투다 | 유의어 뜻 구분 |
| quarrel | 말다툼 | (사소한) 다툼 | 유의어 뜻 구분 |
| gear | 장비; 용품 | 용품; 장비 | 유의어 뜻 구분 |
| ensure | 보장하다; 확실히 하다 | 확실히 하다; 보장하다 | 유의어 뜻 구분 |
| plain | 평범한; 수수한 | 수수한; 평범한 | 유의어 뜻 구분 |
| soil | 흙; 토양 | 토양; 흙 | 유의어 뜻 구분 |
| desert | 버리다; 떠나다 | 떠나다; 버리다 | 유의어 뜻 구분 |
| discard | 버리다; 폐기하다 | 폐기하다; 버리다 | 유의어 뜻 구분 |
| reject | 거절하다; 거부하다 | 거부하다; 거절하다 | 유의어 뜻 구분 |
| decline | 거절하다 | (정중히) 거절하다 | 유의어 뜻 구분 |
| resolve | 해결하다 | (문제를) 풀다; 해결하다 | 유의어 뜻 구분 |
| relax | 완화하다 | (규칙을) 완화하다 | 유의어 뜻 구분 |
| fake | ~인 척하다; 위조하다 | 위조하다; ~인 척하다 | 유의어 뜻 구분 |
| regain | 되찾다; 회복하다 | (잃은 것을) 다시 얻다; 되찾다 | 유의어 뜻 구분 |
| depend | 의지하다; ~에 달려 있다 | (상황에) 달려 있다; 좌우되다 | 숙어 depend on과 뜻 구분 |
| convince | 설득하다; 확신시키다 | 확신시키다; 설득하다 | 유의어 뜻 구분 |
| gigantic | 거대한 | 엄청나게 큰; 거대한 | 유의어 뜻 구분 |
| vary | 다르다; 다양하다 | 다양하다; 다르다 | 유의어 뜻 구분 |
| furthermore | 게다가; 더욱이 | 더욱이; 게다가 | 유의어 뜻 구분 |
| notify | 알리다; 통지하다 | (공식적으로) 통지하다; 알리다 | 유의어 뜻 구분 |
| embrace | 껴안다; 받아들이다 | (기꺼이) 수용하다; 껴안다 | 유의어 뜻 구분 |
| plead | 간청하다; 주장하다 | 애원하다; 주장하다 | 유의어 뜻 구분 |
| polish | 닦다; 다듬다 | 광내다; 다듬다 | 유의어 뜻 구분 |
| expose | 드러내다; 노출시키다 | 노출시키다; 드러내다 | 유의어 뜻 구분 |
| tense | 긴장한; 팽팽한 | 팽팽한; 긴장된 | 유의어 뜻 구분 |
| decent | 예의 바른; 착한 | 점잖은; 예의 바른 | 유의어 뜻 구분 |
| glue | 접착제; 풀 | 풀; 접착제 | 유의어 뜻 구분 |
| interrupt | 방해하다; 끼어들다 | 끼어들다; 방해하다 | 유의어 뜻 구분 |
| used | 익숙한 | (~에) 익숙한 | 유의어 뜻 구분 |
| accustomed | 익숙한 | 익숙해진; 길든 | 유의어 뜻 구분 |
| given | ~을 고려하면 | ~을 감안하면; ~을 고려하면 | 유의어 뜻 구분 |
| security | 안전; 보안 | 보안; 안전 | 유의어 뜻 구분 |
| formal | 공식적인; 격식을 차린 | 격식을 차린; 공식적인 | 유의어 뜻 구분 |
| insane | 미친; 말도 안 되는 | 제정신이 아닌; 말도 안 되는 | 유의어 뜻 구분 |
| response | 반응; 대답 | 응답; 반응 | 유의어 뜻 구분 |
| instantly | 즉시; 즉각 | 즉각; 순식간에 | 유의어 뜻 구분 |
| capacity | 능력 | 역량; 능력 | 유의어 뜻 구분 |
| ingredient | 재료; 요소 | (음식의) 재료; 구성 요소 | 유의어 뜻 구분 |
| highly | 매우; 높이 | 대단히; 높이 | 유의어 뜻 구분 |
| extremely | 매우; 극도로 | 극도로; 매우 | 유의어 뜻 구분 |
| grasp | 이해; 움켜쥠 | 파악; 움켜쥠 | 유의어 뜻 구분 |
| distinctive | 독특한; 특유의 | 뚜렷이 구별되는; 독특한 | 유의어 뜻 구분 |
| variety | 다양성; 여러 가지 | 여러 가지; 다양성 | 유의어 뜻 구분 |
| classic | 전형적인; 고전적인 | 대표적인; 고전적인 | 유의어 뜻 구분 |
| conduct | 행동; 품행 | 품행; 행동 | 유의어 뜻 구분 |
| concerning | ~에 관하여 | ~와 관련하여; ~에 관하여 | 유의어 뜻 구분 |
| approximately | 대략; 약 | 약; 대략 | 유의어 뜻 구분 |
| merchandise | 상품; 물품 | (판매용) 물품; 상품 | 유의어 뜻 구분 |
| enterprise | 기업; 사업 | 사업; 기업 | 유의어 뜻 구분 |
| significance | 중요성; 의의 | 의의; 중요성 | 유의어 뜻 구분 |
| revolution | 회전; 공전 | 공전; 회전 | 유의어 뜻 구분 |
| prohibit | 금지하다 | (법으로) 금지하다 | 유의어 뜻 구분 |
| forbid | 금지하다 | (하지 못하게) 금하다 | 유의어 뜻 구분 |
| trend | 경향; 유행 | 추세; 유행 | 유의어 뜻 구분 |
| reputation | 명성; 평판 | 평판; 명성 | 유의어 뜻 구분 |
| ridiculous | 터무니없는; 우스꽝스러운 | 우스꽝스러운; 터무니없는 | 유의어 뜻 구분 |
| outrageous | 터무니없는; 충격적인 | 충격적인; 터무니없는 | 유의어 뜻 구분 |
| awareness | 인식; 의식 | 의식; 인식 | 유의어 뜻 구분 |
| heighten | 높이다; 고조시키다 | 고조시키다; 높이다 | 유의어 뜻 구분 |
| accomplishment | 성취; 업적 | 업적; 성취 | 유의어 뜻 구분 |
| extraordinary | 놀라운; 비범한 | 비범한; 놀라운 | 유의어 뜻 구분 |
| remarkable | 놀라운; 주목할 만한 | 주목할 만한; 놀라운 | 유의어 뜻 구분 |
| alarming | 놀라운; 걱정스러운 | 걱정스러운; 놀라운 | 유의어 뜻 구분 |
| marvelous | 놀라운; 훌륭한 | 경이로운; 훌륭한 | 유의어 뜻 구분 |
| residence | 주거; 거주지 | 거주지; 주거 | 유의어 뜻 구분 |
| dwelling | 주거; 거처 | 거처; 주거 | 유의어 뜻 구분 |
| consequence | 결과; 영향 | (좋지 않은) 결과; 영향 | 유의어 뜻 구분 |
| blast | 폭발; 강한 바람 | 강한 바람; 폭발 | 유의어 뜻 구분 |
| enrollment | 등록; 입학 | 입학; 등록 | 유의어 뜻 구분 |
| presentation | 발표; 프레젠테이션 | 프레젠테이션; 발표 | 유의어 뜻 구분 |
| compliment | 칭찬; 찬사 | 찬사; 칭찬 | 유의어 뜻 구분 |
| shed | 헛간; 창고 | 창고; 헛간 | 유의어 뜻 구분 |
| incentive | 동기; 장려책 | 장려책; 동기 | 유의어 뜻 구분 |
| contamination | 오염 | (유해 물질에 의한) 오염 | 유의어 뜻 구분 |
| expedition | 탐험; 원정 | 원정; 탐험 | 유의어 뜻 구분 |
| conserve | 보존하다; 아껴 쓰다 | 아껴 쓰다; 보존하다 | 유의어 뜻 구분 |
| bias | 편견; 편향 | 편향; 편견 | 유의어 뜻 구분 |
| beam | 활짝 웃다 | 환하게 웃다 | 유의어 뜻 구분 |
| gloomy | 우울한; 어두운 | 어두운; 우울한 | 유의어 뜻 구분 |
| grasp | 꽉 잡다; 이해하다 | 파악하다; 꽉 잡다 | 유의어 뜻 구분 |
| modest | 겸손한; 적당한 | 적당한; 겸손한 | 유의어 뜻 구분 |
| enthusiastic | 열정적인; 열렬한 | 열렬한; 열정적인 | 유의어 뜻 구분 |
| breeding | 번식; 사육 | 사육; 번식 | 유의어 뜻 구분 |
| junk | 쓰레기; 잡동사니 | 잡동사니; 쓰레기 | 유의어 뜻 구분 |
| litter | 쓰레기 | (길에 버린) 쓰레기 | 유의어 뜻 구분 |
| prompt | 촉발하다; 유도하다 | 유도하다; 촉발하다 | 유의어 뜻 구분 |
| collaborate | 협력하다; 공동 작업하다 | 공동 작업하다; 협력하다 | 유의어 뜻 구분 |
| dedicate | 바치다; 헌신하다 | 헌신하다; 바치다 | 유의어 뜻 구분 |
| startle | 깜짝 놀라게 하다 | (갑자기) 깜짝 놀라게 하다 | 유의어 뜻 구분 |
| in place of | ~ 대신에 | ~을 대신하여 | 유의어 뜻 구분 |
| a range of | 다양한; 여러 가지의 | 여러 가지의; 다양한 | 유의어 뜻 구분 |
| sorrow | 슬픔; 비애 | 비애; 슬픔 | 유의어 뜻 구분 |
| aroma | 향기; 냄새 | (음식의) 향; 향기 | 유의어 뜻 구분 |
| hurdle | 장애물; 난관 | 난관; 장애물 | 유의어 뜻 구분 |
| annoyance | 짜증; 성가신 것 | 성가심; 짜증 | 유의어 뜻 구분 |
| evaluate | 평가하다 | (꼼꼼히) 평가하다 | 유의어 뜻 구분 |
| outcome | 결과 | (최종) 결과 | 유의어 뜻 구분 |
| hire | 고용하다; 빌리다 | (사람을) 쓰다; 고용하다 | 유의어 뜻 구분 |
| irritated | 짜증 난; 따가운 | 약이 오른; 따가운 | 유의어 뜻 구분 |
| reserve | 예약하다; 따로 남겨 두다 | (자리를) 잡아 두다; 예약하다 | 유의어 뜻 구분 |
| represent | 나타내다; 상징하다 | 상징하다; 나타내다 | 유의어 뜻 구분 |
| distinguish | 구별하다 | 식별하다; 구별하다 | 유의어 뜻 구분 |
| rather | 꽤; 다소 | 다소; 꽤 | 유의어 뜻 구분 |
| chance | 가능성; 확률 | 확률; 가능성 | 유의어 뜻 구분 |
| tale | 이야기; 설화 | 설화; (지어낸) 이야기 | 유의어 뜻 구분 |
| benefit | 이익; 혜택 | 혜택; 이익 | 유의어 뜻 구분 |
| view | 여기다; 보다 | (~으로) 보다; 여기다 | 유의어 뜻 구분 |
| dip | 하락; 감소 | 일시적 하락; 감소 | 유의어 뜻 구분 |
| position | 위치; 자세 | (놓인) 자리; 자세 | 유의어 뜻 구분 |
| assist | 돕다; 보조하다 | 보조하다; 돕다 | 유의어 뜻 구분 |
| impulse | 충동 | (순간적) 충동 | 유의어 뜻 구분 |
| mess | 망치다 | 엉망으로 만들다; 망치다 | 유의어 뜻 구분 |
| reply | 대답하다; 답장하다 | 답장하다; 대답하다 | 유의어 뜻 구분 |
| deny | 거부하다 | 허락하지 않다; 거부하다 | 유의어 뜻 구분 |
| besides | 게다가 | 그 밖에; 게다가 | 유의어 뜻 구분 |
| trait | 특성; 특징 | 특질; 특성 | 유의어 뜻 구분 |
| severe | 심각한; 극심한 | 극심한; 심각한 | 유의어 뜻 구분 |
| suspicious | 의심스러운; 수상한 | 수상한; 의심스러운 | 유의어 뜻 구분 |
| acute | 극심한; 급성의 | 급성의; 극심한 | 유의어 뜻 구분 |
| figure out | 알아내다; 이해하다 | (궁리해서) 알아내다; 이해하다 | 유의어 뜻 구분 |
| rough | 힘든; 거친 | 힘든; (바다가) 사나운 | 같은 단어의 첫 뜻 '거친'과 겹쳐 고침 |
| accept | 인정하다; 받아들이다 | (사실로) 인정하다; 수긍하다 | 같은 단어의 첫 뜻 '받아들이다'와 겹쳐 고침 |

## 어색한 예문 교체 (12)

영어가 어색하거나, 뜻과 맞지 않거나, 단어장에 맞지 않는 소재의 예문을 바꿨어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| scare | 예문 2, 예문 2 번역 | My little brother is scared of the dark.<br>내 남동생은 어둠을 무서워한다. | The sudden noise scared the birds away.<br>갑작스러운 소리에 새들이 놀라 달아났다. | 형용사 scared 예문과 겹쳐 동사 용법 예문으로 교체 |
| disappoint | 예문 1, 예문 1 번역 | I was disappointed with the ending of the movie.<br>나는 그 영화의 결말에 실망했다. | The team's poor performance disappointed the fans.<br>팀의 형편없는 경기력은 팬들을 실망시켰다. | 형용사 disappointed 예문과 겹쳐 동사 용법 예문으로 교체 |
| mention | 예문 2, 예문 2 번역 | The book is cheap, not to mention useful.<br>그 책은 유용한 것은 말할 것도 없고 값도 싸다. | The hotel has a beautiful garden, not to mention a pool.<br>그 호텔에는 수영장은 말할 것도 없고 아름다운 정원도 있다. | 'cheap, not to mention useful'은 어순이 어색하고 번역과도 맞지 않아 교체 |
| mate | 예문 2, 예문 2 번역 | He shares a room with his team mate.<br>그는 팀 동료와 방을 함께 쓴다. | He shares a room with a mate from work.<br>그는 직장 동료와 방을 함께 쓴다. | 'team mate'는 한 단어(teammate)로 써야 해서 예문을 교체 |
| complicated | 예문 2, 예문 2 번역 | It is a complicated situation.<br>그것은 복잡한 상황이다. | The situation became more complicated after the storm.<br>폭풍이 지나간 뒤 상황은 더 복잡해졌다. | 'It is a complicated situation.'은 맥락이 없어 뜻이 드러나는 예문으로 교체 |
| capture | 예문 1, 예문 1 번역 | The police captured the thief.<br>경찰은 도둑을 붙잡았다. | Scientists captured the bird to study it.<br>과학자들은 연구하려고 그 새를 포획했다. | '포획하다' 뜻에 맞지 않는 '도둑을 붙잡다' 예문 교체 |
| equip | 예문 2 | School should equip students with life skills. | Schools should equip students with life skills. | 관사 없는 'School should'를 'Schools should'로 고침 |
| vocation | 예문 2, 예문 2 번역 | The school offers vocation training for young adults.<br>그 학교는 청년들에게 직업 훈련을 제공한다. | He left his office job to follow his vocation as a painter.<br>그는 화가라는 천직을 따르려고 사무직을 그만두었다. | 'vocation training'은 'vocational training'이 맞아 예문을 교체 |
| vice versa | 예문 1, 예문 1 번역 | Cats chase dogs, and vice versa.<br>고양이가 개를 쫓기도 하고 그 반대도 마찬가지이다. | Parents learn from their children, and vice versa.<br>부모는 자녀에게서 배우고, 그 반대도 마찬가지이다. | '고양이가 개를 쫓는다'는 어색한 내용이라 교체 |
| up to | 예문 2, 예문 2 번역 | Whether we go or not is up to the weather.<br>우리가 갈지 말지는 날씨에 달려 있다. | The final decision is up to the principal.<br>최종 결정은 교장 선생님께 달려 있다. | 'up to the weather'는 사람의 결정을 말하는 용법과 맞지 않아 교체 |
| messy | 예문 2, 예문 2 번역 | The divorce was long and messy.<br>그 이혼은 길고 복잡했다. | Painting with young children can get messy.<br>어린아이들과 그림을 그리면 엉망이 되기 쉽다. | 고등학생 단어장에 맞지 않는 '이혼' 소재 예문 교체 |
| fictional | 예문 1, 예문 1 번역 | Harry is a fictional character from a famous book.<br>해리는 유명한 책 속의 가상 인물이다. | The detective in the novel is a fictional character.<br>그 소설 속 탐정은 가상 인물이다. | 예문에 쓰지 않기로 한 사람 이름(Harry)을 빼고 교체 |

## 번역투·어색한 번역 다듬기 (65)

"~을 가지고 있다", "나의/너의", "그것은 ~이었다" 같은 직역 번역을 자연스러운 한국어로 고쳤어요.

| 단어 | 바뀐 곳 | 이전 | 바꾼 내용 | 이유 |
| --- | --- | --- | --- | --- |
| long | 예문 1 번역 | 몇 달 동안 해외에 있은 뒤 그녀는 가족을 몹시 보고 싶어 했다. | 몇 달 동안 해외에 머문 뒤 그녀는 가족을 몹시 보고 싶어 했다. | '해외에 있은 뒤'가 어색해서 '머문 뒤'로 고침 |
| state | 예문 2 번역 | 그 나라의 각 주는 자체 법을 가지고 있다. | 그 나라의 각 주에는 자체 법이 있다. | '~을 가지고 있다' 번역투를 '~이 있다'로 고침 |
| meet | 예문 2 번역 | 그 제품은 우리의 기대를 충족시키지 못했다. | 그 제품은 기대를 충족시키지 못했다. | 불필요한 '우리의' 삭제 |
| view | 예문 2 번역 | 사람들은 이 문제에 대해 서로 다른 견해를 가지고 있다. | 이 문제에 대한 사람들의 견해는 저마다 다르다. | '견해를 가지고 있다' 번역투를 자연스럽게 고침 |
| share | 예문 2 번역 | 그녀는 그 회사의 지분을 많이 가지고 있다. | 그녀는 그 회사 지분을 많이 보유하고 있다. | '지분을 가지고 있다'를 '보유하고 있다'로 고침 |
| policy | 예문 2 번역 | 우리 학교는 휴대전화에 대해 엄격한 방침을 가지고 있다. | 우리 학교에는 휴대전화에 관한 엄격한 방침이 있다. | '방침을 가지고 있다' 번역투를 고침 |
| value | 예문 1 번역 | 나는 너의 솔직한 조언을 소중히 여긴다. | 나는 네 솔직한 조언을 소중히 여긴다. | '너의'를 '네'로 고침 |
| stand | 예문 2 번역 | 이 문제에 대한 너의 입장은 무엇이니? | 이 문제에 대한 네 입장은 무엇이니? | '너의'를 '네'로 고침 |
| quality | 예문 2 번역 | 그녀는 좋은 자질을 많이 가지고 있다. | 그녀에게는 좋은 자질이 많다. | '자질을 가지고 있다' 번역투를 고침 |
| technology | 예문 1 번역 | 기술은 우리의 삶을 더 편리하게 만들었다. | 기술 덕분에 우리 삶이 더 편리해졌다. | '기술은 우리의 삶을 ~ 만들었다' 직역을 자연스럽게 고침 |
| potential | 예문 1 번역 | 모든 학생은 성공할 잠재력을 가지고 있다. | 모든 학생에게는 성공할 잠재력이 있다. | '잠재력을 가지고 있다' 번역투를 고침 |
| knowledge | 예문 2 번역 | 그는 역사에 대해 깊은 지식을 가지고 있다. | 그는 역사에 관한 지식이 깊다. | '지식을 가지고 있다' 번역투를 고침 |
| agree | 예문 1 번역 | 그 계획에 대해서는 네 말에 동의한다. | 그 계획에 관해서는 네 생각에 동의한다. | '~에 대해서는 네 말에'를 자연스럽게 고침 |
| political | 예문 1 번역 | 그들은 서로 다른 정치적 견해를 가지고 있다. | 그들의 정치적 견해는 서로 다르다. | '견해를 가지고 있다' 번역투를 고침 |
| improvement | 예문 2 번역 | 새 도로는 크게 나아진 점이다. | 새 도로가 생겨서 예전보다 훨씬 나아졌다. | '크게 나아진 점이다'가 어색해서 고침 |
| weakness | 예문 2 번역 | 초콜릿은 나의 약점이다. | 나는 초콜릿에 약하다. | '초콜릿은 나의 약점이다' 직역을 자연스럽게 고침 |
| degree | 예문 1 번역 | 그녀는 컴퓨터 과학 학위를 가지고 있다. | 그녀는 컴퓨터 과학 학위가 있다. | '학위를 가지고 있다' 번역투를 고침 |
| rich | 예문 2 번역 | 그 나라는 풍부한 역사와 문화를 가지고 있다. | 그 나라는 역사와 문화가 풍부하다. | '~을 가지고 있다' 번역투를 고침 |
| male | 예문 1 번역 | 수컷 새는 흔히 화려한 깃털을 가지고 있다. | 수컷 새는 흔히 깃털이 화려하다. | '깃털을 가지고 있다' 번역투를 고침 |
| spot | 예문 1 번역 | 그 개는 검은 점이 있는 흰 털을 가지고 있다. | 그 개는 흰 털에 검은 점이 있다. | '털을 가지고 있다' 번역투를 고침 |
| otherwise | 예문 1 번역 | 서둘러라, 그렇지 않으면 우리는 늦을 것이다. | 서둘러라. 그렇지 않으면 늦을 것이다. | 쉼표로 이은 명령문을 나누고 불필요한 '우리는' 삭제 |
| request | 예문 1 번역 | 학교는 쉬는 시간을 늘려 달라는 우리의 요청에 동의했다. | 학교는 쉬는 시간을 늘려 달라는 우리 요청에 동의했다. | '우리의'를 '우리'로 고침 |
| indeed | 예문 2 번역 | 그 계획은 실제로 잘 효과를 거두었다. | 그 계획은 실제로 효과가 좋았다. | '실제로 잘 효과를 거두었다'가 어색해서 고침 |
| supply | 예문 1 번역 | 그 마을은 깨끗한 물의 공급이 제한되어 있다. | 그 마을에는 깨끗한 물이 넉넉하게 공급되지 않는다. | '물의 공급이 제한되어 있다' 직역을 자연스럽게 고침 |
| native | 예문 1 번역 | 한국어는 나의 모국어이다. | 한국어는 내 모국어이다. | '나의'를 '내'로 고침 |
| determine | 예문 1 번역 | 네 노력이 너의 성공을 결정할 것이다. | 네 노력이 네 성공을 결정할 것이다. | '너의'를 '네'로 고침 |
| aim | 예문 1 번역 | 이 수업의 목표는 너의 글쓰기 실력을 높이는 것이다. | 이 수업의 목표는 여러분의 글쓰기 실력을 높이는 것이다. | '너의'를 수업 맥락에 맞게 '여러분의'로 고침 |
| sharp | 예문 2 번역 | 고양이는 날카로운 발톱을 가지고 있다. | 고양이는 발톱이 날카롭다. | '발톱을 가지고 있다' 번역투를 고침 |
| shadow | 예문 1 번역 | 해가 지면서 우리의 그림자가 길어졌다. | 해가 지면서 우리 그림자가 길어졌다. | '우리의'를 '우리'로 고침 |
| reflect | 예문 2 번역 | 우리의 선택은 우리의 가치관을 반영한다. | 선택에는 그 사람의 가치관이 반영된다. | '우리의 선택은 우리의 가치관을' 직역을 자연스럽게 고침 |
| bother | 예문 2 번역 | 굳이 요리하지 마라. 외식할 것이다. | 굳이 요리할 필요 없다. 밖에서 먹자. | '외식할 것이다'가 어색해서 고침 |
| ruin | 예문 1 번역 | 비 때문에 우리 소풍을 망쳤다. | 비가 와서 소풍을 망쳤다. | '비 때문에 우리 소풍을 망쳤다'의 주어 호응을 고침 |
| characteristic | 예문 2 번역 | 각 동물은 고유한 특징을 가지고 있다. | 동물마다 고유한 특징이 있다. | '특징을 가지고 있다' 번역투를 고침 |
| satisfy | 예문 2 번역 | 그 식사는 우리의 배고픔을 채우기에 충분했다. | 그 식사는 배고픔을 채우기에 충분했다. | 불필요한 '우리의' 삭제 |
| means | 예문 1 번역 | 자전거는 나의 주된 교통수단이다. | 자전거는 내 주된 교통수단이다. | '나의'를 '내'로 고침 |
| advanced | 예문 2 번역 | 그 나라는 매우 발전된 기술을 가지고 있다. | 그 나라는 기술이 매우 발전했다. | '기술을 가지고 있다' 번역투를 고침 |
| incredible | 예문 2 번역 | 그녀는 놀라운 기억력을 가지고 있다. | 그녀는 기억력이 놀랍다. | '기억력을 가지고 있다' 번역투를 고침 |
| conservative | 예문 1 번역 | 우리 조부모님은 매우 보수적인 생각을 가지고 계신다. | 우리 조부모님은 생각이 매우 보수적이시다. | '생각을 가지고 계신다' 번역투를 고침 |
| ultimately | 예문 1 번역 | 결국 그것은 너의 선택이다. | 결국 선택은 네 몫이다. | '그것은 너의 선택이다' 직역을 자연스럽게 고침 |
| defeat | 예문 2 번역 | 그것은 그들의 시즌 첫 패배였다. | 그 경기는 그들의 시즌 첫 패배였다. | '그것은'으로 시작하는 직역을 고침 |
| bound | 예문 2 번역 | 그것은 조만간 일어날 수밖에 없는 일이었다. | 그런 일은 조만간 일어날 수밖에 없었다. | '그것은 ~ 일이었다' 직역을 고침 |
| meanwhile | 예문 2 번역 | 그녀는 열심히 공부했고 한편 그녀의 남동생은 게임을 했다. | 그녀는 열심히 공부했고, 그동안 남동생은 게임을 했다. | '한편 그녀의 남동생은'의 불필요한 대명사를 줄이고 뜻을 분명히 함 |
| routine | 예문 1 번역 | 운동은 나의 일과 중 하나이다. | 운동은 내 일과 중 하나이다. | '나의'를 '내'로 고침 |
| routine | 예문 2 번역 | 그것은 그저 의례적인 질문이었다. | 그저 의례적인 질문이었을 뿐이다. | '그것은'으로 시작하는 직역을 고침 |
| merely | 예문 1 번역 | 그것은 그저 농담이었다. | 그저 농담이었을 뿐이다. | '그것은'으로 시작하는 직역을 고침 |
| extraordinary | 예문 2 번역 | 그것은 놀라운 경험이었다. | 정말 놀라운 경험이었다. | '그것은'으로 시작하는 직역을 고침 |
| gene | 예문 1 번역 | 눈 색깔은 유전자에 의해 결정된다. | 눈 색깔은 유전자가 결정한다. | '~에 의해 결정된다' 수동 번역투를 고침 |
| impression | 예문 2 번역 | 그 도시에 대한 나의 첫인상은 좋았다. | 그 도시의 첫인상은 좋았다. | '나의 첫인상' 직역을 고침 |
| aggressive | 예문 2 번역 | 그 회사는 공격적인 판매 계획을 가지고 있다. | 그 회사는 공격적인 판매 계획을 세웠다. | '계획을 가지고 있다' 번역투를 고침 |
| encounter | 예문 1 번역 | 그것은 공항에서의 우연한 만남이었다. | 공항에서의 그 만남은 우연이었다. | '그것은'으로 시작하는 직역을 고침 |
| perception | 예문 1 번역, 예문 2 번역 | 소셜 미디어는 아름다움에 대한 우리의 인식을 바꿀 수 있다.<br>나이가 들면서 시간에 대한 우리의 인식이 바뀐다. | 소셜 미디어는 아름다움에 대한 인식을 바꿀 수 있다.<br>나이가 들면서 시간에 대한 인식이 달라진다. | 불필요한 '우리의' 삭제 |
| tragic | 예문 2 번역 | 그것은 그 가족에게 비극적인 상실이었다. | 그 가족에게는 비극적인 상실이었다. | '그것은'으로 시작하는 직역을 고침 |
| enhance | 예문 2 번역 | 그 강좌는 너의 글쓰기 실력을 향상시킬 것이다. | 그 강좌는 네 글쓰기 실력을 향상시킬 것이다. | '너의'를 '네'로 고침 |
| instructor | 예문 1 번역 | 나의 수영 강사는 매우 참을성이 있다. | 내 수영 강사는 매우 참을성이 있다. | '나의'를 '내'로 고침 |
| ambitious | 예문 2 번역 | 그 도시는 새 공원에 대한 야심 찬 계획을 가지고 있다. | 그 도시는 새 공원을 짓는 야심 찬 계획을 세웠다. | '계획을 가지고 있다' 번역투를 고침 |
| in accordance with | 예문 2 번역 | 우리는 너의 바람대로 행동했다. | 우리는 네 바람대로 행동했다. | '너의'를 '네'로 고침 |
| and so on | 예문 2 번역 | 그녀는 테니스, 축구 같은 운동을 좋아한다. | 그녀는 테니스, 축구 등의 운동을 좋아한다. | 'and so on'의 뜻(등)이 번역에서 빠져 있어 넣음 |
| mentor | 예문 1 번역 | 나의 첫 상사는 나의 멘토가 되었다. | 첫 직장 상사가 내 멘토가 되었다. | '나의 ~는 나의 ~'로 겹친 소유격을 정리함 |
| costly | 예문 2 번역 | 그것은 경기를 지게 만든 뼈아픈 실수였다. | 경기를 지게 만든 뼈아픈 실수였다. | '그것은'으로 시작하는 직역을 고침 |
| whereby | 예문 2 번역 | 그것은 식물이 햇빛으로 양분을 만드는 과정이다. | 이는 식물이 햇빛으로 양분을 만드는 과정이다. | '그것은'으로 시작하는 직역을 고침 |
| hardworking | 예문 2 번역 | 부지런한 농부들이 우리의 음식을 기른다. | 부지런한 농부들이 우리가 먹을 음식을 기른다. | '우리의 음식' 직역을 고침 |
| frantically | 예문 2 번역 | 그는 우리의 주의를 끌려고 미친 듯이 손을 흔들었다. | 그는 우리 눈길을 끌려고 미친 듯이 손을 흔들었다. | '우리의 주의를' 직역을 고침 |
| nag | 예문 2 번역 | 잔소리 그만해라. 나중에 할 것이다. | 잔소리 그만해라. 나중에 하겠다. | '나중에 할 것이다'가 어색해서 고침 |
| opposite | 예문 2 번역 | 그녀는 조용하지만 그녀의 언니는 정반대이다. | 그녀는 조용하지만 언니는 정반대이다. | '그녀는 ~ 그녀의'로 겹친 대명사를 줄임 |
| whereas | 예문 2 번역 | 그는 키가 큰 반면 그의 형은 키가 작다. | 그는 키가 큰 반면 형은 키가 작다. | '그는 ~ 그의'로 겹친 대명사를 줄임 |

