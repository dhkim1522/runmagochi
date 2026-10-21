import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/data/run_progress_notifier.dart';
import 'package:runmagochi/run/domain/run_engine.dart';

RunProgressContent _content(
  RunState state, {
  double? goalM = 5000,
  bool reached = false,
}) => runProgressContent(
  state: state,
  distanceM: 2310,
  movingTime: const Duration(minutes: 12, seconds: 34),
  goalM: goalM,
  goalReached: reached,
);

void main() {
  group('기록 중', () {
    test('목표 있음: 남은 거리, 크로노미터 켬, 일시정지 버튼', () {
      final c = _content(RunState.recording);
      expect(c.title, '러닝 중 · 2.31km');
      expect(c.body, '목표 5km까지 2.69km');
      expect(c.elapsed, const Duration(minutes: 12, seconds: 34));
      expect(c.action, RunProgressAction.pause);
    });

    test('목표 달성', () {
      expect(_content(RunState.recording, reached: true).body, '목표 5km 달성!');
    });

    test('목표 없음', () {
      expect(_content(RunState.recording, goalM: null).body, '화면을 꺼도 기록이 이어져요');
    });
  });

  group('일시정지', () {
    test('목표 있음: 시간이 제목에, 크로노미터 끔, 재개 버튼', () {
      final c = _content(RunState.paused);
      expect(c.title, '일시정지 · 2.31km · 12:34');
      expect(c.body, '목표 5km까지 2.69km');
      expect(c.elapsed, isNull);
      expect(c.action, RunProgressAction.resume);
    });

    test('목표 달성·없음 본문은 기록 중과 같다', () {
      expect(_content(RunState.paused, reached: true).body, '목표 5km 달성!');
      expect(_content(RunState.paused, goalM: null).body, '화면을 꺼도 기록이 이어져요');
    });
  });

  group('자동 일시정지', () {
    test('멈춘 문구, 크로노미터 끔, 재개 버튼', () {
      final c = _content(RunState.autoPaused);
      expect(c.title, '멈춰서 일시정지했어요 · 2.31km');
      expect(c.body, '움직이면 이어져요');
      expect(c.elapsed, isNull);
      expect(c.action, RunProgressAction.resume);
    });

    test('목표와 상관없이 본문이 같다', () {
      expect(_content(RunState.autoPaused, reached: true).body, '움직이면 이어져요');
      expect(_content(RunState.autoPaused, goalM: null).body, '움직이면 이어져요');
    });
  });
}
