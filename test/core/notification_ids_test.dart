import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/local_notifications.dart';

void main() {
  test('알림 번호는 서로 다르다', () {
    expect(NotificationIds.all.toSet().length, NotificationIds.all.length);
  });
}
