import 'package:flutter/foundation.dart' show debugPrint;

import '../../core/format.dart';
import '../data/run_progress_notifier.dart'
    show pausedEndWarningBody, pausedEndWarningTitle, signalLostNotice;
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

/// 탈것 의심으로 기록을 멈춤 (결정 0033).
final class VoiceVehicle extends VoiceEvent {
  const VoiceVehicle();
}

/// 신호 끊김으로 기록을 멈춤 (결정 0033). [locationOff] 면 위치 서비스가 꺼져 끊겼다.
final class VoiceSignalLost extends VoiceEvent {
  const VoiceSignalLost({this.locationOff = false});

  final bool locationOff;
}

/// 오래 멈춤으로 러닝이 곧 끝난다는 예고. [secondsLeft] 초 뒤 끝난다.
/// [paused] 는 사용자 일시정지다(움직여도 풀리지 않고 재개만 푼다).
/// [signalLost] 는 신호 끊김이 오래 이어진 경우다.
final class VoiceEndWarning extends VoiceEvent {
  const VoiceEndWarning(
    this.secondsLeft, {
    this.paused = false,
    this.signalLost = false,
  });

  final int secondsLeft;
  final bool paused;
  final bool signalLost;
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
  VoiceVehicle() => '너무 빨라서 이 구간은 기록에서 뺄게요',
  VoiceSignalLost(:final locationOff) =>
    locationOff ? '위치 서비스가 꺼져 있어요' : signalLostNotice,
  VoiceEndWarning(:final secondsLeft, :final paused, :final signalLost)
      when secondsLeft > 0 =>
    paused
        ? '$pausedEndWarningTitle. $pausedEndWarningBody'
        : signalLost
        ? '신호가 오래 끊겨 $secondsLeft초 뒤 러닝을 마쳐요'
        : '움직이지 않으면 $secondsLeft초 뒤 러닝을 마쳐요',
  VoiceEndWarning() => null,
};

/// 캐릭터 응원 한마디 (F28, 결정 0037). 안내 문구 뒤에 읽는다. 응원하지 않을 사건이면 null.
/// 이름 뒤 조사는 받침과 상관없는 "도" 만 쓴다(말랑이도·토리도).
String? cheerLine(VoiceEvent e, String petName) => switch (e) {
  VoiceStart() => '$petName도 같이 달려요',
  VoiceSplit(:final km) => _splitCheers[(km - 1) % _splitCheers.length](
    petName,
  ),
  VoiceGoalReached() => '$petName도 기뻐해요. 정말 잘했어요',
  _ => null,
};

final List<String Function(String)> _splitCheers = [
  (n) => '$n도 신났어요',
  (n) => '좋아요, 이 느낌 그대로요',
  (n) => '$n도 힘내고 있어요',
  (n) => '숨 고르고, 내 속도로 가요',
  (n) => '벌써 여기까지 왔어요',
];

/// `18분 40초`, `1시간 5분 3초`. 0 인 단위는 읽지 않고(`6분`), 전부 0 이면 `0초`.
String _spokenDuration(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = total % 3600 ~/ 60;
  final s = total % 60;
  final parts = [if (h > 0) '$h시간', if (m > 0) '$m분', if (s > 0) '$s초'];
  return parts.isEmpty ? '0초' : parts.join(' ');
}

/// 한 문장을 읽는 데 기다리는 최대 시간. 읽기 끝 신호가 오지 않아도 줄이 막히지 않게 한다.
const Duration voiceLineTimeout = Duration(seconds: 15);

/// 켜짐 여부를 보고 [Speaker] 로 안내 문구를 읽는다. 문구는 부른 순서대로
/// 한 줄씩 읽어 서로 끊지 않는다. 실패는 로그만 남기고 러닝에는 영향을 주지 않는다.
class VoiceGuide {
  VoiceGuide({required this._speaker, required this._enabled, this._petName});

  final Speaker _speaker;
  final Future<bool> Function() _enabled;

  /// 응원에 쓸 캐릭터 이름(이미 읽어 둔 값). 없거나 읽지 못하면 응원하지 않는다.
  final String? Function()? _petName;

  /// 앞선 문구가 끝나야 다음 문구를 읽도록 잇는 꼬리.
  Future<void> _tail = Future.value();

  /// 켜져 있으면 [event] 의 문구를 읽는다. 어떤 실패도 밖으로 던지지 않는다.
  /// 줄 서기는 부르는 즉시 이뤄져 부른 순서가 읽는 순서다.
  Future<void> say(VoiceEvent event) {
    final line = _safeLine(event);
    if (line == null) return Future.value();
    final cheer = _cheer(event);
    return _tail = _tail.then((_) async {
      await _speakLine(line);
      if (cheer != null) await _speakLine(cheer);
    });
  }

  String? _cheer(VoiceEvent event) {
    try {
      final name = _petName?.call();
      return name == null || name.isEmpty ? null : cheerLine(event, name);
    } catch (e) {
      debugPrint('응원 이름 읽기 실패: $e');
      return null;
    }
  }

  String? _safeLine(VoiceEvent event) {
    try {
      return voiceLine(event);
    } catch (e) {
      debugPrint('음성 안내 실패: $e');
      return null;
    }
  }

  Future<void> _speakLine(String line) async {
    try {
      if (!await _enabled()) return;
      await _speaker.speak(line).timeout(voiceLineTimeout);
    } catch (e) {
      debugPrint('음성 안내 실패: $e');
    }
  }
}
