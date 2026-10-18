import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/data/notification_scheduler.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('기기가 별칭 이름(GMT 등)을 줘도 시간대를 찾는다', () {
    // Android 에뮬레이터는 'GMT' 를 준다. 별칭이 없는 데이터에선 초기화가 깨졌다.
    expect(resolveTimeZone('GMT').name, 'GMT');
    expect(resolveTimeZone('Asia/Calcutta').name, 'Asia/Calcutta');
    expect(resolveTimeZone('Asia/Seoul').name, 'Asia/Seoul');
  });

  test('모르는 시간대는 UTC 로 대신한다', () {
    expect(resolveTimeZone('Nowhere/Unknown'), tz.UTC);
  });
}
