# 페이즈 6 구현 계획

- 상태: 실행
- 모드: 수동
- 범위: docs/roadmap.md 페이즈 6 디자인 완성 (6-1 캐릭터 에셋, 6-2 UI/UX 개편, 결정 0010·0019)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 캐릭터를 후보 3개 중 투표로 골라 3종·아이템·배지를 다시 그리고, UI 를 후보 3개 중 고른 방향으로 전 화면 개편해 출시해도 될 수준으로 만든다.

**Architecture:** UI 후보는 디자인 스킬(저장소 HTML)과 Claude Design 캔버스 두 트랙으로 같은 3방향을 만들어 6안 중 고른다. 두 단계에 사람이 고르는 관문이 셋 있다. 관문 1(작업 2): 캐릭터 투표. 관문 2(작업 9): UI 방향 선택. 관문 3(완료 기준): 출시 품질 승인. 관문에서는 멈추고 사용자에게 묻는다. 캐릭터는 지금처럼 코드 안의 픽셀 격자로 그린다(`tool/sprites/`, 사용자 결정 2026-10-22). 파일 이름·레이어·기준점 규격(`docs/specs/sprite-spec.md`)을 지키면 앱 코드는 그대로다. UI 는 토큰(`docs/design/tokens.json` → `lib/core/theme.dart`)과 공통 컴포넌트(`lib/core/ui/clay.dart`)를 먼저 바꾸고 화면을 그 위에 맞춘다.

**Tech Stack:** Flutter 3.47.7 (FVM), Dart 도구 스크립트(`image` 패키지, 개발 의존성), fonttools(글꼴 서브셋, 앱 의존성 아님)

**Spec:** `docs/roadmap.md` 페이즈 6, `docs/specs/sprite-spec.md`, `docs/design/design-system.md`, `docs/screens.md`, `design/mockups/README.md`, 무드보드 `design/references/`, 결정 0010·0011·0013·0019

## Global Constraints

- 캐릭터 그림은 코드 도트로 만든다. Aseprite·pixel-plugin·생성 AI·외주는 쓰지 않는다(2026-10-22 사용자 선택).
- 프레임은 32×32px, 발끝 y=29, 동작 프레임 수 idle 2·walk 4·run 4 를 유지한다. 파일 이름·레이어 순서는 sprite-spec 그대로다. 기준점이 바뀌면 sprite-spec 과 `PetKind` 기준점을 함께 고친다.
- 새 앱 패키지는 넣지 않는다. 앱 아이콘·스플래시는 도구 스크립트로 PNG·리소스를 만든다.
- 디자인 값은 `lib/core/theme.dart` 토큰만 쓴다. 화면에 HEX 를 직접 쓰지 않는다.
- 글자 대비는 4.5:1 이상(24px 이상 3:1), 누를 수 있는 것은 48×48 이상, 글자 13 미만 금지. 라이트·다크 둘 다.
- 문구는 바꾸지 않는다(한국어 존댓말 `-요` 체). 레이아웃·모양·그림만 바꾼다. 문구를 고쳐야 하면 계획 "자동 결정" 에 적는다.
- Nike 코드·리소스를 넣지 않는다. 무드보드 이미지는 방향 참고용이고 앱에 넣지 않는다.
- 후보 결과물은 `design/candidates/` 에 두고 작업 18 에서 지운다.
- 산출물은 아티팩트로 정리한다(2026-10-22 사용자 요청): 캐릭터 에셋 카탈로그(완료), UI 후보 비교(작업 8), 디자인 시스템(작업 10), 화면설계서(작업 19). 페이지 원본은 저장소에 두고 문서·HANDOFF 에 링크한다.
- Android 기준으로 확인한다. 명령은 `fvm flutter ...`, `fvm dart ...`.

## Review Focus

1. **레이어 어긋남**: 새 몸 그림에서 3종 × 4단계 모두 face·모자·소품이 같은 자리에 맞는다(걷기·달리기 프레임 포함). 테스트는 작업 3·4·5(`test/tool/sprite_data_test.dart` 확장).
2. **다크 모드와 대비**: 새 토큰이 라이트·다크 모두 대비 기준을 넘는다. 어두운 캐릭터가 다크 무대에 묻히지 않는다. 테스트는 작업 10(`test/core/theme_test.dart`).
3. **큰 글자**: 시스템 글자 1.3배·2배에서 새 컴포넌트·화면이 잘리거나 넘치지 않는다(360×640). 테스트는 작업 11~15.
4. **줄인 글꼴에서 빠진 글자**: 앱 문구의 모든 글자가 서브셋에 들어 있다. 사용자가 입력한 드문 글자(예: 이름)는 시스템 글꼴로 대신 보인다. 테스트는 작업 17.
5. **예전 러닝의 경로 색**: 구간이 0~1개인 러닝, 빠른 이동 구간이 있는 러닝도 경로가 그려진다(한 색으로). 테스트는 작업 13.

---

## 작업

### A. 6-1 캐릭터 에셋

- [x] 1. 캐릭터 후보 3개
  - 대상(셋 다 같음): 병아리 1~4단계 idle·run, 표정 normal. 장비는 결정 0013 그대로.
  - 후보
    - `a` 클레이 다듬기: 지금 비율 유지, 3단 명암(하이라이트·기본·그림자), 외곽선 정리, 달리기 동작 폭을 키움
    - `b` 큰 머리 다마고치: 머리 비중을 키우고 눈을 크게(반짝임 포함), 굵은 외곽선, 색 수를 줄임
    - `c` 플랫 마스코트(무드보드 `b`·`c`): 검은 외곽선 대신 몸색의 어두운 색 테두리, 단순한 도형, 선으로 그린 웃는 눈
  - 파일: `tool/sprites/candidates/{a,b,c}.dart`(새 파일), `tool/render_candidates.dart`(새 파일), `test/tool/candidate_sprite_test.dart`(새 파일), `docs/decisions/0028-design-assets.md`(새 파일)
  - 출력: `design/candidates/character/<a|b|c>/preview.png`(8배, 줄 = 단계, 칸 = idle·run 프레임), `run.gif`(2~4단계 달리기), `design/candidates/character/compare.png`(셋을 한 장에)
  - 결정 0028: 캐릭터 수단 = 코드 도트, 프레임 수 유지, 배지 그림 24×24, 앱 아이콘·스플래시는 도구 스크립트, 글꼴 서브셋은 fonttools
  - 테스트: 후보마다 프레임 형식(`validateFrame`), 발끝 y=29, 1~4단계 키 증가, idle 2·run 4 프레임이 서로 다름
  - 확인: `fvm flutter test test/tool`, `fvm dart run tool/render_candidates.dart`

- [x] 2. 관문 1: 캐릭터 투표
  - 후보 미리보기와 GIF 를 실은 투표 페이지를 아티팩트로 만든다(스킬: artifact-capabilities 로 투표 저장). 링크를 사용자에게 준다.
  - 사용자가 주변에 보여 주고 결과를 알려 줄 때까지 **멈춘다**. 고른 안과 표 수를 이 계획 "관문 기록" 에 적는다.
  - 스킬: artifact-design, artifact-capabilities

- [x] 3. 병아리 다시 그리기
  - 고른 안으로 `tool/sprites/chick.dart`(필요하면 `pet_art.dart` 팔레트·자세표)를 교체한다. 1~4단계 idle·walk·run, 표정 normal·sleepy·asleep, 1단계 알은 통통 튀기 유지.
  - 파일: `tool/sprites/chick.dart`, `tool/sprites/pet_art.dart`, `assets/sprites/chick/**`, `design/character/chick.png`, 기준점이 바뀌면 `docs/specs/sprite-spec.md`·`PetKind`
  - 테스트: 기존 `test/tool/sprite_data_test.dart` 전부 통과(face 가 4단계 몸 위, 발끝, 단계별 장비)
  - 확인: `fvm dart run tool/render_sprites.dart`, `fvm flutter test test/tool test/avatar`

- [x] 4. 젤리·도토리 다시 그리기
  - 작업 3 과 같은 그림체로 `tool/sprites/jelly.dart`·`acorn.dart` 교체. 종류별 특징(젤리 말랑한 몸, 도토리 모자)은 유지.
  - 파일: `tool/sprites/{jelly,acorn}.dart`, `assets/sprites/{jelly,acorn}/**`, `design/character/{jelly,acorn}.png`, `design/character/concepts.png`
  - 테스트·확인: 작업 3 과 같음

- [x] 5. 아이템 6개 다시 그리기
  - `cap`·`beanie`·`straw_hat`·`sunglasses`·`headphones`·`flower_pin` 을 새 그림체로. 3종 × 4단계 기준점에 맞춘다.
  - 작업 3·4 리뷰에서 넘어온 것: 모자가 4단계 머리·젤리 잎보다 좁아 옆으로 비어져 나옴(모자 폭을 넓힘), 도토리 4단계 헤어밴드가 한 줄이라 모자 테두리처럼 보임(병아리·젤리처럼 두 줄로), 젤리 4단계 잎 좌우 비대칭
  - 파일: `tool/sprites/items.dart`, `assets/sprites/*/{hat,accessory}/**`, `design/character/items.png`
  - 테스트: 아이템 세로 이동 = face 세로 이동, 모자가 눈을 가리지 않음(기존 테스트)
  - 확인: `fvm flutter test test/tool test/shop`

- [x] 6. 배지 그림 12개
  - 배지마다 24×24 도트 그림 하나. 업적 화면 격자·다음 배지 줄·요약 새 배지 줄의 자리표시 아이콘(`_iconFor`)을 그림으로 바꾼다. 못 받은 배지는 같은 그림을 회색·흐리게(`ColorFilter`, 투명도 0.45).
  - 파일: `tool/sprites/badges.dart`(새 파일), `tool/render_sprites.dart`, `assets/badges/<배지 id>.png`, `pubspec.yaml` assets, `lib/achievement/ui/badge_image.dart`(새 파일), `lib/achievement/ui/achievement_screen.dart`, `lib/run/ui/summary_screen.dart`, `docs/specs/sprite-spec.md` 배지 절
  - 테스트: `badgeCatalog` 의 모든 id 에 그림 데이터가 있음(24×24, 투명 배경), 위젯이 받은 배지는 컬러·못 받은 배지는 회색, `FilterQuality.none`
  - 확인: `fvm flutter test test/tool test/achievement test/run/ui`

### B. 6-2 UI/UX 개편

- [x] 7. UI 후보 시안 6개 (두 트랙 × 3방향, 2026-10-22 사용자 결정)
  - 홈·러닝 중·요약 3개 화면, 390px 폰 화면. 고른 캐릭터 PNG 를 넣는다. 라이트 기준, 같은 문구·같은 데이터.
  - 방향 3개(두 트랙 공통)
    - `a` 말랑 클레이 다듬기
    - `b` Taste Skill 이 뽑은 방향(트랙 1 에서 먼저 뽑아 트랙 2 에도 같은 방향을 준다)
    - `c` 무드보드 `design/references/` 방향: 밝은 연두·초록 포인트, 테두리 없는 둥근 카드, 큰 마스코트
  - 트랙 1, 디자인 스킬: `design/candidates/ui/skill/<a|b|c>/index.html`, 같은 폴더에 Chrome 헤드리스 스크린샷 `home.png`·`run.png`·`summary.png`
    - 스킬: ui-ux-pro-max:ui-ux-pro-max (a·c), taste-skill:design-taste-frontend (b)
  - 트랙 2, Claude Design: Design 캔버스 아티팩트 하나에 방향별 3개 화면 아트보드 9개. 페이즈 2.5 디자인 시스템 아티팩트(`docs/design/design-system.md` 의 링크)를 출발점으로 쓴다. 아트보드 사본(HTML)과 스크린샷을 `design/candidates/ui/canvas/<a|b|c>/` 에 남긴다
    - 스킬: Artifact quickstart(design), artifact-design
  - 두 트랙은 파일이 겹치지 않아 동시에 진행한다.
  - 확인: 두 트랙 × 세 방향 모두 화면 3장, 폭 390 에서 가로 스크롤 없음

- [x] 8. 후보 비교
  - Impeccable `critique` 로 6안을 같은 기준(한눈에 읽힘, 위계, 일관성, 접근성, AI 티)으로 비교한다. 결과 `design/candidates/ui/critique.md`.
  - 방향별로 두 트랙 안을 나란히 놓은 비교 페이지를 아티팩트로 만들어 링크를 준다.
  - 스킬: impeccable:impeccable, artifact-design

- [x] 9. 관문 2: UI 방향 선택
  - 사용자가 6안 중 고를 때까지 **멈춘다**(조합 선택 가능, 예: a 방향의 캔버스 안). 고른 안과 고칠 점을 "관문 기록" 에 적는다.

- [x] 10. 디자인 시스템 갱신
  - 고른 방향으로 `docs/design/tokens.json`·`docs/design/design-system.md`·`lib/core/theme.dart` 를 고친다. 라이트·다크.
  - Claude Design System 아티팩트도 새 토큰·컴포넌트로 갱신하고 `design-system.md` 의 원본 링크를 고친다.
  - 새로 정할 것: 코인 색(지금 `accent-deep` 차용), 경로 페이스 색 3단(느림·보통·빠름), 배경(무늬·그라데이션 여부), 화면 전환 시간·곡선 토큰
  - 테스트: `test/core/theme_test.dart` 에 새 토큰의 대비(글자·바탕 쌍마다 4.5:1, 큰 글자 3:1), 다크 값 존재
  - 확인: `fvm flutter test test/core`
  - 스킬: ui-ux-pro-max:ui-ux-pro-max

- [x] 11. 공통 컴포넌트
  - `lib/core/ui/clay.dart` 의 버튼·카드·칩·진행 막대·다이얼로그·탭바·코인 칩을 새 시스템으로. 누름 반응(눌림·되돌아옴) 포함. 화면 배경 위젯.
  - 파일: `lib/core/ui/clay.dart`(이름이 방향과 맞지 않으면 `components.dart` 로 바꾸고 import 정리), `lib/shop/ui/coin_chip.dart`, `test/core/ui/`
  - 테스트: 컴포넌트별 최소 48×48, 글자 2배에서 넘침 없음, 다크 테마, 눌림 상태
  - 확인: `fvm flutter test test/core`

- [x] 12. 홈·러닝 중·일시정지
  - 고른 시안대로 `home_screen.dart`·`run_goal_picker.dart`·`in_run_screen.dart` 개편. 거리 숫자가 가장 크다는 원칙 유지.
  - 테스트: 기존 화면 테스트 통과, 360×640·글자 1.3배 넘침 없음, 다크 테마
  - 확인: `fvm flutter test test/run`

- [x] 13. 요약·경로 페이스 색·공유 카드
  - 요약 화면 개편(`summary_screen.dart`, `split_pace_chart.dart`).
  - 경로 색: 경로 점을 누적 거리로 1km 구간에 나누고, 구간 페이스를 이 러닝의 가장 느린·빠른 구간 사이에서 3단 색으로 칠한다. 구간이 1개 이하이거나 모든 구간이 같으면 한 색(`primary-deep`, 결정 0029 뒤 이름). 빠른 이동 구간은 `ink-muted`.
    - `List<RouteSegment> routePaceSegments(List<(double, double)> points, List<Split> splits)` — `lib/run/domain/route_pace.dart`(새 파일), `RouteSegment { List<(double, double)> points; RoutePace pace; }`, `enum RoutePace { slow, mid, fast, fastMove, single }`
    - `RoutePainter` 가 구간마다 토큰 색으로 그린다.
  - 공유 카드(`share_card.dart`) 디자인: 새 시스템, 경로 페이스 색 포함, 1080×1350 유지.
  - 테스트: `routePaceSegments` — 구간 0·1·3개, 같은 페이스, 빠른 이동 구간, 구간 경계에서 선이 끊기지 않음(앞 구간 끝점 = 다음 구간 첫 점). 화면: 넘침·다크.
  - 확인: `fvm flutter test test/run`

- [x] 14. 기록·아바타·업적·상점·코인 내역
  - `history_screen.dart`·`stats_chart.dart`·`avatar_screen.dart`·`achievement_screen.dart`·`shop_screen.dart`·`coin_history_screen.dart` 개편.
  - 테스트·확인: 작업 12 와 같은 기준, `fvm flutter test`

- [ ] 15. 첫 실행·설정·권한, 빈 상태·오류 화면
  - `onboarding_screen.dart`·`settings_screen.dart`·`permission_screen.dart`, 기록 없음·코인 내역 없음·위치 신호 오류·백업 실패 등 빈 상태·오류 표시를 새 시스템으로 맞춘다.
  - 화면 전환·레벨업·배지 획득 애니메이션을 토큰 시간으로 정리한다. 시스템 "애니메이션 줄이기" 를 켜면 움직임을 뺀다(`MediaQuery.disableAnimations`).
  - 테스트: 빈 상태 화면 렌더, 애니메이션 줄이기에서 즉시 최종 상태, 넘침·다크
  - 확인: `fvm flutter test`

- [ ] 16. 앱 아이콘·스플래시
  - 고른 캐릭터와 색으로 아이콘을 만든다. `tool/render_app_icon.dart`(새 파일)가 Android `mipmap-*/ic_launcher.png`, 적응형 아이콘(전경·배경 + `mipmap-anydpi-v26/ic_launcher.xml`), iOS `AppIcon.appiconset`, 스플래시 그림을 쓴다.
  - 스플래시: `launch_background.xml`(라이트·다크), Android 12 이상 `values-v31`·`values-night-v31` 의 `windowSplashScreen*`. 바탕은 `background` 토큰 값(결정 0029 뒤 이름).
  - 테스트: 도구 출력 크기(48·72·96·144·192, iOS 1024 포함), 투명 여백 비율(적응형 안전 영역 66%)
  - 확인: `fvm dart run tool/render_app_icon.dart`, `fvm flutter build apk --debug`

- [ ] 17. 글꼴 줄이기
  - Pretendard 가변 글꼴(결정 0029)을 KS X 1001 한글 2,350자 + 영문·숫자·기호 + 앱 문구에 쓰인 모든 글자로 서브셋한다(굵기 축 유지).
  - `tool/subset_fonts.py`(새 파일, fonttools, 실행 방법을 맨 위 주석에), `tool/font_chars.txt`(생성), `assets/fonts/*`
  - 테스트: `test/tool/font_chars_test.dart` — `lib/**.dart` 문자열 리터럴의 모든 글자가 `font_chars.txt` 에 있음
  - 확인: 글꼴 두 파일 합계 4MB 이하, `fvm flutter build apk --debug` 크기가 줄어듦(전후 값을 계획에 적는다)

- [ ] 18. 정리
  - 고른 안을 `design/character/`·`design/mockups/`(`phase-6-screens/` 스크린샷, README 갱신)·`docs/design/tokens.json` 에 반영하고 `design/candidates/` 와 후보 도구 코드(`tool/sprites/candidates/`, `tool/render_candidates.dart`, `tool/render_ui_candidate_pets.dart`, 해당 테스트)를 지운다.
  - 캐릭터 에셋 카탈로그 아티팩트(https://claude.ai/artifact/ECbG2Fh4TXQwcr5fNUWCXA, 원본 `design/character/asset-catalog.html`)를 최종 그림으로 다시 올린다
  - 문서: `docs/design/design-system.md`, `docs/specs/sprite-spec.md`(만드는 방법·배지), `docs/screens.md`, `docs/tooling.md`(pixel-plugin 6-1 사용 시점을 "쓰지 않음(결정 0028)" 으로, Impeccable·Taste Skill 사용 기록), `CLAUDE.md` 문서 지도
  - 확인: `fvm dart analyze`, `fvm flutter test`

- [ ] 19. 화면설계서 아티팩트
  - 최종 앱 화면으로 포트폴리오 수준의 화면설계서를 만든다(2026-10-22 사용자 요청). 품질 기준: `design/references/screen-board-hifi.jpg`(모든 화면을 폰 아트보드 격자로), `design/references/screen-board-wireframe.png`(같은 화면의 저충실도 와이어프레임 보드).
  - 화면 수집: 에뮬레이터에서 예시 데이터로 모든 화면·상태를 찍는다(라이트, 대표 화면은 다크도). 첫 실행 1·2, 권한 안내, 홈(거리·시간 목표, 직접 입력), 러닝 중(목표 달성, 자동 일시정지), 일시정지, 요약(레벨업, 목표 달성·미달, 새 배지, 잘라내기, 공유 카드), 기록(주·월·년·전체, 빈 상태), 기록 상세, 아바타, 업적, 상점(구매 확인, 코인 부족), 코인 내역, 설정, 러닝 알림·종료 예고 알림.
  - 구성
    1. 표지·개요: 앱 한 줄 소개, 화면 수, 디자인 원칙, 디자인 시스템 링크
    2. 전체 화면 보드: 흐름 순서로 묶은 폰 아트보드 격자(고충실도)
    3. 화면 흐름도: 화면 사이 이동(`docs/screens.md` 흐름 기준)
    4. 화면별 상세: 화면 + 번호 붙인 요소 설명, 요구사항 ID(F1~F21), 상태 변형, 인터랙션
    5. 와이어프레임 보드: 같은 화면을 회색 블록으로 단순화한 저충실도 보드
    6. 컴포넌트·상태 모음: 버튼·카드·칩·막대·빈 상태·오류
  - 파일: `design/screens/`(스크린샷, 페이지 원본), `docs/screens.md` 에 링크
  - 스킬: artifact-design (필요하면 Design 캔버스)
  - 확인: 위 화면 목록이 모두 보드에 있음, 폰 폭 390 에서 가로 스크롤 없음, 라이트·다크

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 전부 통과, `fvm dart analyze` 0건
- [ ] `fvm flutter build apk --debug` 성공, APK 크기가 페이즈 5 대비 줄어듦(글꼴)
- [ ] `fvm dart run tool/render_sprites.dart`·`tool/render_app_icon.dart` 를 다시 돌려도 저장소에 변경 없음
- [ ] 화면에 HEX 직접 사용 없음(`lib/**/ui` 에서 `Color(0x` 검색 0건, 테마 파일 제외)

### E2E (에뮬레이터, `/e2e` 가 확인)
- [ ] 런처에 새 앱 아이콘, 실행 때 새 스플래시가 보인다
- [ ] 첫 실행 → 홈 → 가상 러닝(5분) → 요약까지 새 디자인으로 보이고, 요약 경로가 구간 페이스 색으로 그려진다
- [ ] 러닝 중 아바타가 새 그림으로 달리고, 상점에서 아이템을 입히면 새 아이템 그림이 머리에 맞는다
- [ ] 업적 화면 배지 12개가 그림으로 보이고 받은 배지만 색이 켜진다
- [ ] 공유 카드가 새 디자인으로 만들어진다
- [ ] 다크 모드에서 홈·러닝 중·요약이 읽힌다, 한글에 빈 네모(두부)가 없다

### 사람 확인
- [x] 관문 1: 캐릭터 후보 투표로 고름 (작업 2) — A
- [x] 관문 2: UI 후보 중 고름 (작업 9) — c · 캔버스(사각 무대)
- [ ] 관문 3: 바뀐 디자인을 출시 품질로 승인 (화면설계서 아티팩트 기준)
- [ ] 실기기(Android·iPhone)에서 아이콘·스플래시·글꼴·화면 확인 (페이즈 7)

## 관문 기록
- 관문 2 비교 페이지: https://claude.ai/artifact/F5MsvhPE9fAXw5YtCwe3Xc (critique `design/candidates/ui/critique.md`). 추천 b · 캔버스(27/30), 차선 a · 스킬(23). 결과: **c · 캔버스 확정**(2026-10-22 사용자, 결정 0029). 사용자가 c · 캔버스에 관심, 요청으로 c 의 연두 원을 사각 무대(하늘+땅 띠)로 바꿈(배경 아이템 확장 대비, 2026-10-22). 원래 모양은 커밋 206afd5. 함께 고칠 점: `$` 코인 아이콘 → 앱 코인, 선택 표시 하나로(분할 48 높이), 연두 버튼 면 경계, 배지 `코인 +200` 강조, 탭 아이콘 앱 고유, 다크 모드 새 설계, 글꼴 Pretendard
- UI 후보 캔버스(트랙 2): https://claude.ai/artifact/FxKS7MR2twYmmE3k6SzNhe
- 관문 1 투표 페이지(2026-10-22): https://claude.ai/artifact/SBshrAFUGtLfBbaLHQxMnb . 저장 기능 없음(db 아티팩트는 조직 내부 전용이라 외부 사람이 못 엶). 고르면 `런마고치 캐릭터: A/B/C` 문구가 나오고 사용자가 표를 모은다. 결과: **A 말랑 클레이 확정**(2026-10-22 사용자). 기준점은 지금 값(모자 y=18, 소품 y=20) 유지

## 자동 결정
- 작업 14(시안 없는 화면): 상점 무대 6배(아바타 8배), 업적 배지 48→72, 코인 내역 `+N` 색 coin, 아바타 성장 단계 `달성` 글자 primaryDeep, 기록 기간 화살표 48 동그라미, 쓴 코인 줄에도 CoinIcon(ink).
- 작업 13: 경로 페이스 색 범례 문구 `느림`·`보통`·`빠름`·`빠른 이동` 을 새로 넣었다. 문구 유지 원칙의 예외로, 3색 경로는 범례 없이는 읽을 수 없어서다. 관문 3 에서 함께 본다.
- 작업 5: 1단계 알에 모자가 커 보이는 점(버섯처럼 보임)은 그대로 둔다. 아이템 파일 경로에 단계가 없어 단계별 그림을 쓰려면 앱 코드를 바꿔야 한다. 관문 3 에서 사용자가 보고 고칠지 정한다(고치면 `itemSheet` 에 단계를 넣고 1단계 작은 모자를 그린다).
