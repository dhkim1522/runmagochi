import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/run_guard.dart';

final _start = DateTime(2026, 10, 18, 7);

DateTime _at(Duration d) => _start.add(d);

void main() {
  parseTests();
  test('기본값은 20분·6시간', () {
    expect(autoEndIdle, const Duration(minutes: 20));
    expect(autoEndMax, const Duration(hours: 6));
    const config = RunGuardConfig();
    expect(config.idle, autoEndIdle);
    expect(config.max, autoEndMax);
  });

  group('기록 중 20분 규칙', () {
    final lastPoint = _at(const Duration(minutes: 10));

    test('마지막 점 뒤 19분 59초면 계속', () {
      final d = checkAutoEnd(
        now: lastPoint.add(const Duration(minutes: 19, seconds: 59)),
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: _start,
      );
      expect(d, isNull);
    });

    test('마지막 점 뒤 20분이면 종료, 끝 시각은 마지막 점', () {
      final d = checkAutoEnd(
        now: lastPoint.add(const Duration(minutes: 20)),
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: _start,
      );
      expect(d?.reason, AutoEndReason.idle);
      expect(d?.endAt, lastPoint);
    });

    test('재개 뒤에는 재개 시각부터 다시 센다', () {
      final resumedAt = _at(const Duration(minutes: 40));
      final keep = checkAutoEnd(
        now: resumedAt.add(const Duration(minutes: 19)),
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: resumedAt,
      );
      expect(keep, isNull);

      final end = checkAutoEnd(
        now: resumedAt.add(const Duration(minutes: 20)),
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: resumedAt,
      );
      expect(end?.reason, AutoEndReason.idle);
      expect(end?.endAt, resumedAt);
    });

    test('점이 하나도 없으면 기록 시작 시각으로 끝낸다', () {
      final d = checkAutoEnd(
        now: _at(const Duration(minutes: 20)),
        startedAt: _start,
        recording: true,
        lastPointAt: null,
        recordingSince: _start,
      );
      expect(d?.reason, AutoEndReason.idle);
      expect(d?.endAt, _start);
    });

    test('일시정지 중에는 적용하지 않는다', () {
      final d = checkAutoEnd(
        now: lastPoint.add(const Duration(minutes: 30)),
        startedAt: _start,
        recording: false,
        lastPointAt: lastPoint,
        recordingSince: null,
      );
      expect(d, isNull);
    });

    test('짧게 바꾼 설정을 따른다', () {
      final d = checkAutoEnd(
        now: lastPoint.add(const Duration(seconds: 30)),
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: _start,
        config: const RunGuardConfig(idle: Duration(seconds: 30)),
      );
      expect(d?.reason, AutoEndReason.idle);
    });
  });

  group('6시간 상한', () {
    test('5시간 59분 59초면 계속', () {
      final now = _at(const Duration(hours: 5, minutes: 59, seconds: 59));
      final d = checkAutoEnd(
        now: now,
        startedAt: _start,
        recording: true,
        lastPointAt: now.subtract(const Duration(seconds: 1)),
        recordingSince: _start,
      );
      expect(d, isNull);
    });

    test('기록 중 6시간이면 종료, 끝 시각은 마지막 점', () {
      final now = _at(const Duration(hours: 6));
      final lastPoint = now.subtract(const Duration(seconds: 1));
      final d = checkAutoEnd(
        now: now,
        startedAt: _start,
        recording: true,
        lastPointAt: lastPoint,
        recordingSince: _start,
      );
      expect(d?.reason, AutoEndReason.maxDuration);
      expect(d?.endAt, lastPoint);
    });

    test('일시정지 중에도 6시간이면 종료, 끝 시각은 마지막 점', () {
      final lastPoint = _at(const Duration(hours: 1));
      final d = checkAutoEnd(
        now: _at(const Duration(hours: 6)),
        startedAt: _start,
        recording: false,
        lastPointAt: lastPoint,
        recordingSince: null,
      );
      expect(d?.reason, AutoEndReason.maxDuration);
      expect(d?.endAt, lastPoint);
    });

    test('점이 하나도 없으면 지금 시각으로 끝낸다', () {
      final now = _at(const Duration(hours: 6));
      final d = checkAutoEnd(
        now: now,
        startedAt: _start,
        recording: false,
        lastPointAt: null,
        recordingSince: null,
      );
      expect(d?.reason, AutoEndReason.maxDuration);
      expect(d?.endAt, now);
    });
  });
}

void parseTests() {
  group('runGuardConfigFromSeconds', () {
    test('둘 다 비면 null', () {
      expect(runGuardConfigFromSeconds(idleSec: '', maxSec: ''), isNull);
    });

    test('준 값만 초로 바꾸고 나머지는 기본값', () {
      final c = runGuardConfigFromSeconds(idleSec: '30', maxSec: '');
      expect(c?.idle, const Duration(seconds: 30));
      expect(c?.max, autoEndMax);
      final d = runGuardConfigFromSeconds(idleSec: '', maxSec: '120');
      expect(d?.idle, autoEndIdle);
      expect(d?.max, const Duration(minutes: 2));
    });

    test('숫자가 아니거나 0 이하면 기본값', () {
      final c = runGuardConfigFromSeconds(idleSec: 'x', maxSec: '0');
      expect(c?.idle, autoEndIdle);
      expect(c?.max, autoEndMax);
    });
  });
}
