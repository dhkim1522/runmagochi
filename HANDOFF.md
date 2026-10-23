# 작업 인계

> 다른 PC나 다음 세션에서 바로 이어서 할 수 있도록 현재 상태와 다음 할 일을 적는다. 작업을 마칠 때마다 교체한다.

## 현재 상태

- **페이즈 8 산출물 정리 구현 완료, 사람 확인 대기** (`docs/plans/phase-8.md`, 상태 `실측 대기`, 2026-10-24).
- 산출물 12종이 모두 있다: [현황표](docs/portfolio.md). 화면 64컷 전체 재촬영, README 스크린샷 6장, 문서 지도 갱신 완료.
- 자동 검증: `fvm flutter test` 1,372개 통과, `fvm dart analyze` 문제 없음, 디버그 APK 빌드 통과(`build/app/outputs/flutter-apk/app-debug.apk`), mermaid 문법 검사 전부 통과, 문서 상대 링크 끊김 0.
- 아티팩트: [포트폴리오 보드](https://claude.ai/artifact/HmkBwrBFQa5DFWq6mdRrpf), [화면설계서 8판](https://claude.ai/artifact/456dWcNyLn1vbUsjV9FLVc). 둘 다 비공개라 공유하려면 페이지의 공유 메뉴에서 연다.
- 에뮬레이터 `runmagochi` 는 켜져 있고 디버그 APK 설치됨(예시 데이터 젤리 Lv.9).

## 사람 확인 (다음 `/phase 8` 이 완료 판정)

- [ ] 산출물 12종을 포트폴리오로 쓸 수 있는 수준으로 승인
- [ ] 문서가 앱 동작과 맞는지 표본 확인(시퀀스 또는 ERD 중 하나)
- [ ] README 러닝 GIF: ffmpeg·adb 가 PATH 에 없어 만들지 못했다. 넣을지 정하고, 넣으면 도구를 설치해 녹화(≤2MB)
- 13c(위치 서비스 꺼짐) 컷에서 버튼에 진한 테두리가 한 번 보임. 일시적 포커스 표시로 추정, 실기기에서 확인(페이즈 9)

## 다음

- 완료 판정 뒤 페이즈 9(실기기 테스트, `docs/field-test.md`). 아이템 그림 검토를 하면 상점·꾸미기 컷은 다시 찍는다.
- mermaid 검사 도구는 스크래치패드 밖이라 세션마다 사라진다. 다이어그램을 고치면 mermaid-cli 로 다시 검사할 것.
