# 페이즈 2.5 구현 계획

- 상태: 계획
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 2.5 (결정 0010)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 무료 수단만으로 MVP 화면 6개와 캐릭터를 기본 품질로 디자인하고 앱에 적용한다.

**Architecture:** 디자인은 먼저 Claude 아티팩트(Design System, Design 캔버스)에서 사용자 승인을 받고, 승인본을 저장소의 `design/` 와 `docs/design/` 에 내보낸다. 앱은 승인된 토큰을 `lib/core/theme.dart` 한 곳에서 읽는다. 캐릭터는 Dart 데이터(팔레트 + 프레임별 픽셀 격자)로 그려 도구가 PNG 시트로 렌더링한다. 규격(32×32, idle 2·walk 4·run 4)과 파일 경로는 그대로라 앱 코드는 바뀌지 않는다.

**Tech Stack:** Flutter 3.47.7 (FVM), Material 3 `ThemeData`, Google Fonts 의 OFL 글꼴을 에셋으로 번들(네트워크 없이 동작), `image`(개발용 PNG 렌더링)

**Spec:** `docs/roadmap.md` 페이즈 2.5, `docs/screens.md`(UX 원칙), `docs/specs/sprite-spec.md`, 와이어프레임 `design/wireframes/png/01·03·04·05·06·07·09`

## Global Constraints

- 무료 수단만 쓴다. 유료 도구·생성 AI 는 페이즈 6.
- 네트워크 없이 동작: 글꼴은 `google_fonts` 런타임 다운로드 대신 OFL 글꼴 파일을 `assets/fonts/` 에 넣고 `pubspec.yaml` 에 등록한다. 라이선스 파일을 함께 넣는다.
- 디자인 값(색·글꼴·크기·간격·모서리)은 `lib/core/theme.dart` 에만 둔다. 화면 코드에 색 리터럴(`Color(0x…)`, `Colors.xxx`)을 새로 쓰지 않는다.
- UX 원칙(`docs/screens.md`) 유지: 시작은 한 번의 탭, 러닝 중엔 거리 숫자가 가장 크게, 길게 눌러 종료, 남은 양 진행 막대, 벌주지 않는 아바타.
- 기존 테스트의 문구·동작은 유지한다. 바뀌는 건 모양뿐이다. 문구를 바꿔야 하면 시안 승인 때 함께 정하고 테스트를 고친다.
- 스프라이트 규격·경로는 바꾸지 않는다. face 레이어는 4단계 공용이므로 모든 단계의 머리·눈 위치가 같아야 한다.
- 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **다크 모드·큰 글자**: 시스템 글자 크기 1.3배에서 홈·러닝 중·요약이 넘치지 않는다. 테스트는 Task 5·6.
2. **러닝 중 가독성**: 거리 숫자가 다른 어떤 글자보다 크고, 배경과 대비가 충분하다(4.5:1 이상). 테스트는 Task 5.
3. **색 리터럴 누수**: 화면 파일에 색 리터럴이 남지 않는다. 확인은 Task 7 의 grep 검사.
4. **오프라인 글꼴**: 비행기 모드에서도 지정 글꼴로 그려진다(번들 글꼴). 확인은 Task 4.
5. **스프라이트 정렬**: 4단계 body 와 공용 face 가 모든 프레임에서 어긋나지 않는다. 테스트는 Task 8.

---

## 작업

- [ ] 1. 디자인 방향과 디자인 시스템 (사용자 승인)
- [ ] 2. 화면 시안 6개 (사용자 승인)
- [ ] 3. 캐릭터 콘셉트 (사용자 승인)
- [ ] 4. 앱 테마 적용
- [ ] 5. 홈·러닝 중·일시정지 화면
- [ ] 6. 요약·기록 화면
- [ ] 7. 아바타 탭·주간 목표·권한 화면
- [ ] 8. 캐릭터 스프라이트 완성

### Task 1: 디자인 방향과 디자인 시스템

컨트롤러가 사용자와 직접 진행한다(서브에이전트 아님).

- 스킬: `ui-ux-pro-max:ui-ux-pro-max`, `ui-ux-pro-max:design-system`
- [ ] **Step 1:** 앱 성격(러닝 + 도트 육성, 한국어, 야외에서 한눈에)에 맞는 방향 2~3안을 `ui-ux-pro-max` 로 고른다. 각 안: 분위기 한 줄, 주색·보조색·배경·텍스트 색, 글꼴(본문·숫자·도트 포인트), 모서리·그림자 원칙.
- [ ] **Step 2:** 안들을 Claude Design System 아티팩트로 만들어 보여주고 하나를 고르게 한다. 고른 안을 다듬어 승인받는다.
- [ ] **Step 3:** 승인본을 `docs/design/design-system.md` 로 내보낸다: 색 토큰(라이트·다크, 이름과 HEX), 타이포 스케일(이름·크기·굵기·용도), 간격 스케일, 모서리, 컴포넌트 규칙(버튼·카드·진행 막대·탭바·다이얼로그). 글꼴 이름과 라이선스. 아티팩트 링크.
- [ ] **Step 4:** `CLAUDE.md` 문서 지도에 `docs/design/design-system.md` 를 추가하고 커밋한다.

### Task 2: 화면 시안 6개

컨트롤러가 사용자와 직접 진행한다.

- 스킬: `ui-ux-pro-max:ui-ux-pro-max`
- [ ] **Step 1:** Design 캔버스에 Task 1 시스템으로 홈, 러닝 중, 일시정지, 러닝 요약(경험치·레벨업 포함), 기록, 아바타 탭 아트보드를 만든다. 와이어프레임 배치와 현재 앱 문구를 따른다. 코인·상점·옷장·업적은 넣지 않는다.
- [ ] **Step 2:** 사용자 승인. 수정 요청은 캔버스에서 고친다.
- [ ] **Step 3:** 승인본을 `design/mockups/` 에 내보낸다(아티팩트 HTML 과 화면별 PNG 캡처). 화면마다 구현 메모(사용 토큰, 바뀌는 문구)를 `design/mockups/README.md` 에 적는다. 커밋.

### Task 3: 캐릭터 콘셉트

컨트롤러가 사용자와 직접 진행한다.

- [ ] **Step 1:** `tool/sprites/` 에 캐릭터를 Dart 데이터로 정의하는 형식을 만든다: 팔레트(문자 → 색), 프레임마다 32줄 × 32문자 격자. 렌더러 `tool/render_sprites.dart` 가 격자를 규격 PNG 시트로 만든다(Task 2 의 기존 생성기를 대체).
- [ ] **Step 2:** 디자인 시스템 색에 맞춘 콘셉트 2~3안의 1단계 idle 2프레임을 그리고, 8배 확대 미리보기 PNG 를 만들어 보여준다. 고른 안을 4단계 외형(알·새싹 → 어린 러너 → 러너 → 마라토너)의 idle 정지 프레임까지 확장해 승인받는다.
- [ ] **Step 3:** 승인 콘셉트를 `design/character/` (미리보기 PNG, 설명) 에 남기고 커밋한다.

### Task 4: 앱 테마 적용

**Files:**
- Create: `lib/core/theme.dart`, `assets/fonts/*` (+ 라이선스), `test/core/theme_test.dart`
- Modify: `pubspec.yaml`(fonts), `lib/app.dart`

**Interfaces:**
- Produces: `ThemeData appLightTheme()`, `ThemeData appDarkTheme()`, 간격 상수 `class Gap { static const double xs, s, m, l, xl; }`, 화면에서 쓰는 추가 토큰은 `ThemeExtension<AppColors>`(예: 아바타 무대 배경, 진행 막대 트랙)

- [ ] **Step 1:** 실패하는 테스트: 두 테마의 `colorScheme.primary`·`surface`·`onSurface` 가 `docs/design/design-system.md` 의 HEX 와 같다. 본문 글꼴 family 가 번들 글꼴 이름이다. `AppColors` 확장이 두 테마에 있다. `onSurface`/`surface` 대비가 4.5 이상이다.
- [ ] **Step 2:** FAIL 확인 → 구현 → PASS. `MaterialApp` 에 `theme`·`darkTheme`·`themeMode: ThemeMode.system`.
- [ ] **Step 3:** `fvm flutter test`·`fvm dart analyze`·`fvm flutter build apk --debug` 통과, 커밋.

### Task 5: 홈·러닝 중·일시정지 화면

**Files:** Modify `lib/run/ui/home_screen.dart`, `lib/run/ui/in_run_screen.dart`, `lib/avatar/ui/weekly_goal_bar.dart`. Test: 기존 화면 테스트 + 새 테스트.
- [ ] **Step 1:** 실패하는 테스트: 글자 크기 1.3배(`MediaQuery` `textScaler`)에서 홈·러닝 중·일시정지가 overflow 없이 그려진다. 러닝 중 거리 글자가 가장 크다(기존 테스트 유지). 시안 메모에 적힌 새 요소가 있으면 그 문구가 보인다.
- [ ] **Step 2:** `design/mockups/` 의 해당 시안과 `README.md` 메모대로 구현한다. 색·크기는 `theme.dart` 토큰만 쓴다.
- [ ] **Step 3:** 테스트·분석 통과, 커밋.

### Task 6: 요약·기록 화면

**Files:** Modify `lib/run/ui/summary_screen.dart`, `lib/avatar/ui/growth_summary.dart`, `lib/run/ui/history_screen.dart`, `lib/run/ui/route_painter.dart`(선 색을 토큰으로)
- [ ] **Step 1:** 실패하는 테스트: 글자 크기 1.3배에서 overflow 없음. 시안 메모의 새 요소.
- [ ] **Step 2:** 시안대로 구현, 토큰만 사용. 테스트·분석 통과, 커밋.

### Task 7: 아바타 탭·주간 목표·권한 화면

**Files:** Modify `lib/avatar/ui/avatar_screen.dart`, `lib/run/ui/permission_screen.dart`, `lib/app.dart`(탭바)
- [ ] **Step 1:** 실패하는 테스트: 글자 크기 1.3배에서 overflow 없음. 시안 메모의 새 요소.
- [ ] **Step 2:** 시안대로 구현. 테스트·분석 통과.
- [ ] **Step 3:** 색 리터럴 검사: `grep -rnE "Color\(0x|Colors\.[a-z]" lib --include=*.dart | grep -v lib/core/theme.dart` 결과가 비어 있다(투명 `Colors.transparent` 만 예외). 커밋.

### Task 8: 캐릭터 스프라이트 완성

**Files:** Modify `tool/sprites/*`, `assets/sprites/body/*`, `assets/sprites/face/*`, `docs/specs/sprite-spec.md`(만드는 방법). Test: `test/avatar/ui/sprite_assets_test.dart`, 새 `test/tool/sprite_data_test.dart`
- [ ] **Step 1:** 실패하는 테스트(`sprite_data_test`): 모든 프레임 격자가 32×32 이고 팔레트에 없는 문자가 없다. 4단계 모두 눈 영역(face 레이어가 칠하는 픽셀 좌표)이 body 의 머리 안쪽에 있다. 각 동작의 프레임끼리 서로 다르다(빈 애니메이션 방지). 발끝 최하단 불투명 픽셀이 y=29 다.
- [ ] **Step 2:** Task 3 승인 콘셉트로 4단계 × (idle 2, walk 4, run 4) body 와 3표정 × 3동작 face 를 그린다. `fvm dart run tool/render_sprites.dart` 로 PNG 를 만든다.
- [ ] **Step 3:** 테스트·분석 통과. 8배 확대 미리보기를 컨트롤러가 보고 확인한 뒤 커밋.

---

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 전체 통과
- [ ] `fvm dart analyze` 경고 0
- [ ] `fvm flutter build apk --debug` 성공
- [ ] 화면 파일 색 리터럴 검사 통과 (Task 7 Step 3)

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 홈·러닝 중·일시정지·요약·기록·아바타 탭이 `design/mockups/` 승인 시안과 같은 배치·색으로 보인다(스크린샷 대조)
- [ ] 새 캐릭터가 홈(idle), 러닝 중(가상 러닝 중 run), 아바타 탭(4단계 미리보기)에 어긋남 없이 보인다
- [ ] 페이즈 2 E2E 5개 시나리오가 그대로 통과한다(가상 러닝 → 경험치 → 레벨 막대, 목표 변경 → 달성)
- [ ] 시스템 다크 모드로 바꿔도 화면이 읽힌다

### 사람 확인
- [ ] 디자인 시스템 승인 (Task 1)
- [ ] 화면 시안 승인 (Task 2)
- [ ] 캐릭터 콘셉트 승인 (Task 3)
- [ ] 실기기에서 최종 모습 확인

## 자동 결정

없음
