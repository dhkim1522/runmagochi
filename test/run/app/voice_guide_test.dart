import 'package:fake_async/fake_async.dart';
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
      expect(
        voiceLine(const VoiceEndWarning(30, paused: true)),
        '일시정지가 길어 러닝을 마쳐요. 30초 안에 재개를 눌러 주세요',
      );
      expect(voiceLine(const VoiceEndWarning(0)), isNull);
    });

    test('탈것 의심·신호 끊김과 그 종료 예고 (결정 0033)', () {
      expect(voiceLine(const VoiceVehicle()), '너무 빨라서 이 구간은 기록에서 뺄게요');
      expect(voiceLine(const VoiceSignalLost()), '신호가 끊겼어요. 밖으로 나오면 다시 찾을게요');
      expect(
        voiceLine(const VoiceSignalLost(locationOff: true)),
        '위치 서비스가 꺼져 있어요',
      );
      expect(
        voiceLine(const VoiceEndWarning(30, signalLost: true)),
        '신호가 오래 끊겨 30초 뒤 러닝을 마쳐요',
      );
    });
  });

  group('cheerLine (F28)', () {
    test('시작·구간·목표 달성 뒤에 캐릭터 이름으로 응원한다', () {
      expect(cheerLine(const VoiceStart(), '말랑이'), '말랑이도 같이 달려요');
      expect(
        cheerLine(const VoiceGoalReached(DistanceGoal(5000)), '말랑이'),
        '말랑이도 기뻐해요. 정말 잘했어요',
      );
      final splits = [
        for (var km = 1; km <= 4; km++)
          cheerLine(
            VoiceSplit(
              km: km,
              elapsed: Duration(minutes: 6 * km),
              avgPaceSecPerKm: 360,
            ),
            '말랑이',
          ),
      ];
      // 구간마다 다른 말, 이름 뒤에는 받침과 상관없는 "도" 만 쓴다.
      expect(splits.toSet().length, 4);
      for (final line in splits) {
        expect(line, isNotNull);
        expect(line, isNot(contains('말랑이가')));
        expect(line, isNot(contains('말랑이이')));
      }
    });

    test('멈춤·경고 사건에는 응원하지 않는다', () {
      for (final e in const [
        VoiceAutoPaused(),
        VoiceAutoResumed(),
        VoiceVehicle(),
        VoiceSignalLost(),
        VoiceEndWarning(30),
      ]) {
        expect(cheerLine(e, '말랑이'), isNull, reason: '$e');
      }
    });
  });

  group('VoiceGuide', () {
    test('이름을 주면 안내 뒤에 응원을 한 줄 더 읽는다', () async {
      final speaker = FakeSpeaker();
      final guide = VoiceGuide(
        speaker: speaker,
        enabled: () async => true,
        petName: () => '말랑이',
      );
      await guide.say(const VoiceStart());
      await guide.say(const VoiceAutoPaused());
      expect(speaker.spoken, ['러닝을 시작해요', '말랑이도 같이 달려요', '일시정지했어요']);
    });

    test('이름을 읽지 못하면 응원 없이 안내만 읽는다', () async {
      final speaker = FakeSpeaker();
      await VoiceGuide(
        speaker: speaker,
        enabled: () async => true,
        petName: () => throw StateError('db'),
      ).say(const VoiceStart());
      expect(speaker.spoken, ['러닝을 시작해요']);
    });

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

    test('문구는 부른 순서대로 한 줄씩 읽고 서로 끊지 않는다', () {
      fakeAsync((async) {
        final speaker = FakeSpeaker()..speakTime = const Duration(seconds: 2);
        final guide = VoiceGuide(speaker: speaker, enabled: () async => true);
        guide.say(const VoiceStart());
        guide.say(const VoiceAutoPaused());
        guide.say(const VoiceAutoResumed());
        async.elapse(const Duration(seconds: 10));
        expect(speaker.spoken, ['러닝을 시작해요', '일시정지했어요', '다시 기록해요']);
        expect(speaker.cutOff, isEmpty);
      });
    });

    test('읽기 끝 신호가 오지 않아도 15초 뒤 다음 문구를 읽는다', () {
      fakeAsync((async) {
        final speaker = FakeSpeaker()..speakTime = const Duration(minutes: 5);
        final guide = VoiceGuide(speaker: speaker, enabled: () async => true);
        guide.say(const VoiceStart());
        guide.say(const VoiceAutoPaused());
        async.elapse(const Duration(seconds: 16));
        expect(speaker.spoken, ['러닝을 시작해요', '일시정지했어요']);
      });
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
