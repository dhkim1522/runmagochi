import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/run_guard.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

final _start = DateTime(2026, 10, 18, 7);

DateTime _at(Duration d) => _start.add(d);

void main() {
  parseTests();
  test('기본값은 자동 일시정지 5분·사용자 일시정지 1시간·예고 30초·6시간·탈것 의심 합계 2분', () {
    expect(autoEndStill, const Duration(minutes: 5));
    expect(autoEndPaused, const Duration(hours: 1));
    expect(autoEndWarning, const Duration(seconds: 30));
    expect(autoEndMax, const Duration(hours: 6));
    expect(autoEndVehicle, const Duration(minutes: 2));
    const config = RunGuardConfig();
    expect(config.still, autoEndStill);
    expect(config.paused, autoEndPaused);
    expect(config.warning, autoEndWarning);
    expect(config.max, autoEndMax);
    expect(config.vehicle, autoEndVehicle);
  });

  group('탈것 의심 규칙 (결정 0033)', () {
    final firstStop = _at(const Duration(minutes: 3));
    final since = _at(const Duration(minutes: 10));

    AutoEndDecision? check(
      Duration total, {
      RunState state = RunState.vehicle,
      DateTime? vehicleEndAt,
      RunGuardConfig config = const RunGuardConfig(),
    }) => checkAutoEnd(
      now: since.add(const Duration(seconds: 40)),
      startedAt: _start,
      state: state,
      pausedAt: since,
      stateSince: since,
      lastPointAt: since,
      recordingSince: state == RunState.recording ? since : null,
      vehicleTime: total,
      vehicleEndAt: vehicleEndAt,
      config: config,
    );

    test('합계 1분 59초면 계속, 2분이면 첫 의심 구간 전 마지막 정상 점에 끝낸다', () {
      expect(
        check(const Duration(minutes: 1, seconds: 59), vehicleEndAt: firstStop),
        isNull,
      );
      final d = check(const Duration(minutes: 2), vehicleEndAt: firstStop);
      expect(d?.reason, AutoEndReason.vehicle);
      expect(d?.endAt, firstStop);
    });

    test('첫 정상 점을 모르면 기록이 멈춘 시각', () {
      expect(check(const Duration(minutes: 2))?.endAt, since);
    });

    test('탈것 의심 중일 때만 적용한다', () {
      for (final state in [
        RunState.recording,
        RunState.paused,
        RunState.autoPaused,
      ]) {
        expect(
          check(const Duration(minutes: 5), state: state)?.reason,
          isNot(AutoEndReason.vehicle),
        );
      }
    });

    test('탈것 의심은 예고하지 않는다', () {
      expect(
        autoEndWarningDeadline(
          now: since.add(const Duration(minutes: 30)),
          state: RunState.vehicle,
          stateSince: since,
        ),
        isNull,
      );
    });

    test('config.vehicle 로 줄인다', () {
      final d = check(
        const Duration(seconds: 20),
        config: const RunGuardConfig(vehicle: Duration(seconds: 20)),
      );
      expect(d?.reason, AutoEndReason.vehicle);
    });
  });

  group('오래 멈춤 규칙', () {
    final pausedAt = _at(const Duration(minutes: 10));

    AutoEndDecision? check(
      RunState state,
      Duration afterStateSince, {
      DateTime? stateSince,
      RunGuardConfig config = const RunGuardConfig(),
    }) {
      final since = stateSince ?? pausedAt;
      return checkAutoEnd(
        now: since.add(afterStateSince),
        startedAt: _start,
        state: state,
        pausedAt: pausedAt,
        stateSince: since,
        lastPointAt: pausedAt,
        recordingSince: null,
        config: config,
      );
    }

    DateTime? deadline(
      RunState state,
      Duration afterStateSince, {
      DateTime? stateSince,
      RunGuardConfig config = const RunGuardConfig(),
    }) {
      final since = stateSince ?? pausedAt;
      return autoEndWarningDeadline(
        now: since.add(afterStateSince),
        state: state,
        stateSince: since,
        config: config,
      );
    }

    test('자동 일시정지 4분 59초엔 예고 없음, 5분~5분 29초는 예고, 5분 30초에 pausedAt 으로 종료', () {
      const s = RunState.autoPaused;
      final end = pausedAt.add(const Duration(minutes: 5, seconds: 30));
      expect(check(s, const Duration(minutes: 4, seconds: 59)), isNull);
      expect(deadline(s, const Duration(minutes: 4, seconds: 59)), isNull);

      expect(check(s, const Duration(minutes: 5)), isNull);
      expect(deadline(s, const Duration(minutes: 5)), end);
      expect(check(s, const Duration(minutes: 5, seconds: 29)), isNull);
      expect(deadline(s, const Duration(minutes: 5, seconds: 29)), end);

      final d = check(s, const Duration(minutes: 5, seconds: 30));
      expect(d?.reason, AutoEndReason.still);
      expect(d?.endAt, pausedAt);
      expect(deadline(s, const Duration(minutes: 5, seconds: 30)), isNull);
    });

    test('신호 끊김도 5분에 예고하고 5분 30초에 pausedAt 으로 끝낸다', () {
      const s = RunState.signalLost;
      final end = pausedAt.add(const Duration(minutes: 5, seconds: 30));
      expect(deadline(s, const Duration(minutes: 4, seconds: 59)), isNull);
      expect(deadline(s, const Duration(minutes: 5)), end);
      expect(check(s, const Duration(minutes: 5, seconds: 29)), isNull);
      final d = check(s, const Duration(minutes: 5, seconds: 30));
      expect(d?.reason, AutoEndReason.signalLost);
      expect(d?.endAt, pausedAt);
    });

    test('사용자 일시정지 1시간에 예고, 1시간 30초에 pausedAt 으로 종료', () {
      const s = RunState.paused;
      expect(deadline(s, const Duration(minutes: 59, seconds: 59)), isNull);
      expect(
        deadline(s, const Duration(hours: 1)),
        pausedAt.add(const Duration(hours: 1, seconds: 30)),
      );
      expect(check(s, const Duration(hours: 1, seconds: 29)), isNull);
      final d = check(s, const Duration(hours: 1, seconds: 30));
      expect(d?.reason, AutoEndReason.paused);
      expect(d?.endAt, pausedAt);
    });

    test('자동 일시정지에서 바꾼 사용자 일시정지는 바꾼 시각부터 1시간을 세고 처음 멈춘 시각에 끝낸다', () {
      final switchedAt = pausedAt.add(const Duration(minutes: 3));
      expect(
        check(
          RunState.paused,
          const Duration(minutes: 30),
          stateSince: switchedAt,
        ),
        isNull,
      );
      final d = check(
        RunState.paused,
        const Duration(hours: 1, seconds: 30),
        stateSince: switchedAt,
      );
      expect(d?.reason, AutoEndReason.paused);
      expect(d?.endAt, pausedAt);
    });

    test('기록 중에는 점이 오래 없어도 끝내지 않고 예고도 없다', () {
      final d = checkAutoEnd(
        now: pausedAt.add(const Duration(hours: 2)),
        startedAt: _start,
        state: RunState.recording,
        pausedAt: null,
        stateSince: pausedAt,
        lastPointAt: pausedAt,
        recordingSince: pausedAt,
      );
      expect(d, isNull);
      expect(
        autoEndWarningDeadline(
          now: pausedAt.add(const Duration(hours: 2)),
          state: RunState.recording,
          stateSince: pausedAt,
        ),
        isNull,
      );
    });

    test('config 로 줄인 기준을 따른다', () {
      const config = RunGuardConfig(
        still: Duration(seconds: 20),
        paused: Duration(seconds: 40),
        warning: Duration(seconds: 5),
      );
      expect(
        deadline(
          RunState.autoPaused,
          const Duration(seconds: 20),
          config: config,
        ),
        pausedAt.add(const Duration(seconds: 25)),
      );
      expect(
        check(
          RunState.autoPaused,
          const Duration(seconds: 25),
          config: config,
        )?.reason,
        AutoEndReason.still,
      );
      expect(
        check(RunState.paused, const Duration(seconds: 44), config: config),
        isNull,
      );
      expect(
        check(
          RunState.paused,
          const Duration(seconds: 45),
          config: config,
        )?.reason,
        AutoEndReason.paused,
      );
    });
  });

  group('6시간 상한', () {
    test('5시간 59분 59초면 계속', () {
      final now = _at(const Duration(hours: 5, minutes: 59, seconds: 59));
      final d = checkAutoEnd(
        now: now,
        startedAt: _start,
        state: RunState.recording,
        pausedAt: null,
        stateSince: _start,
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
        state: RunState.recording,
        pausedAt: null,
        stateSince: _start,
        lastPointAt: lastPoint,
        recordingSince: _start,
      );
      expect(d?.reason, AutoEndReason.maxDuration);
      expect(d?.endAt, lastPoint);
    });

    test('일시정지 중에도 6시간이면 종료, 끝 시각은 마지막 점', () {
      final lastPoint = _at(const Duration(hours: 1));
      final now = _at(const Duration(hours: 6));
      final d = checkAutoEnd(
        now: now,
        startedAt: _start,
        state: RunState.paused,
        pausedAt: lastPoint,
        stateSince: now.subtract(const Duration(minutes: 10)),
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
        state: RunState.paused,
        pausedAt: _start,
        stateSince: now.subtract(const Duration(minutes: 10)),
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
    test('모두 비면 null', () {
      expect(runGuardConfigFromSeconds(), isNull);
    });

    test('준 값만 초로 바꾸고 나머지는 기본값', () {
      final c = runGuardConfigFromSeconds(stillSec: '30', maxSec: '120');
      expect(c?.still, const Duration(seconds: 30));
      expect(c?.max, const Duration(minutes: 2));
      expect(c?.paused, autoEndPaused);
      expect(c?.warning, autoEndWarning);
      expect(c?.vehicle, autoEndVehicle);
      final d = runGuardConfigFromSeconds(
        pausedSec: '60',
        warningSec: '10',
        vehicleSec: '10',
      );
      expect(d?.paused, const Duration(minutes: 1));
      expect(d?.warning, const Duration(seconds: 10));
      expect(d?.vehicle, const Duration(seconds: 10));
      expect(d?.still, autoEndStill);
      expect(d?.max, autoEndMax);
    });

    test('숫자가 아니거나 0 이하면 기본값', () {
      final c = runGuardConfigFromSeconds(
        stillSec: 'x',
        pausedSec: '0',
        warningSec: '-3',
        maxSec: '0',
        vehicleSec: '-3',
      );
      expect(c?.still, autoEndStill);
      expect(c?.paused, autoEndPaused);
      expect(c?.warning, autoEndWarning);
      expect(c?.max, autoEndMax);
      expect(c?.vehicle, autoEndVehicle);
    });
  });
}
