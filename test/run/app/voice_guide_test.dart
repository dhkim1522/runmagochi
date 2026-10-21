import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/voice_guide.dart';
import 'package:runmagochi/run/domain/run_goal.dart';

import '../ui/fakes.dart';

void main() {
  group('voiceLine', () {
    test('시작', () {
      expect(voiceLine(const VoiceStart()), '러닝을 시작해요');
    });

    test('1km 구간: 누적 시간과 평균 페이스', () {
      expect(
        voiceLine(
          const VoiceSplit(
            km: 3,
            elapsed: Duration(minutes: 18, seconds: 40),
            avgPaceSecPerKm: 373,
          ),
        ),
        '3킬로미터. 시간 18분 40초. 평균 페이스 6분 13초.',
      );
    });

    test('0 인 단위는 읽지 않고 한 시간이 넘으면 시간을 읽는다', () {
      expect(
        voiceLine(
          const VoiceSplit(
            km: 10,
            elapsed: Duration(hours: 1, minutes: 5, seconds: 3),
            avgPaceSecPerKm: 360,
          ),
        ),
        '10킬로미터. 시간 1시간 5분 3초. 평균 페이스 6분.',
      );
    });

    test('목표 달성: 거리와 시간', () {
      expect(
        voiceLine(const VoiceGoalReached(DistanceGoal(5000))),
        '목표 5킬로미터를 채웠어요',
      );
      expect(
        voiceLine(const VoiceGoalReached(DistanceGoal(2500))),
        '목표 2.5킬로미터를 채웠어요',
      );
      expect(
        voiceLine(const VoiceGoalReached(TimeGoal(Duration(minutes: 30)))),
        '목표 30분을 채웠어요',
      );
    });

    test('자동 일시정지·재개·종료 예고', () {
      expect(voiceLine(const VoiceAutoPaused()), '일시정지했어요');
      expect(voiceLine(const VoiceAutoResumed()), '다시 기록해요');
      expect(voiceLine(const VoiceEndWarning(30)), '움직이지 않으면 30초 뒤 러닝을 마쳐요');
      expect(voiceLine(const VoiceEndWarning(0)), isNull);
    });
  });

  group('VoiceGuide', () {
    test('켜져 있으면 읽는다', () async {
      final speaker = FakeSpeaker();
      await VoiceGuide(
        speaker: speaker,
        enabled: () async => true,
      ).say(const VoiceStart());
      expect(speaker.spoken, ['러닝을 시작해요']);
    });

    test('꺼져 있으면 읽지 않는다', () async {
      final speaker = FakeSpeaker();
      await VoiceGuide(
        speaker: speaker,
        enabled: () async => false,
      ).say(const VoiceStart());
      expect(speaker.spoken, isEmpty);
    });

    test('읽기 실패와 켜짐 확인 실패는 던지지 않는다', () async {
      final speaker = FakeSpeaker()..fails = true;
      await VoiceGuide(
        speaker: speaker,
        enabled: () async => true,
      ).say(const VoiceStart());
      await VoiceGuide(
        speaker: speaker,
        enabled: () async => throw StateError('db'),
      ).say(const VoiceStart());
      expect(speaker.spoken, isEmpty);
    });
  });
}
