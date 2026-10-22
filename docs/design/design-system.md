# 디자인 시스템

> 원본: [Claude 디자인 시스템 아티팩트](https://claude.ai/artifact/FPihTBfX2CJserHVwUQ514) (2026-10-22 갱신, 연두 무드보드 + 사각 무대, 결정 0029). 아티팩트 파일 사본은 `docs/design/design-system/project/`(글꼴 woff2 는 빼고). 값은 `docs/design/tokens.json` 이 기준이다. 옛 방향 말랑 클레이(2026-10-17 승인)는 아티팩트 버전 기록과 `design/mockups/` 에 남아 있다.

앱은 `lib/core/theme.dart` 에서 이 토큰만 읽는다: `AppColors`(색), `AppText`(글자), `Gap`·`Radii`·`Borders`·`Stage`·`Motion`. 토큰 값은 `test/core/theme_test.dart` 가 `tokens.json` 과 같은지, 대비가 기준을 넘는지 라이트·다크 모두 확인한다.

달릴수록 자라는 도트 친구와 함께 뛰는 러닝 앱의 디자인 시스템. 방향은 **연두 무드보드 + 사각 무대**: 요즘 한국 생활 앱처럼 가볍고 친절하게. 큰 마스코트가 화면의 주인공이고, 정보는 테두리 없는 흰 카드가 받쳐 준다. 규칙 원본은 `design/candidates/ui/shared/direction-c.md`, 시안은 `design/candidates/ui/canvas/c/`.

## 원칙

- **마스코트가 주인공**: 캐릭터는 사각 무대 위에 화면에서 가장 큰 그림으로 선다(홈·요약 8배, 러닝 중 6배).
- **한눈에**: 러닝 중에는 거리 숫자 하나가 가장 크다(`distance-xl` 128). 옅은 풀빛 `background` 에 짙은 `ink` 글자.
- **연두는 형광펜**: `primary` 연두는 누를 것·선택된 것에만. 채워지는 막대·강조 글자는 초록 `primary-deep`. 연두는 밝은 바탕 위 1.2:1 이라 그림·막대 채움에 쓰지 않는다.
- **테두리 대신 톤**: 카드는 흰 판과 바탕의 톤 차이로 떨어진다. 그림자·립 없음.
- **벌주지 않게**: `danger` 는 위치 신호 오류 같은 진짜 문제에만.
- **한 화면 한 행동**: 화면마다 연두 버튼은 하나.

## 색

| 역할 | 토큰 | 규칙 |
| --- | --- | --- |
| 바탕 | `background` | 모든 화면. 무늬·그라데이션 없음(풍경은 무대가 맡는다) |
| 카드 | `surface` | 테두리 없음 |
| 트랙 | `surface-soft` | 진행 막대 빈 부분, 선택 안 된 칩, 분할 선택 바탕 |
| 구분선 | `line` | 옅은 구분선. 카드 테두리로 쓰지 않는다 |
| 주요 행동 | `primary` + `on-primary` + `primary-edge` 2px 경계선 | 시작, 확인. 흰 글자 금지 |
| 보조 행동 | `surface` + `ink` + `line-strong` 2px 경계선 | 끝부분 잘라내기, 이전 |
| 어두운 판 | `panel` + `on-panel` | 일시정지·재개, 탭바 선택 알약. 다크에서는 밝은 판 |
| 초록 | `primary-deep` | 강조 글자, 경험치 +, 레벨 업!, 진행·구간 막대 채움, 한 색 경로 선, 글자 버튼 |
| 달성 | `success` | 목표 달성 문구 |
| 코인 | `coin`, 그림 안 별 `on-coin` | 코인 +N, 코인 그림 |
| 무대 | `stage-sky` · `stage-ground` · `stage-ground-line`, 무대 위 글자 `stage-ink` | 사각 무대 두 겹 |
| 말풍선 | `bubble` + `ink` | 무대 위 말풍선 판·꼬리. 라이트는 흰색, 다크는 하늘보다 밝은 판 |
| 경로 페이스 | `pace-slow` 파랑 · `pace-mid` 초록 · `pace-fast` 주황 | 느림·보통·빠름. 빠른 이동 구간은 `ink-muted` |

비율: 바탕 50%, 흰 카드 35%, 연두·초록 10%, 진한 글자 5%.

direction-c 이름과 토큰: `lime` = `primary`, `green` = `primary-deep`·`success`·`pace-mid`, `green-ink` = `stage-ink`, 어두운 판 = `panel`, 트랙 = `surface-soft`.

### 새로 정한 것 (작업 10)

- **코인 색**: `coin` 토큰을 따로 둔다(시안 `#1E40AF`, 다크 `#8FAEFF`). 옛 `accent-deep` 차용은 없앴다.
- **경로 페이스 3단**: 파랑·초록·주황. 초록 안에서 밝기만 바꾸지 않고 색상을 달리해 적색맹·녹색맹·청색맹 흉내(Machado 2009)에서도 서로 ΔE76 19 이상 떨어진다(테스트 기준 15). 셋 다 흰 카드 위 3:1 이상. 구간이 1개 이하이거나 모두 같으면 한 색 **`primary-deep`**(계획 작업 13 의 "`primary`" 는 연두라 흰 카드 위 1.3:1 로 안 보여 초록으로 바꾼다). 색만으로 뜻을 전하지 않도록 범례(`느림`·`보통`·`빠름`·`빠른 이동`, 있는 색만)를 함께 둔다. 경로는 누적 거리로 1km 구간에 나누고(`routePaceSegments`), 시작 점은 연두 + `primary-edge` 경계, 끝 점은 `ink` + `surface` 고리(작업 13).
- **배경**: 단색 `background`. 무늬·그라데이션을 쓰지 않는다. 장면감은 사각 무대(하늘·땅 겹, 뒤에 배경 아이템)가 맡는다.
- **전환 시간·곡선**: 아래 "움직임".
- **연두 면 경계**(critique P1): 연두 면은 늘 `primary-edge` 2px(`Borders.edge`) 경계선을 두른다. 흰 보조 버튼은 `line-strong` 2px.
- **선택 표시 하나**(critique P1): 칩·분할 선택·목표 버튼 모두 연두 면 + `primary-edge` 경계선, 높이 48. 검은 알약(`panel`)은 탭바 선택에만.

## 글자

- **Pretendard**(SIL OFL, v1.3.9 가변 글꼴) 한 가족. `assets/fonts/PretendardVariable.ttf`, 라이선스 `assets/fonts/OFL-Pretendard.txt`. 서브셋은 작업 17.
- 앱에서는 `fontWeight` 와 같은 `wght` FontVariation 을 함께 지정한다(가변 글꼴).
- 숫자(`distance-xl`·`number-l`·`stat`): 800, 고정폭 숫자, 자간 -0.04em·-0.03em·-0.02em.
- 크기: `distance-xl` 128 (러닝 중 거리), `number-l` 64 (요약 거리·카운트다운), `title` 26 (화면 제목·이름·레벨), `stat` 22 (지표 값), `button` 22, `title-s` 22 (단위·종료 안내), `heading` 17/800 (카드 제목), `body` 17/500, `body-strong` 17/700, `label` 14/600, `caption` 13/600. 13 아래로 쓰지 않는다.

## 모양·간격

- 버튼 높이 60 알약, 칩·분할 선택 48 알약, 진행 막대 12 알약.
- 모서리: 카드·무대·다이얼로그 `radius-lg` 24, 작은 카드·말풍선·카드 안 무대 `radius-md` 20, 마스코트 판 `radius-xl` 28, 구간 막대 위끝 `radius-sm` 12.
- 간격: 좌우 `space-5` 20, 카드 사이 `space-3` 12, 섹션 사이 `space-7` 28, 카드 안 `space-5` 20.

## 사각 무대

- 폭 전체, 모서리 `Stage.radius`(24, 카드 안 `Stage.radiusInCard` 20). 하늘 `stage-sky` 위 땅 띠 `stage-ground`, 윗선 `stage-ground-line` 4px(`Borders.groundLine`).
- 땅 띠 높이(윗선 포함) `Stage.groundHeight` 56(8배), 러닝 중 `Stage.groundHeightCompact` 40(6배). 캐릭터 발끝은 윗선 아래로 `Stage.footSink` 8 묻힌다. 정수 배율, 보간 없음(`FilterQuality.none`).
- 무대는 하늘·땅 두 겹이고, 배경 아이템은 겹 단위로 바꾼다(겹마다 토큰이 따로 있는 까닭).
- 말풍선: `bubble` 판 + 꼬리, `radius-md`, 캐릭터를 가리킨다. 문구는 기존 문구만. 다크에서 `surface` 는 `stage-sky` 와 톤이 같아(ΔE76 8) 모양·꼬리가 묻혀서 `bubble` 을 따로 둔다(작업 12, 다크 `#44573A`, 하늘과 ΔE76 19, 위 `ink` 7.0:1).

## 아이콘

- 2px 둥근 선, 24px. 탭 아이콘은 일반 세트 대신 앱 고유 그림(critique P2): 러닝화, 기록 막대, 병아리 얼굴, 코인 주머니(`TabIcon`, 코드로 그린다).
- **코인 그림은 앱 코인 모양**: `coin` 동그라미 + `primary` 안쪽 고리 + `on-coin` 별(`CoinIcon`). `$`·`Icons.monetization_on` 금지.
- 요약 배지 줄 `코인 +200` 은 그 줄의 값이라 다른 줄의 경험치 값과 같은 `heading` 17/800(`coin` 색)으로, 값 아래 붙는 `코인 +N`(`label` 14/600)보다 눈에 띈다(관문 2 비평, 작업 13).

## 움직임

| 토큰 | 값 | 쓰는 곳 |
| --- | --- | --- |
| `Motion.press` | 80ms | 누름 반응 |
| `Motion.quick` | 160ms | 칩·분할·탭 선택 |
| `Motion.enter` / `Motion.exit` | 300 / 200ms | 화면·시트 들어오기·나가기(나가기 ≈ 2/3) |
| `Motion.celebrate` | 600ms | 레벨 업·배지 획득 |
| `Motion.enterCurve` / `Motion.exitCurve` | easeOutCubic / easeInCubic | 들어올 때 감속, 나갈 때 가속 |
| `Motion.standard` | easeInOutCubic | 제자리 상태 변화 |
| `Motion.pop` | easeOutBack | 보상 튀어 오름 |

시스템 "애니메이션 줄이기" 를 켜면 움직임을 빼고 바로 최종 상태를 보인다(작업 15).

## 다크 모드

시안에 없어 작업 10 에서 새로 설계했다. 반전하지 않고 같은 정체성을 지킨다.

- 바탕은 풀빛 어둠(`background` #10160D), 카드 `surface`·트랙 `surface-soft` 가 한 단계씩 밝아 테두리 없이 떨어진다.
- 연두 `primary` 와 `on-primary` 는 라이트와 같은 값. 연두 면은 다크 바탕 위에서 13:1 이라 경계선 `primary-edge` 는 덜 진한 연두.
- 초록·코인·페이스·위험 색은 어두운 바탕에서 읽히도록 밝은 쪽으로 옮겼다. `panel` 은 밝은 판 + 짙은 글자.
- 무대는 어두운 풀빛 하늘·땅. 스프라이트는 `sprite-rim` 1픽셀 윤곽으로 무대에 묻히지 않게 한다(라이트는 투명).

## 접근성

- 글자 대비 4.5:1 이상(24px 이상 3:1), 면 경계·그림 3:1 이상. 쌍마다 라이트·다크 측정값은 테스트가 확인한다.
- 채움 전용 쌍(글자로 쓰지 않는다): `stage-sky` 위 `ink-muted`, `surface-soft` 위 `primary-deep`(막대 채움은 그림 3:1 로 검사). `stage-sky` 위 `primary-deep` 은 24px 이상 큰 글자로만 쓴다. 무대 위 작은 글자는 `stage-ink`, 말풍선은 `bubble` 위 `ink`.
- 누를 수 있는 것은 48×48 이상.
- 시스템 글자 크기를 키워도 잘리지 않게, 고정 높이 안에 글자를 가두지 않는다.

## 작업 11~15 를 위한 메모

- 토큰 이름 변경: `cream` → `background`, `accent`/`on-accent` → `panel`/`on-panel`, `accent-deep` → `coin`(코인) 또는 없앰(립). `primary-deep` 은 이름은 같고 뜻이 "주황 립" 에서 "초록 강조" 로 바뀌었다.
- 공통 컴포넌트는 `lib/core/ui/components.dart`(작업 11, 옛 `clay.dart`): `AppCard`·`StatCard`·`StatsCard`(흰 카드 하나에 지표 칸 `StatCard.cell` 여러 개, 작업 12), `AppButton`(기본 연두·`.secondary` 흰·`.panel` 어두운 판), `AppChip`·`ChipRow`(칩·분할 선택 공통), `ProgressBar`, `CoinIcon`(코인 칩은 `lib/shop/ui/coin_chip.dart`), `AppTabBar`·`TabIcon`, `PetStage`·`StageGround`·`SpeechBubble`, `Pressable`(누름 0.97), `ScreenTitle`. 다이얼로그는 `AlertDialog` 를 그대로 쓰고 모양은 테마(`filledButtonTheme`·`textButtonTheme`·`dialogTheme`)가 정한다.
- `PetStage` 는 펫(`32 × scale`)을 발끝이 땅 윗선 아래 `Stage.footSink` 에 묻히게 놓는다(8배 땅 56 → 펫 상자 아래 32, 6배 땅 40 → 20). 하늘·땅 겹은 `sky`·`ground` 로 바꾼다. 화면 적용은 작업 12~14.
- 옛 `Borders.thick`·`lip`·`lipPressed` 는 지웠다. 포커스 윤곽은 `Borders.focus` 3.
