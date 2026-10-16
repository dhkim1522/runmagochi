# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- 페이즈 0 준비 단계
- 원천 문서 정리 완료: 기획서, 로드맵, 설계서, 화면설계, 명세 2종, 결정 4건, 와이어프레임, 검토 보고
- 결정 완료: 로컬 우선, 원천 문서 저장소 보관, 보상(코인·상점·업적) 후속, Flutter 채택(Flame 없음), Android 먼저·iOS는 페이즈 3
- 페이즈 1~6 구성과 완료 기준 확정 (`docs/roadmap.md`)
- 기획·기술 스택 검토(`docs/research/plan-review.md`)의 핵심 권고 반영: MVP 화면 6개, 하단 탭 3개, 지도 대신 경로 선, 경로 압축 저장, 아바타 상태 반응 추가
- 코드 없음

## 다음 할 일

1. Flutter 프로젝트를 생성하고 Android 에뮬레이터에서 빌드·실행을 확인한다.
2. 페이즈 1 기록 코어에 착수한다. 범위와 완료 기준은 `docs/roadmap.md` 페이즈 1.
   - 기록 엔진(`docs/specs/run-engine.md`)과 단위 테스트를 먼저 만든다.

## 환경 메모

- 회사 Mac: `~/personal/` 아래에서 git·gh 가 개인 계정(dhkim1522)으로 자동 전환된다.
- 집 Windows: Claude Code 개인 계정 로그인, 개인 SSH 키를 GitHub에 등록한 뒤 이 저장소를 clone한다. 저장소 안에서 `git config user.email dhkim1522@naver.com` 을 설정한다.
- Android 에뮬레이터 가상 GPS: `adb emu geo fix <경도> <위도>` 를 1초마다 보내 러닝을 흉내 낸다.
