# 0009 페이즈 2 추가 패키지

- 상태: 채택
- 날짜: 2026-10-17

## 배경

- 페이즈 2는 아바타 성장과 주간 목표 알림을 추가한다. 임시 스프라이트 생성과 알림에 패키지가 필요하다.

## 결정

- `image` (개발 의존성): 임시 스프라이트 PNG 를 만드는 `tool/gen_placeholder_sprites.dart` 와 스프라이트 크기 테스트에 쓴다. 앱에는 들어가지 않는다.
- `flutter_local_notifications`: 서버 없이 기기에서 예약 알림(금요일 18:00)을 띄우는 사실상 표준 패키지다. `zonedSchedule` 로 미리 몇 주치를 예약하고, sync 때마다 `cancelAll` 후 다시 예약한다. Android 는 core library desugaring 과 예약 알림 receiver, `RECEIVE_BOOT_COMPLETED` 가 필요하다.
- `timezone`: `zonedSchedule` 이 요구하는 `TZDateTime` 을 만든다.
- `flutter_timezone`: 기기의 현지 시간대 식별자를 얻어 `timezone` 의 local 로 설정한다.
- 예약은 `AndroidScheduleMode.inexactAllowWhileIdle` 로 한다. 몇 분 정도 늦어도 되는 알림이라 정확한 알람 권한(`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`)이 필요 없다. Android 13 알림 권한(`POST_NOTIFICATIONS`)은 처음 예약할 때 요청한다.

## 결과

- 실제 에셋이 나오면 생성기는 필요 없어진다. `image` 는 테스트용으로 남는다.
- 알림 코드는 `NotificationScheduler` 인터페이스 뒤에 있어 테스트는 가짜로 대체한다.
