# runmagochi

> 실제 러닝 기록(GPS·페이스)에 도트 아바타 육성을 더한 Android·iOS 러닝 앱. 달릴수록 캐릭터가 자라고, 받은 코인으로 러닝 옷·장비를 사서 꾸민다.

`runmagochi` 는 개발 코드명이다. 정식 앱 이름은 출시 전 상표 확인 후 정한다 (다마고치 상표 유사 우려).

## 문서

- [통합 문서](https://claude.ai/code/artifact/0ac0d5b6-7b0b-4143-bda1-3ab9f9850a8c) — 목표, 요구사항(F1~F15), 시나리오, 작업 계획
- [와이어프레임](https://claude.ai/artifact/GGgUf6VGKuK3AkSRxrEnoQ) — 핵심 화면 10개, NRC 도출 UX 원칙
- [설계·개발 정의서](https://claude.ai/code/artifact/402308db-95f5-44a0-ad9c-6ca1d8111d2d) — 기술 스택, 아키텍처, 기록 엔진, 게임 규칙, 데이터 모델, 작업 체크리스트
- `docs/nrc-analysis.md` — Nike Run Club 기술 구조 분석 요약

문서가 원본이다. 결정이 바뀌면 문서를 고치고, 이 파일에는 결정 결과만 남긴다.

## 결정사항

- 플랫폼: Android + iOS, 하나의 코드베이스
- 기록은 기기에서, 보상(코인·경험치) 계산은 서버에서 한다
- 성장 단계는 누적 거리 기준 4단계 (0~50km, 50~250km, 250~1,000km, 1,000km 이상)
- 하단 탭 4개: 러닝, 기록, 아바타, 상점

## 미결정

- 개발 프레임워크: Flutter(추천) 또는 React Native
- 도트 아트 제작 방법, 스프라이트 규격
- 캐릭터 컨셉과 성장 단계별 외형
- 보상 수치 초안 승인
- 수익 모델

## 작업 규칙

- Nike Run Club 분석 결과는 구조·UX 참고용이다. Nike 코드·리소스를 이 저장소에 넣지 않는다.
- 작업을 마칠 때마다 `HANDOFF.md` 를 갱신한다. 다른 PC(집 Windows)에서 이어서 작업한다.
