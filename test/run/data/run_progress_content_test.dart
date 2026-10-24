import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_goal.dart';

RunProgressContent _content(
  RunState state, {
  RunGoal? goal = const DistanceGoal(5000),
  bool reached = false,
}) => runProgressContent(
  state: state,
  distanceM: 2310,
  movingTime: const Duration(minutes: 12, seconds: 34),
  goal: goal,
  goalReached: reached,
);

void main() {
  endWarningTests();
  group('기록 중', () {
    test('목표 있음: 남은 거리, 크로노미터 켬, 일시정지 버튼', () {
      final c = _content(RunState.recording);
      expect(c.title, '러닝 중 · 2.31km');
      expect(c.body, '목표 5km까지 2.69km');
      expect(c.elapsed, const Duration(minutes: 12, seconds: 34));
      expect(c.actions, [RunProgressAction.pause]);
    });

    test('목표 달성', () {
      expect(_content(RunState.recording, reached: true).body, '목표 5km 달성!');
    });

    test('시간 목표: 남은 시간', () {
      // 움직인 시간 12:34, 목표 30분 → 17:26.
      final c = _content(
        RunState.recording,
        goal: const TimeGoal(Duration(minutes: 30)),
      );
      expect(c.body, '목표 30분까지 17:26');
    });

    test('시간 목표 달성', () {
      final c = _content(
        RunState.recording,
        goal: const TimeGoal(Duration(minutes: 10)),
        reached: true,
      );
      expect(c.body, '목표 10분 달성!');
    });

    test('시간 목표를 넘겨도 남은 시간은 0:00 으로 멈춘다', () {
      final c = _content(
        RunState.recording,
        goal: const TimeGoal(Duration(minutes: 10)),
      );
      expect(c.body, '목표 10분까지 0:00');
    });

    test('목표 없음', () {
      expect(_content(RunState.recording, goal: null).body, '화면을 꺼도 기록이 이어져요');
    });
  });

  group('일시정지', () {
    test('목표 있음: 시간이 제목에, 크로노미터 끔, 재개 버튼', () {
      final c = _content(RunState.paused);
      expect(c.title, '일시정지 · 2.31km · 12:34');
      expect(c.body, '목표 5km까지 2.69km');
      expect(c.elapsed, isNull);
      expect(c.actions, [RunProgressAction.resume]);
    });

    test('목표 달성·없음 본문은 기록 중과 같다', () {
      expect(_content(RunState.paused, reached: true).body, '목표 5km 달성!');
      expect(_content(RunState.paused, goal: null).body, '화면을 꺼도 기록이 이어져요');
    });
  });

  group('자동 일시정지', () {
    test('멈춘 문구, 크로노미터 끔, 재개·일시정지 버튼', () {
      final c = _content(RunState.autoPaused);
      expect(c.title, '멈춰서 일시정지했어요 · 2.31km');
      expect(c.body, '움직이면 이어져요');
      expect(c.elapsed, isNull);
      expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
    });

    test('목표와 상관없이 본문이 같다', () {
      expect(_content(RunState.autoPaused, reached: true).body, '움직이면 이어져요');
      expect(_content(RunState.autoPaused, goal: null).body, '움직이면 이어져요');
    });
  });

  group('탈것 의심·신호 끊김 (결정 0033)', () {
    test('탈것 의심: 뺀다고 알리고 재개·일시정지 버튼', () {
      final c = _content(RunState.vehicle);
      expect(c.title, '일시정지 · 2.31km');
      expect(c.body, '혹시 뭘 타셨나요? 이 구간은 기록에서 뺄게요');
      expect(c.elapsed, isNull);
      expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
    });

    test('탈것 의심 문구를 끄면 일시정지 제목에 목표 본문', () {
      final c = runProgressContent(
        state: RunState.vehicle,
        distanceM: 2310,
        movingTime: const Duration(minutes: 12, seconds: 34),
        goal: const DistanceGoal(5000),
        goalReached: false,
        vehicleNotice: false,
      );
      expect(c.title, '일시정지 · 2.31km');
      expect(c.body, '목표 5km까지 2.69km');
      expect(c.elapsed, isNull);
      expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
    });

    test('기록 중에는 탈것 의심 문구를 쓰지 않는다', () {
      final c = runProgressContent(
        state: RunState.recording,
        distanceM: 2310,
        movingTime: const Duration(minutes: 12, seconds: 34),
        goal: const DistanceGoal(5000),
        goalReached: false,
        vehicleNotice: true,
      );
      expect(c.title, '러닝 중 · 2.31km');
      expect(c.body, '목표 5km까지 2.69km');
    });

    test('일시정지에는 탈것 의심 문구를 쓰지 않는다', () {
      final c = runProgressContent(
        state: RunState.paused,
        distanceM: 2310,
        movingTime: const Duration(minutes: 12, seconds: 34),
        goal: const DistanceGoal(5000),
        goalReached: false,
        vehicleNotice: true,
      );
      expect(c.body, '목표 5km까지 2.69km');
    });

    test('신호 끊김인데 위치 서비스가 꺼졌으면 꺼짐 문구', () {
      final c = runProgressContent(
        state: RunState.signalLost,
        distanceM: 2310,
        movingTime: const Duration(minutes: 12, seconds: 34),
        goal: const DistanceGoal(5000),
        goalReached: false,
        locationOff: true,
      );
      expect(c.title, '일시정지 · 2.31km');
      expect(c.body, '위치 서비스가 꺼져 있어요. 켜면 이어서 기록해요');
      expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
    });

    test('신호 끊김: 다시 찾는다고 알리고 재개·일시정지 버튼', () {
      final c = _content(RunState.signalLost, reached: true);
      expect(c.title, '일시정지 · 2.31km');
      expect(c.body, '신호가 끊겼어요. 밖으로 나오면 다시 찾을게요');
      expect(c.elapsed, isNull);
      expect(c.actions, [RunProgressAction.resume, RunProgressAction.pause]);
    });
  });
}

void endWarningTests() {
  group('종료 예고 알림', () {
    test('자동 일시정지면 움직이거나 재개하라고 알린다', () {
      final c = endWarningContent(paused: false);
      expect(c.title, '움직이지 않으면 러닝을 마쳐요');
      expect(c.body, '30초 안에 움직이거나 재개를 눌러 주세요');
    });

    test('사용자 일시정지면 재개만 안내한다', () {
      final c = endWarningContent(paused: true);
      expect(c.title, '일시정지가 길어 러닝을 마쳐요');
      expect(c.body, '30초 안에 재개를 눌러 주세요');
    });

    test('신호 끊김이면 밖으로 나오거나 재개하라고 알린다', () {
      final c = endWarningContent(paused: false, signalLost: true);
      expect(c.title, '신호가 오래 끊겨 러닝을 마쳐요');
      expect(c.body, '30초 안에 밖으로 나오거나 재개를 눌러 주세요');
    });

    test('남은 시간에 여유 5초를 더해 알림을 스스로 거둔다', () {
      final now = DateTime(2026, 10, 17, 12);
      expect(
        endWarningTimeoutMs(now.add(const Duration(seconds: 30)), now),
        35000,
      );
      expect(
        endWarningTimeoutMs(now.subtract(const Duration(seconds: 3)), now),
        5000,
      );
    });
  });
}
