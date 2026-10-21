import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/geo.dart';

import '../../tool/fake_run_path.dart';

void main() {
  test('경로의 하버사인 합이 시간 × 속도와 1% 이내로 같다', () {
    final path = buildPath(
      seconds: 300,
      speedMps: 3.0,
      lat: 37.5260,
      lng: 126.9240,
    );

    var total = 0.0;
    for (var i = 1; i < path.length; i++) {
      total += haversineMeters(
        path[i - 1].$1,
        path[i - 1].$2,
        path[i].$1,
        path[i].$2,
      );
    }

    expect(total, closeTo(300 * 3.0, 300 * 3.0 * 0.01));
  });

  test('시작점에서 출발해 북동쪽으로 이동한다', () {
    final path = buildPath(seconds: 10, speedMps: 3.0, lat: 37.5, lng: 127.0);

    expect(path.first, (37.5, 127.0));
    expect(path.last.$1, greaterThan(37.5));
    expect(path.last.$2, greaterThan(127.0));
  });

  test('멈춤 구간은 같은 좌표를 이어 보낸 뒤 경로를 이어 간다', () {
    final path = buildPath(seconds: 4, speedMps: 3.0, lat: 37.5, lng: 127.0);
    final stopped = withStop(path, stopAt: 2, stopFor: 3);

    expect(stopped, hasLength(path.length + 3));
    expect(stopped.take(3), path.take(3));
    expect(stopped.sublist(3, 6), everyElement(path[2]));
    expect(stopped.skip(6), path.skip(3));
  });
}
