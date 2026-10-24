# 디자인 시스템

> 원본: [Claude 디자인 시스템 아티팩트](design-system/index.html) (2026-10-22 갱신, 연두 무드보드 + 사각 무대, 결정 0029. 작업 18 에서 토큰을 `tokens.json` 과 맞추고 컴포넌트 견본 13개로 늘림). 아티팩트 파일 사본은 `docs/design/design-system/project/`(글꼴 woff2 는 빼고). 값은 `docs/design/tokens.json` 이 기준이다. 아티팩트 개요(README)는 색·글꼴·간격·모서리·그림자만 짧게 요약한 것이라(궁서체로 보이던 제목은 페이지가 `# 제목`을 세리프로 그려서였고, 제목 줄을 뺐다), 자세한 규칙은 이 문서가 원천이다. 옛 방향 말랑 클레이(2026-10-17 승인)는 아티팩트 버전 기록과 `design/mockups/` 에 남아 있다.

앱은 `lib/core/theme.dart` 에서 이 토큰만 읽는다: `AppColors`(색), `AppText`(글자), `Gap`·`Radii`·`Borders`·`Stage`·`Motion`. 토큰 값은 `test/core/theme_test.dart` 가 `tokens.json` 과 같은지, 대비가 기준을 넘는지 라이트·다크 모두 확인한다.

달릴수록 자라는 도트 친구와 함께 뛰는 러닝 앱의 디자인 시스템. 방향은 **연두 무드보드 + 사각 무대**: 요즘 한국 생활 앱처럼 가볍고 친절하게. 큰 마스코트가 화면의 주인공이고, 정보는 테두리 없는 흰 카드가 받쳐 준다. 규칙 원본은 `design/mockups/phase-6/direction-c.md`, 시안은 `design/mockups/phase-6/canvas/c/`.

## 원칙

- **마스코트가 주인공**: 캐릭터는 사각 무대 위에 화면에서 가장 큰 그림으로 선다(홈·요약 8배, 러닝 중 6배). 단계가 올라도 몸을 옆으로 넓히지 않고(2단계 이후 같은 폭, 3·4단계 폭÷키 0.9 이하) 키·외관·장비로 자란다(결정 0034, `docs/specs/sprite-spec.md`).
- **한눈에**: 러닝 중에는 거리 숫자 하나가 가장 크다(`distance-xl` 128). 옅은 풀빛 `background` 에 짙은 `ink` 글자.
- **연두는 형광펜**: `primary` 연두는 누를 것·선택된 것에만. 채워지는 막대·강조 글자는 초록 `primary-deep`. 연두는 밝은 바탕 위 1.2:1 이라 그림·막대 채움에 쓰지 않는다.
- **테두리 대신 톤**: 카드는 흰 판과 바탕의 톤 차이로 떨어진다. 그림자·립 없음. 버튼·선택된 칩도 진한 테두리 없이 면과 옅은 그림자(`elevation-float`)로만 뜬다.
- **벌주지 않게**: `danger` 는 위치 신호 오류 같은 진짜 문제에만.
- **한 화면 한 행동**: 화면마다 연두 버튼은 하나.

## 색

| 역할 | 토큰 | 규칙 |
| --- | --- | --- |
| 바탕 | `background` | 모든 화면. 무늬·그라데이션 없음(풍경은 무대가 맡는다) |
| 카드 | `surface` | 테두리 없음 |
| 트랙 | `surface-soft` | 진행 막대 빈 부분, 선택 안 된 칩, 분할 선택 바탕 |
| 구분선 | `line` | 옅은 구분선. 카드 테두리로 쓰지 않는다 |
| 주요 행동 | `primary` + `on-primary`, 경계선 없이 `elevation-float` | 시작, 확인. 흰 글자 금지 |
| 보조 행동 | `surface` + `ink`, `elevation-float` + `line` 1px 머리카락 선 | 끝부분 잘라내기, 이전, 길게 눌러 종료 |
| 어두운 판 | `panel` + `on-panel` | 일시정지·재개, 탭바 선택 알약. 다크에서는 밝은 판 |
| 초록 | `primary-deep` | 강조 글자, 경험치 +, 레벨 업!, 진행·구간 막대 채움, 한 색 경로 선, 글자 버튼 |
| 달성 | `success` | 목표 달성 문구 |
| 코인 | `coin`, 그림 안 별 `on-coin` | 코인 +N, 코인 그림 |
| 무대 | `stage-sky` · `stage-ground` · `stage-ground-line`, 무대 위 글자 `stage-ink`, 배경색 `stageScene.park` | 사각 무대 하늘·풀밭·풀잎, 공원 산책로 배경 |
| 말풍선 | `bubble` + `ink` | 무대 위 말풍선 판·꼬리. 라이트는 흰색, 다크는 하늘보다 밝은 판 |
| 경로 페이스 | `pace-slow`·`pace-mid`·`pace-fast` 연두 한 계열 3단 | 천천히·보통·빠르게. 빠른 이동 구간은 `ink-muted`(범례 `빠른 이동 · 제외`), 한 색 경로는 `primary-deep` |

비율: 바탕 50%, 흰 카드 35%, 연두·초록 10%, 진한 글자 5%.

direction-c 이름과 토큰: `lime` = `primary`, `green` = `primary-deep`·`success`, `green-ink` = `stage-ink`, 어두운 판 = `panel`, 트랙 = `surface-soft`.

### 새로 정한 것 (작업 10)

- **코인 색**: `coin` 토큰을 따로 둔다(시안 `#1E40AF`, 다크 `#8FAEFF`). 옛 `accent-deep` 차용은 없앴다.
- **경로 페이스 3단**: 연두 한 계열의 명도 단계(작업 13 → 관문 3 작업 29 에서 파랑·자주·주황을 바꿈. 보통이 보라라 어색하다는 의견). 라이트는 느림 `#659325`(올리브 연두) → 보통 `#066B0E`(초록) → 빠름 `#003647`(짙은 청록), 빠를수록 짙다(작업 30: 보통·빠름이 둘 다 어두운 초록이라 구분이 약해 색조를 연두→초록→청록으로 넓힘). 다크는 느림 `#4D7722` → 보통 `#61AE13` → 빠름 `#EAF6AC`, 빠를수록 옅다(어두운 바탕에서 밝을수록 눈에 띈다). 한 방향 단계라 라이트 색상(hue) 약 85~197도, 명도 차를 크게 잡아 세 색과 빠른 이동 `ink-muted`(회색 풀색) 넷이 정상·적·녹·청 색각 이상(Machado 2009 흉내) 모두에서 서로 CIEDE2000 라이트 15.6·다크 17.4 이상(테스트 기준 15)이다. 라이트 빠름 `#003647` 은 본문 `ink` 와도 CIEDE2000 정상 20.5·색각 이상 13.3 이상 떨어진다(테스트: 정상 15, 색각 12). 넷 다 `surface`·`background` 위 3:1 이상(라이트 3.32~12.97, 다크 3.07~16.0). 구간 막대·경로 선·범례가 같은 토큰(`RoutePaceColors`)을 쓴다. 구간이 1개 이하이거나 모두 같으면 한 색 **`primary-deep`**. 색만으로 뜻을 전하지 않도록 범례(`천천히`·`보통`·`빠르게`·`빠른 이동 · 제외`, 있는 색만)를 함께 둔다. `빠른 이동 · 제외`는 탈것이 의심돼 경험치에서 뺀 구간이라 회색(`ink-muted`)으로 연두 단계와 떨어뜨린다. 경로는 누적 거리로 1km 구간에 나누고(`routePaceSegments`), 시작 점은 연두 + `primary-edge` 경계, 끝 점은 `ink` + `surface` 고리(작업 13).
- **배경**: 단색 `background`. 무늬·그라데이션을 쓰지 않는다. 장면감은 사각 무대(공원 산책로 네 겹, 배경 아이템이 겹을 바꾼다)가 맡는다.
- **전환 시간·곡선**: 아래 "움직임".
- **연두 면은 테두리 없이 뜬다**(작업 31, 관문 3 이후 의견, 비교 C 안): 옛 critique P1 의 `primary-edge` 2px·`line-strong` 2px 경계선이 어색하다는 의견으로 없앴다. 연두 버튼·선택된 칩·분할 선택은 경계선 없는 채움 + `elevation-float`, 흰 보조 버튼은 `elevation-float` + `line` 1px(`Borders.hairline`)이다. 그림자는 있는 듯 없는 듯 옅게: 라이트 `0 3px 8px -3px ink 14%` + `0 1px 2px ink 8%`(비교 C 안 `0 6px 14px -4px 38%` + `0 1px 2px 22%` 의 절반 이하), 다크는 어두운 바탕에서 안 보여 `0 2px 4px -1px #000 20%` 한 겹뿐이고 면 밝기(연두 13:1)가 구분을 맡는다. `primary-edge` 는 고른 카드 윤곽(상점·아바타)·경로 시작 점·스플래시 타일에만 남는다.
- **선택 표시 하나**(critique P1, 작업 31 갱신): 칩·분할 선택·목표 버튼 모두 연두 면 + 앞의 체크 아이콘(`check_rounded` 20, `on-primary`) + 17/800 굵은 글자, 높이 48. 테두리가 없어도 색만으로 구분하지 않는다(연두와 트랙 `surface-soft` 는 명도가 비슷하다). 검은 알약(`panel`)은 탭바 선택에만.

## 글자

- **Pretendard**(SIL OFL, v1.3.9 가변 글꼴) 한 가족. 앱에는 서브셋 `assets/fonts/RunmagochiSans.ttf` 를 번들하고, 라이선스는 `assets/fonts/OFL-Pretendard.txt`.
  - 번들 파일은 KS X 1001 한글 2,350자 + 영문·숫자·Latin-1·기호 + `lib` 에 쓰인 모든 글자만 남긴 서브셋이다(굵기 축 유지, 약 1.1MB). 목록은 `tool/font_chars.txt`, 원본 전체 글꼴은 `tool/fonts/`, 다시 만들기는 `tool/subset_fonts.py`(실행 방법은 맨 위 주석).
  - OFL 예약 글꼴 이름(Pretendard) 조항에 따라 고친(서브셋) 글꼴은 이름에 Pretendard 를 쓰지 않는다: 파일 `RunmagochiSans.ttf`, Flutter family `RunmagochiSans`, 내부 글꼴 이름 `Runmagochi Sans`(작업 18). 수정하지 않은 원본 `tool/fonts/PretendardVariable.ttf` 는 이름 그대로다. 디자인 시스템 아티팩트·시안(웹)은 원본 Pretendard 를 쓴다.
  - 문구에 새 글자를 쓰면 `test/tool/font_chars_test.dart` 가 실패한다. 스크립트를 다시 실행한다. 목록 밖 글자(예: 사용자가 입력한 드문 한글)는 기기 시스템 글꼴로 보인다.
- 앱에서는 `fontWeight` 와 같은 `wght` FontVariation 을 함께 지정한다(가변 글꼴).
- 숫자(`distance-xl`·`number-l`·`stat`): 800, 고정폭 숫자, 자간 -0.04em·-0.03em·-0.02em.
- 크기: `distance-xl` 128 (러닝 중 거리), `number-l` 64 (요약 거리·카운트다운), `title` 26 (화면 제목·이름·레벨), `stat` 22 (지표 값), `button` 22, `title-s` 22 (단위·종료 안내), `heading` 17/800 (카드 제목), `body` 17/500, `body-strong` 17/700, `label` 14/600, `caption` 13/600. 13 아래로 쓰지 않는다.

## 모양·간격

- 버튼 높이 60 알약, 칩·분할 선택 48 알약, 진행 막대 12 알약.
- 모서리: 카드·무대·다이얼로그 `radius-lg` 24, 작은 카드·말풍선·카드 안 무대 `radius-md` 20, 마스코트 판 `radius-xl` 28, 구간 막대 위끝 `radius-sm` 12.
- 간격: 좌우 `space-5` 20, 카드 사이 `space-3` 12, 섹션 사이 `space-7` 28, 카드 안 `space-5` 20.
- 그래프 막대(기록 기간 막대·요약 구간 막대)는 `primary-deep` 채움, 위끝 둥글게(`radius-sm`, 좁으면 폭의 절반). 연두로 채우지 않는다.
- 시안 없는 화면(기록·아바타·업적·상점·코인 내역, 작업 14)도 같은 짜임새: 머리줄(제목 또는 뒤로 동그라미 + 제목) → 흰 카드들, 섹션 제목은 `heading` 17/800.

## 사각 무대

- 폭 전체, 모서리 `Stage.radius`(24, 카드 안 `Stage.radiusInCard` 20). 정수 배율, 보간 없음(`FilterQuality.none`).
- 배경은 **공원 산책로**(작업 25, 관문 3 에서 고른 안 2) 한 점 투시 도트 그림이다. 소실점은 펫 몸 뒤 지평선에 있고, 모래빛 흙길이 소실점으로 좁아진다. 길 위 자갈·풀잎·작은 꽃 점, 길가 둥근 나무(±1.7)·덤불(±1.15), 지평선 위 두 겹 나무 줄. 위쪽 하늘은 말풍선·날씨 자리로 비운다. 연두 `primary` 는 배경에 쓰지 않는다. 그림 원본(투시 식·색·속도)은 `design/mockups/phase-6/stage-background/gen.py`·`notes.md`, 시안은 [캔버스](../../design/mockups/phase-6/compare/index.html) "무대 배경 시안 — 작업 25".
- 겹(아래 → 위): 1 하늘(`stage-sky` 단색 + 도트 구름 2~3개 `park-cloud`, 멈춤. 오른쪽 위 96px 는 말풍선 자리라 비우고 먼 풍경 띠 위 2칸까지만, 3배 미만 작은 무대는 구름 없음. 나중에 날씨 겹이 이 겹을 바꾼다) → 2 먼 풍경(지평선 위 12칸 띠, 멈춤) → 3 땅·길(풀밭 `stage-ground`, 풀잎 `stage-ground-line`, 길·점) → 4 앞 장식(길가 물체, 먼 것부터) → 펫(발밑 도트 그림자) → 말풍선. 4 는 이름과 달리 펫 뒤에 그린다(펫보다 가까운 물체는 화면 좌우 끝이라 겹치지 않는다). 겹은 `StageScene`(`lib/core/stage/stage_scene.dart`)으로 묶고, 배경 아이템은 다른 `StageScene` 을 `PetStage.scene` 에 준다. 공원 산책로만의 색은 `ParkPalette`(`lib/core/stage/park_scene.dart`, `tokens.json` 의 `stageScene.park`).
- 배경 도트 1칸 = 4px(6배 이상, 펫 8배 도트의 절반). 펫이 작으면 `2·배율/3` 내림(최소 1px). 지평선은 발끝 위 13 스프라이트 줄(가슴 높이), 무대가 아주 낮으면 무대 높이의 3/4 를 넘지 않는다. 길가 물체는 3배 이상에서만 그린다(성장 단계 줄 2배 무대는 하늘·먼 풍경·길만).
- 펫 발끝은 무대 아래에서 `땅 높이 − Stage.footSink` 위에 선다: `Stage.groundHeight` 56(8배) → 48, 러닝 중 `Stage.groundHeightCompact` 40(6배) → 32, 카드 안 `Stage.groundHeightMini` 24(2~3배, 모서리 `radius-sm` 12) → 16. 땅 띠가 없어진 대신 발밑 도트 그림자(폭 20 스프라이트 칸, 배경 도트 3줄, 라이트 `ink` 14%·다크 검정 30%)가 땅에 선 느낌을 준다.
- 러닝 중(일시정지가 아닐 때)에만 땅·길 무늬와 길가 물체가 소실점 쪽으로 물러난다: 0.5칸/초, 무늬 주기 2칸을 32장으로 끊어 초당 8장(도트 느낌, 배터리). 하늘·먼 풍경은 멈춤. 홈·요약·아바타·상점·첫 실행·공유 카드는 늘 멈춤. 일시정지·자동 일시정지면 그 자리에 멈추고 재개하면 이어서 흐른다. 애니메이션 줄이기면 0번 장에 멈춘다. 흐름은 펫을 다시 만들지 않는다(`StageBackdrop` 의 `RepaintBoundary` 안 `CustomPaint` 만 다시 그리고, 멈춘 겹·장마다의 흐르는 겹을 크기·테마별 `Picture` 로 담아 둔다).
- 말풍선: `bubble` 판 + 꼬리, `radius-md`, 캐릭터를 가리킨다. 문구는 기존 문구만. 다크에서 `surface` 는 `stage-sky` 와 톤이 같아(ΔE76 8) 모양·꼬리가 묻혀서 `bubble` 을 따로 둔다(작업 12, 다크 `#44573A`, 하늘과 ΔE76 19, 위 `ink` 7.0:1).

## 앱 아이콘·스플래시·알림 아이콘

- 스플래시 타일(하늘+땅 사각 무대)은 크림 바탕과 색이 비슷해, 가장자리에 `primary-edge` 4dp 테두리를 두른다(작업 29, 대비 라이트 바탕 3.8:1·다크 바탕 4.4:1). 라이트·다크가 같은 그림이고 바탕만 다르다.
- 안드로이드 알림 작은 아이콘은 `ic_stat_chick`(24dp 계열 5밀도 drawable): 병아리 도트 실루엣, 흰색+투명, 눈은 구멍. 알림·러닝 기록 서비스 알림 모두 쓴다. `tool/render_app_icon.dart` 가 만든다.

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

시스템 "애니메이션 줄이기" 를 켜면 움직임을 빼고 바로 최종 상태를 보인다(작업 15). 화면은 시간을 `Motion.of(context, 토큰)` 으로 읽고(줄이기면 0), 컨트롤러로 돌리는 연출(레벨 업·배지 획득)은 `Motion.reduced(context)` 면 끝 값에 둔다.

- 화면 전환(Android): `AppPageTransitionsBuilder` — 들어오는 화면이 화면 높이 4% 아래에서 올라오며 나타난다(`enter` + `enterCurve`), 나갈 때 거꾸로(`exit` + `exitCurve`). 테마 `pageTransitionsTheme` 이 정해 `MaterialPageRoute` 를 그대로 쓴다. iOS 는 뒤로 밀기 제스처가 있는 기본 전환.
- 아래 시트(오늘 목표·끝부분 잘라내기): `showModalBottomSheet` 에 `sheetAnimationStyle: Motion.sheet(context)` — `enter` + `enterCurve` 로 올라오고 `exit` + `exitCurve` 로 내려간다. 애니메이션 줄이기면 바로 열리고 닫힌다(작업 21).
- 누름: 짧게 톡 눌러도 눌린 모양(0.97)이 `press` 동안 남는다(바로 떼면 한 프레임도 안 그려져 반응이 안 보였다). 애니메이션 줄이기면 붙잡지 않고 누른 동안만 눌린 모양이다(작업 18). 탭바 탭도 같은 `Pressable`.
- 첫 실행 장 넘김: `enter`/`exit` 교차 페이드. 레벨 업 커짐·배지 획득 튀어 오름: `celebrate` + `pop`.

## 다크 모드

시안에 없어 작업 10 에서 새로 설계했다. 반전하지 않고 같은 정체성을 지킨다.

- 바탕은 풀빛 어둠(`background` #10160D), 카드 `surface`·트랙 `surface-soft` 가 한 단계씩 밝아 테두리 없이 떨어진다.
- 연두 `primary` 와 `on-primary` 는 라이트와 같은 값. 연두 면은 다크 바탕 위에서 13:1 이라 경계선 없이도 또렷하고, 그림자는 거의 안 보이는 한 겹이다. 다크 흰 보조 버튼은 `surface` 와 `line` 머리카락 선으로 구분한다.
- 초록·코인·페이스·위험 색은 어두운 바탕에서 읽히도록 밝은 쪽으로 옮겼다. `panel` 은 밝은 판 + 짙은 글자.
- 무대는 어두운 풀빛 하늘·풀밭에 어두운 흙길·나무(다크 `ParkPalette`). 스프라이트는 `sprite-rim` 얇은 윤곽으로 무대에 묻히지 않게 한다(라이트는 투명). 윤곽 두께는 `max(1, round(배율/4))` 화면 px(8배 2px, 6배 2px, 3배 1px). 도트 1칸 두께는 굵어서 관문 3 에서 비교 B(얇게)를 골랐다(`design/mockups/phase-6/rim-compare.html`).

## 접근성

- 글자 대비 4.5:1 이상(24px 이상 3:1), 면 경계·그림 3:1 이상. 쌍마다 라이트·다크 측정값은 테스트가 확인한다.
- 채움 전용 쌍(글자로 쓰지 않는다): `stage-sky` 위 `ink-muted`, `surface-soft` 위 `primary-deep`(막대 채움은 그림 3:1 로 검사). `stage-sky` 위 `primary-deep` 은 24px 이상 큰 글자로만 쓴다. 무대 위 작은 글자는 `stage-ink`, 말풍선은 `bubble` 위 `ink`.
- 누를 수 있는 것은 48×48 이상.
- 시스템 글자 크기를 키워도 잘리지 않게, 고정 높이 안에 글자를 가두지 않는다.

## 입력·알림·상태 (작업 15)

- 입력칸: 테마 `inputDecorationTheme` — `surface` 채움, `line-strong` 2px 경계(바탕·카드 모두 3:1), 포커스 `primary-deep` 3px, 오류 `danger`, 모서리 `radius-md`, 도움말·글자 수 `caption` `ink-muted`. 커서·선택 손잡이 `primary-deep`(연두 커서는 흰 판 위에서 안 보인다).
- 스위치: 켜짐 연두 면(경계 없음, 손잡이가 오른쪽·`on-primary`), 꺼짐 `surface-soft` + `line-strong` 경계(테마 `switchTheme`).
- 스낵바: `panel` 판 + `on-panel` 본문, 화면 아래 띠(위 모서리만 `radius-md`), 그림자 없음.
- 진행 표시(불러오는 중): `primary-deep`.
- 빈 상태: `EmptyState`(앱 그림 + `ink-muted` 문구). 불러오기 실패: `EmptyState.error`(같은 카드에 느낌표 동그라미 `ink-muted`, 필요하면 `다시 시도` 버튼). 사용자가 고칠 문제가 아니라 `danger` 를 쓰지 않는다.
- 진짜 문제 알림(위치 신호 오류·러닝 저장 실패): `NoticeCard` — 흰 작은 카드에 `danger` 경계선·느낌표·`body-strong` 글자.

## 구현 메모 (작업 11~18)

- 구현 화면 스크린샷은 `design/mockups/phase-6-screens/`, 화면별 구성과 컴포넌트는 `docs/screens.md` "화면 디자인".

- 토큰 이름 변경: `cream` → `background`, `accent`/`on-accent` → `panel`/`on-panel`, `accent-deep` → `coin`(코인) 또는 없앰(립). `primary-deep` 은 이름은 같고 뜻이 "주황 립" 에서 "초록 강조" 로 바뀌었다.
- 공통 컴포넌트는 `lib/core/ui/components.dart`(작업 11, 옛 `clay.dart`): `AppCard`·`StatCard`·`StatsCard`(흰 카드 하나에 지표 칸 `StatCard.cell` 여러 개, 작업 12), `AppButton`(기본 연두·`.secondary` 흰·`.panel` 어두운 판, 경계선 없음), `AppChip`·`ChipRow`(칩·분할 선택 공통), `ProgressBar`, `CoinIcon`(코인 칩은 `lib/shop/ui/coin_chip.dart`), `AppTabBar`·`TabIcon`, `PetStage`·`StageBackdrop`·`SpeechBubble`, `Pressable`(누름 0.97), `ScreenTitle`, `CircleIconButton`(48 흰 동그라미 아이콘 버튼: 뒤로, 작업 14), `EmptyState`(흰 카드 + 앱 그림 + `ink-muted` 안내 문구, 작업 14. 넘기는 그림은 `EmptyState.iconSize` 40 으로 그린다), `NoticeCard`(진짜 문제 알림, 작업 15). 다이얼로그는 `AlertDialog` 를 그대로 쓰고(확인 버튼은 연두 면 + 옅은 그림자, 경계선 없음) 모양은 테마(`filledButtonTheme`·`textButtonTheme`·`dialogTheme`)가 정한다.
- `PetStage` 는 펫(`32 × scale`)을 발끝이 무대 아래에서 `groundHeight − Stage.footSink` 에 서게 놓는다(8배 땅 56 → 펫 상자 아래 32, 6배 땅 40 → 20). 배경은 `scene`(기본 `parkScene`)으로 바꾸고, 러닝 중에는 `moving: true`(작업 25). 펫 위끝이 무대 위끝에 닿는 높이는 `PetStage.fitHeight(scale:, groundHeight:)`(작업 18, 상점 무대·카드 미리보기가 쓴다).
- 옛 `Borders.thick`·`lip`·`lipPressed` 는 지웠다. 포커스 윤곽은 `Borders.focus` 3, 보조 버튼 머리카락 선은 `Borders.hairline` 1. 그림자는 `AppColors.floatShadow`(작업 31).

## 날씨 무대 (F25)

공원 무대(`parkScene`)는 받은 날씨에 따라 하늘 겹과 5번째 날씨 겹을 바꾼다(`parkSceneFor`, `lib/core/stage/park_scene.dart`). 색은 `WeatherPalette`(라이트·다크): 흐린 하늘·비 하늘·눈 하늘·구름·비구름·빗줄기·눈송이·별·달. 해 진 뒤는 테마와 상관없이 다크 토큰으로 그린다. 비·눈은 칸마다 하나씩 흩뿌리고 멈춰 있다(배터리). 공유 카드는 맑은 낮으로 고정한다.
