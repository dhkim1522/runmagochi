import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/format.dart';
import '../data/tts_speaker.dart';
import '../domain/run_goal.dart';

/// 음성 안내를 낼 사건.
sealed class VoiceEvent {
  const VoiceEvent();
}

/// 러닝 시작.
final class VoiceStart extends VoiceEvent {
  const VoiceStart();
}

/// 1km 구간 완료. [km] 는 완료한 누적 킬로미터(1, 2, 3 …).
/// [elapsed] 는 그 경계까지의 움직인 시간(일시정지·자동 일시정지 제외),
/// [avgPaceSecPerKm] 은 그 경계까지의 평균 페이스(= 움직인 시간 ÷ 킬로미터).
final class VoiceSplit extends VoiceEvent {
  const VoiceSplit({
    required this.km,
    required this.elapsed,
    required this.avgPaceSecPerKm,
  });

  final int km;
  final Duration elapsed;
  final double avgPaceSecPerKm;
}

/// 오늘 목표 달성.
final class VoiceGoalReached extends VoiceEvent {
  const VoiceGoalReached(this.goal);

  final RunGoal goal;
}

/// 자동 일시정지.
final class VoiceAutoPaused extends VoiceEvent {
  const VoiceAutoPaused();
}

/// 자동 재개.
final class VoiceAutoResumed extends VoiceEvent {
  const VoiceAutoResumed();
}

/// 오래 멈춤으로 러닝이 곧 끝난다는 예고. [secondsLeft] 초 뒤 끝난다.
final class VoiceEndWarning extends VoiceEvent {
  const VoiceEndWarning(this.secondsLeft);

  final int secondsLeft;
}

/// 사건의 안내 문구. 읽지 않을 사건이면 null.
String? voiceLine(VoiceEvent e) => switch (e) {
  VoiceStart() => '러닝을 시작해요',
  VoiceSplit(:final km, :final elapsed, :final avgPaceSecPerKm) =>
    '$km킬로미터. 시간 ${_spokenDuration(elapsed)}. '
        '평균 페이스 ${_spokenDuration(Duration(seconds: avgPaceSecPerKm.round()))}.',
  VoiceGoalReached(:final goal) => switch (goal) {
    DistanceGoal(:final meters) => '목표 ${formatTargetKm(meters)}킬로미터를 채웠어요',
    TimeGoal(:final time) => '목표 ${time.inMinutes}분을 채웠어요',
  },
  VoiceAutoPaused() => '일시정지했어요',
  VoiceAutoResumed() => '다시 기록해요',
  VoiceEndWarning(:final secondsLeft) when secondsLeft > 0 =>
    '움직이지 않으면 $secondsLeft초 뒤 러닝을 마쳐요',
  VoiceEndWarning() => null,
};

/// `18분 40초`, `1시간 5분 3초`. 0 인 단위는 읽지 않고(`6분`), 전부 0 이면 `0초`.
String _spokenDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = total % 3600 ~/ 60;
  final s = total % 60;
  final parts = [if (h > 0) '$h시간', if (m > 0) '$m분', if (s > 0) '$s초'];
  return parts.isEmpty ? '0초' : parts.join(' ');
}

/// 켜짐 여부를 보고 [Speaker] 로 안내 문구를 읽는다. 실패는 로그만 남기고
/// 러닝에는 영향을 주지 않는다.
class VoiceGuide {
  VoiceGuide({required this._speaker, required this._enabled});

  final Speaker _speaker;
  final Future<bool> Function() _enabled;

  /// 켜져 있으면 [event] 의 문구를 읽는다. 어떤 실패도 밖으로 던지지 않는다.
  Future<void> say(VoiceEvent event) async {
    try {
      final line = voiceLine(event);
      if (line == null) return;
      if (!await _enabled()) return;
      await _speaker.speak(line);
    } catch (e) {
      debugPrint('음성 안내 실패: $e');
    }
  }
}
