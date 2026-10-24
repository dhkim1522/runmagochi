# 페이즈 9 구현 계획

- 상태: 실행
- 모드: 수동 (사용자 지시 2026-10-24: 실측 없이 할 수 있는 작업은 모두 지금 진행)
- 범위: docs/roadmap.md 페이즈 9, 결정 0036·0037

실측이 필요 없는 작업(신규 기능 9개, 문서·화면설계서)을 먼저 하고, 실기기 실측·기준값 조정·지인 베타는 그 뒤에 한다. 이미 끝난 개선: 설정 초기화·첫 실행 카드 제거(결정 0036), UI/UX 전체 검토 반영.

## 작업 (실측 전)

- [ ] 1. GPX 내보내기 (F30)
  - 파일: `lib/run/domain/gpx.dart`(새로), `lib/run/ui/summary_screen.dart`
  - 테스트: 경로 점·구간으로 GPX 1.1 문자열(trk/trkseg/trkpt, 시각 UTC)을 만든다. 상세 화면 공유 메뉴에서 GPX 파일을 공유한다
  - 확인: `fvm flutter test test/run`
- [ ] 2. 응원 음성 (F28)
  - 파일: `lib/run/app/voice_guide.dart`
  - 테스트: 구간 안내 뒤에 캐릭터 종류별 응원 한마디가 붙는다(반 지점·목표 직전·목표 달성). 음성 안내를 끄면 말하지 않는다
  - 확인: `fvm flutter test test/run/app`
- [ ] 3. 캐릭터 알림 (F27)
  - 파일: `lib/reminder/`(새로), 설정 화면
  - 테스트: 마지막 러닝 뒤 3일째 저녁에 한 번 "기다리고 있어요" 예약, 러닝하면 다시 예약. 다음 레벨까지 1km 이하면 문구가 남은 거리로 바뀐다. 설정에서 끄면 예약을 지운다. 기본은 켜짐이 아니라 첫 러닝 뒤 묻지 않고 켜짐(벌점 없음)
  - 확인: `fvm flutter test test/reminder test/settings`
- [ ] 4. 결산 카드 (F32)
  - 파일: `lib/run/ui/recap_card.dart`(새로), 기록 화면
  - 테스트: 주·월 탭에서 공유 버튼으로 기간 거리·러닝 수·레벨 변화를 담은 카드를 만든다. 러닝이 없으면 버튼이 없다
  - 확인: `fvm flutter test test/run/ui`
- [ ] 5. 부화 연출 (F33)
  - 파일: `tool/sprites/egg.dart`(새로), `assets/sprites/egg/`, `lib/onboarding/ui/hatch_view.dart`(새로)
  - 테스트: 첫 실행 1장에서 알이 흔들리다 금이 가고 깨지며 캐릭터가 나온다(약 3초, 누르면 건너뜀). 움직임 줄이기 설정이면 바로 캐릭터. 초기화 뒤에도 같은 연출
  - 확인: `fvm flutter test test/onboarding`, 스프라이트 생성 `fvm dart run tool/render_sprites.dart`
  - 스킬: pixel-plugin(도트), 규격 `docs/specs/sprite-spec.md`
- [ ] 6. 날씨 배경 (F25)
  - 파일: `lib/core/stage/` 날씨 장면(맑음·흐림·비·눈·밤), `lib/weather/`(새로, Open-Meteo 무료 API·키 없음), 무대
  - 테스트: 날씨 코드 → 장면 매핑, 해 진 뒤는 밤. 인터넷·위치가 없으면 기본(맑음/낮), 30분 캐시. 러닝 기록 위치와 별개로 대략 위치만 쓴다
  - 확인: `fvm flutter test test/weather test/core`
  - 결정: 새 패키지(`http`) → 결정 기록
- [ ] 7. 홈 화면 위젯 (F29)
  - 파일: `lib/widget/`(새로), `android/app/src/main/`(AppWidget), `ios/`(WidgetKit 확장)
  - 테스트: 위젯에 보낼 상태(캐릭터·표정·레벨·다음 레벨까지 거리·날씨)를 만든다. 러닝을 끝내거나 앱을 열면 갱신한다
  - 확인: `fvm flutter test test/widget`, 에뮬레이터 홈 화면에 위젯 추가
  - 결정: 새 패키지(`home_widget`) → 결정 기록. iOS 무료 Apple ID 는 App Group 이 제한될 수 있어 실기기 설치를 확인한다
- [ ] 8. 새 친구 입양·도감 (F31)
  - 파일: 아바타 저장소·스키마 8판(아바타 여러 행, 현재 친구 표시), `lib/avatar/ui/` 도감
  - 테스트: 마지막 성장 단계(최대 레벨) 뒤 "새 친구 맞이하기"가 열리고, 부화 연출로 아직 없는 종류가 나온다. 키운 친구는 도감에 레벨·누적 거리와 함께 남는다. 경험치·코인은 계속 이어진다. 스키마 7→8 이전과 백업 v8
  - 확인: `fvm flutter test`, `test/docs` ERD 대조
- [ ] 9. 건강 앱 연동 (F15)
  - 파일: `lib/health/`(새로), 설정, Android Health Connect 권한, iOS HealthKit
  - 테스트: 건강 앱의 러닝 운동(이 앱이 쓴 것 제외)을 읽어 경험치로 반영, 같은 운동은 한 번만. 끄면 읽지 않는다
  - 확인: `fvm flutter test test/health`
  - 결정: 새 패키지(`health`) → 결정 기록. 스토어 권한 신고는 페이즈 10
- [ ] 10. 화면설계서·문서 갱신
  - 파일: `design/screens/`(바뀐 컷 재촬영), `docs/screens.md`, `docs/product.md`, `docs/data-model.md`, `docs/sequences.md`
  - 확인: `fvm flutter test test/docs`, mermaid 검사, 상대 링크 검사

## 작업 (실측)

- [ ] 11. Android·iPhone 30분 러닝 3회씩 실측, 기록표(`docs/field-test.md`)
- [ ] 12. 기준값 조정(탈것 22km/h·2분·30초, 자동 일시정지, 정확도 20m)
- [ ] 13. 소감·개선점 리포트(`docs/research/field-test-report.md`)와 수정
- [ ] 14. Android 지인 베타(릴리스 키 APK) 의견 수집
- [ ] 15. 1.0 후보

## 완료 기준

### 자동 확인
- [ ] `fvm flutter test` 통과, `fvm dart analyze` 문제 없음, `fvm flutter build apk --debug` 통과
- [ ] 스키마 7→8 이전 테스트, 백업 v7 파일 가져오기
- [ ] 새 문서·고친 문서의 mermaid 검사, 상대 링크 끊김 0

### E2E (에뮬레이터)
- [ ] 첫 실행에서 알이 깨지며 캐릭터가 나온다
- [ ] 러닝 상세에서 GPX 공유 창이 열린다
- [ ] 홈 화면에 위젯을 추가하면 캐릭터와 다음 레벨 거리가 보인다
- [ ] 날씨를 바꾸면(가짜 날씨) 무대 배경이 바뀐다

### 사람 확인
- [ ] Android·iPhone 실기기로 각각 실제 30분 러닝 3회, 기록 누락 0건, 트랙 거리 오차 5% 이내
- [ ] 페이즈 1~6 의 "사람 확인" 항목 통과
- [ ] 리포트의 개선점을 반영하거나 미룰 이유를 적음
- [ ] Android 지인 베타 의견 수집
- [ ] iPhone 위젯·건강 연동이 무료 Apple ID 로 동작하는지(안 되면 페이즈 10 유료 계정 뒤)

## 자동 결정
없음
