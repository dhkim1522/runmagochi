import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/run_guard.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

final _start = DateTime(2026, 10, 18, 7);

DateTime _at(Duration d) => _start.add(d);

void main() {
  parseTests();
  test('기본값은 자동 일시정지 5분·사용자 일시정지 1시간·예고 30초·6시간·빠른 이동 30초', () {
    expect(autoEndStill, const Duration(minutes: 5));
    expect(autoEndPaused, const Duration(hours: 1));
    expect(autoEndWarning, const Duration(seconds: 30));
    expect(autoEndMax, const Duration(hours: 6));
    expect(autoEndFast, const Duration(seconds: 30));
    const config = RunGuardConfig();
    expect(config.still, autoEndStill);
    expect(config.paused, autoEndPaused);
    expect(config.warning, autoEndWarning);
    expect(config.max, autoEndMax);
    expect(config.fast, autoEndFast);
  });

  group('빠른 이동 규칙', () {
    final fastSince = _at(const Duration(minutes: 5));
    final before = _at(const Duration(minutes: 4, seconds: 50));

    AutoEndDecision? check(
      Duration afterFast, {
      RunState state = RunState.recording,
      DateTime? beforeFastAt,
      DateTime? lastPointAt,
    }) => checkAutoEnd(
      now: fastSince.add(afterFast),
      startedAt: _start,
      state: state,
      pausedAt: state == RunState.recording ? null : before,
      stateSince: state == RunState.recording ? _start : fastSince,
      lastPointAt: lastPointAt ?? before,
      recordingSince: state == RunState.recording ? _start : null,
      fastSince: fastSince,
      fastLastAt: fastSince.add(afterFast),
      beforeFastAt: beforeFastAt,
    );

    test('29초면 계속, 30초면 종료하고 끝 시각은 빨라지기 전 점', () {
      expect(check(const Duration(seconds: 29), beforeFastAt: before), isNull);
      final d = check(const Duration(seconds: 30), beforeFastAt: before);
      expect(d?.reason, AutoEndReason.fast);
      expect(d?.endAt, before);
    });

    test('빨라지기 전 점이 없으면 기록 구간 시작 시각', () {
      final d = check(const Duration(seconds: 30), lastPointAt: null);
      expect(d?.endAt, _start);
    });

    test('기록 구간 시작 시각도 없으면 시작 시각', () {
      final d = checkAutoEnd(
        now: fastSince.add(const Duration(seconds: 30)),
        startedAt: _start,
        state: RunState.recording,
        pausedAt: null,
        stateSince: _start,
        lastPointAt: null,
        recordingSince: null,
        fastSince: fastSince,
        fastLastAt: fastSince.add(const Duration(seconds: 30)),
      );
      expect(d?.endAt, _start);
    });

    test('now 가 한참 지나도 점 시각 차이가 짧으면 계속', () {
      final d = checkAutoEnd(
        now: fastSince.add(const Duration(minutes: 5)),
        startedAt: _start,
        state: RunState.recording,
        pausedAt: null,
        stateSince: _start,
        lastPointAt: before,
        recordingSince: _start,
        fastSince: fastSince,
        fastLastAt: fastSince.add(const Duration(seconds: 1)),
        beforeFastAt: before,
      );
      expect(d, isNull);
    });

    test('일시정지·자동 일시정지 중에는 적용하지 않는다', () {
      for (final state in [RunState.paused, RunState.autoPaused]) {
        expect(
          check(const Duration(minutes: 1), state: state, beforeFastAt: before),
          isNull,
        );
      }
    });

    test('config.fast 로 줄인다', () {
      final d = checkAutoEnd(
        now: fastSince.add(const Duration(seconds: 5)),
        startedAt: _start,
        state: RunState.recording,
        pausedAt: null,
        stateSince: _start,
        lastPointAt: before,
        recordingSince: _start,
        fastSince: fastSince,
        fastLastAt: fastSince.add(const Duration(seconds: 5)),
        beforeFastAt: before,
        config: const RunGuardConfig(fast: Duration(seconds: 5)),
      );
      expect(d?.reason, AutoEndReason.fast);
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
      expect(c?.fast, autoEndFast);
      final d = runGuardConfigFromSeconds(
        pausedSec: '60',
        warningSec: '10',
        fastSec: '10',
      );
      expect(d?.paused, const Duration(minutes: 1));
      expect(d?.warning, const Duration(seconds: 10));
      expect(d?.fast, const Duration(seconds: 10));
      expect(d?.still, autoEndStill);
      expect(d?.max, autoEndMax);
    });

    test('숫자가 아니거나 0 이하면 기본값', () {
      final c = runGuardConfigFromSeconds(
        stillSec: 'x',
        pausedSec: '0',
        warningSec: '-3',
        maxSec: '0',
        fastSec: '-3',
      );
      expect(c?.still, autoEndStill);
      expect(c?.paused, autoEndPaused);
      expect(c?.warning, autoEndWarning);
      expect(c?.max, autoEndMax);
      expect(c?.fast, autoEndFast);
    });
  });
}
