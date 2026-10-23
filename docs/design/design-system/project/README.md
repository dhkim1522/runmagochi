# 런마고치

달릴수록 자라는 도트 친구와 함께 뛰는 러닝 앱의 디자인 시스템. 방향은 **연두 무드보드 + 사각 무대**(결정 0029, 2026-10-22): 요즘 한국 생활 앱처럼 가볍고 친절하게. 큰 마스코트가 화면의 주인공이고, 정보는 테두리 없는 흰 카드가 받쳐 준다.

> 이전 방향 말랑 클레이(2026-10-17, 주황·크림, 두꺼운 테두리·립, Jua + Noto Sans KR)는 이 아티팩트의 버전 기록에 남아 있다.

## 원칙

- **마스코트가 주인공**: 캐릭터는 사각 무대 위에 화면에서 가장 큰 그림으로 선다(홈·요약 8배, 러닝 중 6배). 무대 기본 배경은 공원 산책로(한 점 투시 도트 그림, 네 겹)이고, 배경 아이템·날씨가 겹 단위로 바꾼다.
- **한눈에**: 러닝 중에는 거리 숫자 하나가 가장 크다(`distance-xl` 128). 야외 햇빛 아래에서도 읽히도록 옅은 풀빛 `background` 에 짙은 `ink` 글자.
- **연두는 형광펜**: `primary` 연두는 "지금 누를 것" 과 "선택된 것" 에만. 채워지는 막대·강조 글자는 초록 `primary-deep`. 연두는 밝은 바탕 위에서 1.2:1 이라 그림·막대 채움에 쓰지 않는다.
- **테두리 대신 톤**: 카드는 흰 판과 바탕의 톤 차이로만 떨어진다. 그림자는 없거나 한 겹만.
- **벌주지 않게**: 쉬어도 혼내는 빨강을 쓰지 않는다. `danger` 는 위치 신호 오류 같은 진짜 문제에만.
- **한 화면 한 행동**: 화면마다 연두 버튼은 하나.

## 색

비율: 바탕 50%, 흰 카드 35%, 연두·초록 10%, 진한 글자 5%.

| 역할 | 토큰 | 규칙 |
| --- | --- | --- |
| 바탕 | `background` | 모든 화면. 무늬·그라데이션 없음 — 풍경은 무대가 맡는다 |
| 카드 | `surface` | 테두리 없음, 모서리 `radius-lg`(작은 카드 `radius-md`) |
| 트랙 | `surface-soft` | 진행 막대 빈 부분, 선택 안 된 칩, 분할 선택 바탕 |
| 주요 행동 | `primary` + `on-primary` + `primary-edge` 2px 경계선 | 시작, 확인. 흰 글자 금지 |
| 보조 행동 | `surface` + `ink` + `line-strong` 2px 경계선 | 끝부분 잘라내기, 이전 |
| 어두운 판 | `panel` + `on-panel` | 일시정지, 탭바 선택 알약. 다크에서는 밝은 판 |
| 초록 | `primary-deep` | 강조 글자, 경험치 +, 레벨 업!, 진행·구간 막대 채움, 글자 버튼 |
| 코인 | `coin`, 그림 안 별 `on-coin` | 코인 +N, 코인 그림 |
| 무대 | `stage-sky` · `stage-ground` · `stage-ground-line`, 무대 위 글자 `stage-ink`, 배경 `park-*`, 발밑 그림자 `stage-shadow` | 하늘·풀밭·풀잎, 공원 산책로 배경 |
| 말풍선 | `bubble` + `ink` | 무대 위 말풍선 판·꼬리. 라이트는 흰색, 다크는 하늘보다 밝은 판(다크 `surface` 는 하늘에 묻힌다) |
| 경로 페이스 | `pace-slow`·`pace-mid`·`pace-fast` 연두 한 계열 3단 | 천천히·보통·빠르게. 빠른 이동 구간은 `ink-muted`(범례 `빠른 이동 · 제외`) |
| 문제 알림 | `danger` | 위치 신호 오류·저장 실패(`NoticeCard`)에만 |

## 선택 표시는 하나

선택된 칩·분할 선택·목표 버튼은 모두 **연두 면 + `primary-edge` 2px 경계선**이다. 검은 알약은 탭바 선택에만 쓴다. 분할 선택도 칩과 같은 높이 48 알약이다.

## 연두 면의 경계

연두 면은 바탕 대비 1.2:1 이라 모양이 흐리다. 연두 면은 늘 `primary-edge` 를 `border-edge`(2px) 두께로 두른다. 이 선이 바탕·카드·트랙과 3:1 이상이다. 흰 보조 버튼도 같은 이유로 `line-strong` 2px 경계선을 두른다.

## 글자

- **Pretendard**(SIL OFL, v1.3.9 가변 글꼴) 한 가족. 이 시스템의 견본은 원본 Pretendard 를 쓴다. 앱은 앱에 쓰는 글자만 남긴 서브셋을 번들하고, OFL 예약 글꼴 이름 조항에 따라 그 서브셋은 `RunmagochiSans`(파일 `assets/fonts/RunmagochiSans.ttf`, 내부 이름 Runmagochi Sans)라고 부른다. 모양은 같다.
- 숫자: 800, 자간 -0.02em(거리 128 은 -0.04em, 64 는 -0.03em), 고정폭 숫자(tnum).
- 크기: `distance-xl` 128 (러닝 중 거리) · `number-l` 64 (요약 거리·카운트다운) · `title` 26 (화면 제목·이름·레벨) · `stat`·`button`·`title-s` 22 (지표 값·버튼·단위) · `heading`·`body` 17 · `label` 14 · `caption` 13. **13 아래 없음.**

## 모양

- 버튼: 높이 60, 알약, 글자 `button`. 립 없음.
- 칩·분할 선택: 높이 48 알약.
- 진행 막대: 높이 12 알약, 채움 `primary-deep`, 트랙 `surface-soft`.
- 카드: `radius-lg` 24(작은 카드 `radius-md` 20, 마스코트 판 `radius-xl` 28), 안쪽 여백 `space-5`.
- 말풍선: `bubble` 판 + 아래 작은 꼬리, `radius-md`, 글자 `label` 14/700 한 줄. 문구는 기존 문구만(`다음 레벨까지 6.0km`).
- 동그라미 버튼: 48 흰 동그라미 + `ink` 아이콘 24(뒤로·설정).
- 빈 상태: 흰 카드 가운데 앱 그림(40) + `ink-muted` 문구. 불러오기 실패도 같은 카드에 느낌표 동그라미(`danger` 아님).
- 간격: 좌우 `space-5` 20, 카드 사이 `space-3` 12, 섹션 사이 `space-7` 28.

## 사각 무대

- 폭 전체, 모서리 `radius-lg`(카드 안 `radius-md`). 정수 배율, 보간 없음.
- **배경은 공원 산책로**(관문 3 에서 고른 안 2): 소실점이 펫 몸 뒤 지평선에 있는 한 점 투시 도트 그림. 모래빛 흙길(`park-path`, 가장자리 `park-edge`)이 소실점으로 좁아지고, 길 위 자갈(`park-pebble`·`park-pebble-hi`)·풀잎(`stage-ground-line`)·작은 꽃(`park-flower`) 점, 길가 둥근 나무·덤불(`park-canopy`·`park-canopy-hi`, 줄기 `park-trunk`), 지평선 위 두 겹 나무 줄(`park-far`·`park-far2`). 연두 `primary` 는 배경에 쓰지 않는다.
- **겹**(아래 → 위): 1 하늘 `stage-sky` + 도트 구름 2~3개(`park-cloud`, 멈춤. 오른쪽 위 96px 말풍선 자리와 먼 풍경 띠는 비운다. 3배 미만 작은 무대는 구름 없음) → 2 먼 풍경(지평선 위 12칸 띠) → 3 땅·길(풀밭 `stage-ground`) → 4 앞 장식(길가 물체, 먼 것부터) → 펫과 발밑 도트 그림자(`stage-shadow`, 폭 20 스프라이트 칸) → 말풍선. 배경 아이템은 다른 겹 묶음(`StageScene`)을 준다.
- **크기**: 배경 도트 1칸 `stage-dot` 4px(6배 이상, 펫 8배 도트의 절반. 작으면 `2·배율/3` 내림, 최소 1px). 지평선은 발끝 위 `stage-horizon` 13 스프라이트 줄. 길가 물체는 3배 이상에서만.
- **발끝**: 무대 아래에서 `땅 높이 − stage-foot-sink` 위에 선다. `stage-ground-height` 56(8배) → 48, `stage-ground-height-compact` 40(러닝 중 6배) → 32, `stage-ground-height-mini` 24(카드 안 2~3배, 모서리 `radius-sm`) → 16. 옛 땅 띠·윗선은 없어지고 발밑 그림자가 땅에 선 느낌을 준다.
- **러닝 중 흐름**: 기록 중에만 땅·길 무늬와 길가 물체가 소실점 쪽으로 0.5칸/초 물러난다. 한 장 `duration-stage-frame` 125ms(초당 8장, 도트 느낌·배터리). 하늘·구름·먼 풍경은 멈춤. 일시정지·자동 일시정지면 그 자리에 멈추고, 홈·요약·아바타·상점·첫 실행·공유 카드는 늘 멈춤. 애니메이션 줄이기면 0번 장에 멈춘다.
- **다크**: 어두운 풀빛 하늘·풀밭에 어두운 흙길·나무(`park-*` 다크 값). 스프라이트 둘레를 `sprite-rim` 으로 얇게 두른다: `max(1, round(배율/4))` 화면 px(8배·6배 2px, 3배 1px). 도트 1칸 두께는 굵어 관문 3 에서 얇은 쪽(비교 B)을 골랐다. 라이트는 그리지 않는다.
- 말풍선은 SpeechBubble(`bubble` 판), 무대 오른쪽 위. 러닝 중에는 탈것 의심("혹시 뭘 타셨나요? 이 구간은 기록에서 뺄게요")·신호 끊김("신호가 끊겼어요. 밖으로 나오면 다시 찾을게요") 안내도 같은 말풍선에 띄운다.

## 아이콘

- 2px 둥근 선, 24px. 탭 아이콘(러닝·기록·아바타·상점)은 일반 세트 대신 앱 고유 그림을 쓴다.
- **코인 그림은 앱 코인 모양**: `coin` 동그라미 + 연두 안쪽 고리 + `on-coin` 별. `$` 기호 금지(앱 코인은 달러가 아니다).

## 경로 페이스 색

- 이 러닝의 가장 느린·빠른 1km 구간 사이를 3단으로 나눠 칠한다: `pace-slow`(옅은 올리브 연두)·`pace-mid`(초록)·`pace-fast`(짙은 숲색). 연두 한 계열의 명도 단계이고 다크는 빠를수록 옅다.
- 관문 3 에서 보라를 없애고 연두 한 계열로 바꿨다(작업 29). 명도를 크게 달리 잡아 세 색과 빠른 이동 `ink-muted` 넷이 정상·적·녹·청 색각 이상(Machado 2009) 모두에서 서로 CIEDE2000 15 이상, `surface`·`background` 위 3:1 이상이다.
- 구간이 1개 이하이거나 모두 같으면 한 색 `primary-deep`. 빠른 이동 구간은 `ink-muted`.
- 시작 점은 연두 + `primary-edge` 경계, 끝 점은 `ink` + `surface` 고리.
- 색만으로 뜻을 전하지 않는다: 경로 카드 아래 범례(`천천히`·`보통`·`빠르게`·`빠른 이동 · 제외`, 있는 색만)를 둔다.

## 움직임

| 토큰 | 값 | 쓰는 곳 |
| --- | --- | --- |
| `duration-press` | 80ms | 누름 반응 |
| `duration-quick` | 160ms | 칩·분할·탭 선택 |
| `duration-enter` / `duration-exit` | 300 / 200ms | 화면·아래 시트(오늘 목표·끝부분 잘라내기) 들어오기·나가기 |
| `duration-stage-frame` | 125ms | 러닝 중 무대 길 흐름 한 장(초당 8장) |
| `duration-celebrate` | 600ms | 레벨 업·배지 획득 |
| `curve-enter` / `curve-exit` | easeOutCubic / easeInCubic | 들어올 때 감속, 나갈 때 가속 |
| `curve-standard` | easeInOutCubic | 제자리 상태 변화 |
| `curve-pop` | easeOutBack | 보상 튀어 오름 |

시스템 "애니메이션 줄이기" 가 켜져 있으면 움직임을 빼고 바로 최종 상태를 보인다. 누름도 `duration-press` 만큼 붙잡지 않고 누른 동안만 눌린 모양이다. 아래 시트는 바로 열리고 닫히며, 무대 길은 멈춘다.

아래 시트는 `duration-enter` + `curve-enter` 로 올라오고 `duration-exit` + `curve-exit` 로 내려간다. 오늘 목표 시트는 거리·시간 분할 → 값 칩 3개 → 휠(가운데 칸은 `surface-soft` 조용한 알약) → 연두 `확인` 하나(GoalSheet 견본).

## 화면 모드

설정 › 화면 › 화면 모드에서 `시스템`(기본)·`라이트`·`다크` 를 고른다(칩 3칸, `ChipRow`). 라이트·다크를 고르면 기기 설정과 상관없이 그 테마로 그린다. 값은 프로필에 저장하고 백업에 들어간다(DB·백업 7판).

## 다크 모드

시안에 없던 것을 새로 설계했다. 반전이 아니라 같은 정체성: 풀빛 어둠 바탕(`background` #10160D) 위에 카드·트랙이 한 단계씩 밝고, 연두 `primary` 는 라이트와 같은 값이다. 초록·코인·페이스 색은 어두운 바탕에서 읽히도록 밝은 쪽으로 옮겼다. 어두운 판 `panel` 은 다크에서 밝은 판이 된다.

## 접근성

- 글자 대비 4.5:1 이상(24px 이상 3:1), 경계·그림 3:1 이상. 라이트·다크 둘 다 앱 테스트(`test/core/theme_test.dart`)가 쌍마다 잰다.
- 누를 수 있는 것은 48×48 이상.
- 시스템 글자 크기를 키워도 잘리지 않게, 고정 높이 안에 글자를 가두지 않는다.

## 앱 코드

`lib/core/theme.dart` 가 이 토큰만 읽는다: `AppColors`(색), `AppText`(글자), `Gap`·`Radii`·`Borders`·`Stage`·`Motion`. 토큰 원본은 저장소 `docs/design/tokens.json`.

공통 컴포넌트는 `lib/core/ui/components.dart` 에 있다. 이 시스템의 견본과 이름이 이렇게 맞는다.

| 견본 | 앱 컴포넌트 |
| --- | --- |
| Button | `AppButton`(기본·`.secondary`·`.panel`), 누름 `Pressable` |
| CircleIconButton | `CircleIconButton` |
| Chip | `AppChip`·`ChipRow` |
| Card · StatsCard | `AppCard`, `StatsCard` + `StatCard.cell` |
| ProgressBar | `ProgressBar` |
| Coin | `CoinIcon`, 코인 칩 `CoinChip` |
| Stage · SpeechBubble | `PetStage`·`StageBackdrop`(배경 `StageScene`·`parkScene`), `SpeechBubble` |
| GoalSheet | 오늘 목표 시트(홈 `오늘 목표 5km ›` 한 줄에서 연다) |
| EmptyState · NoticeCard | `EmptyState`(`.error`), `NoticeCard` |
| RoutePace | `RoutePainter`·`RoutePaceLegend` |
| TabBar | `AppTabBar`·`TabIcon` |

화면별 구성은 저장소 `docs/screens.md` "화면 디자인", 실제 앱 스크린샷은 [화면설계서](https://claude.ai/artifact/456dWcNyLn1vbUsjV9FLVc)(저장소 `design/screens/`).
