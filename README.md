# runmagochi

실제 러닝 기록(GPS·페이스)에 도트 아바타 육성을 더한 Android·iOS 러닝 앱. 달릴수록 캐릭터가 자라고, 오래 쉬면 졸린 표정을 짓는다. 서버 없이 기기 안에서 동작한다.

`runmagochi` 는 개발 코드명이다.

## 시작하기

1. 저장소를 clone한다.
2. 저장소 폴더에서 Claude Code를 연다.
3. 폴더 신뢰(trust) 확인 창에서 신뢰를 선택한다.
4. `/kickoff` 를 실행한다. 현황 브리핑을 보고 이 PC에서 쓸 플러그인을 고른다.
5. `/phase` 로 현재 페이즈를 진행한다. `/phase --auto` 는 계획 승인 없이 자동으로 진행한다.

## 문서

| 문서 | 내용 |
| --- | --- |
| [기획서](docs/product.md) | 목표, 요구사항, 사용자 시나리오 |
| [로드맵](docs/roadmap.md) | 페이즈별 범위와 완료 기준, 현재 위치 |
| [설계서](docs/architecture.md) | 기술 스택, 구조, 데이터 모델, 서버 이전 경로 |
| [화면설계](docs/screens.md) | MVP 화면, 이동 흐름, UX 원칙 |
| [기록 엔진 명세](docs/specs/run-engine.md) | GPS 처리, 거리·페이스 계산 규칙 |
| [게임 규칙 명세](docs/specs/game-rules.md) | 경험치·레벨·외형 단계 수치 |
| [결정 기록](docs/decisions/) | 주요 결정과 근거 |
| [와이어프레임](design/wireframes/README.md) | 화면 콘티 |
| [개발 도구](docs/tooling.md) | Claude Code 추천 플러그인과 사용 시점 |

## 빌드·실행

Android SDK 플랫폼 37 과 [FVM](https://fvm.app) 이 필요하다. Flutter 버전은 `.fvmrc` 로 고정돼 있다(결정 0008). 처음 한 번 `fvm install` 을 실행한다.

```
fvm flutter pub get
fvm dart run build_runner build
fvm flutter run
```
