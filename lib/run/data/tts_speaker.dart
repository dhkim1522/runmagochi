import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

/// 문장을 소리 내어 읽는 곳. [speak] 는 다 읽은 뒤 끝난다. 구현은 기기 음성 합성(TTS)이다.
abstract interface class Speaker {
  /// [text] 를 읽고 읽기가 끝나면 완료한다. 겹쳐 부르면 앞 문장이 끊길 수 있으므로
  /// 부르는 쪽(VoiceGuide)이 한 줄씩 부른다.
  Future<void> speak(String text);
}

/// `flutter_tts` 로 한국어(`ko-KR`)를 읽는다. 다른 앱 소리는 줄였다가 되돌린다(덕킹).
///
/// 첫 [speak] 때 엔진을 설정한다. 설정 단계의 실패는 로그만 남기고 그대로
/// 읽기를 시도하며, 읽기 실패는 던진다(부르는 쪽이 로그만 남긴다).
class TtsSpeaker implements Speaker {
  TtsSpeaker([FlutterTts? tts]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  Future<void>? _ready;

  Future<void> _setUp() async {
    Future<void> step(String name, Future<dynamic> Function() job) async {
      try {
        await job();
      } catch (e) {
        debugPrint('음성 안내: $name 설정 실패 $e');
      }
    }

    try {
      // 한국어 음성이 없으면 성공(1)이 아닌 값이 온다. 영어 음성으로 읽지 않게 로그로 남긴다.
      final result = await _tts.setLanguage('ko-KR');
      if (result != 1) debugPrint('음성 안내: 한국어(ko-KR) 설정 실패 $result');
    } catch (e) {
      debugPrint('음성 안내: 언어 설정 실패 $e');
    }
    // 다 읽어야 speak 가 끝나 VoiceGuide 가 문구를 한 줄씩 읽는다.
    await step('읽기 완료 대기', () => _tts.awaitSpeakCompletion(true));
    if (kIsWeb) return;
    if (Platform.isIOS) {
      // 재생 범주에서 다른 앱 소리를 줄이고, 다 읽으면 되돌린다.
      await step(
        '오디오 세션',
        () => _tts
            .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, const [
              IosTextToSpeechAudioCategoryOptions.duckOthers,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ], IosTextToSpeechAudioMode.spokenAudio),
      );
    } else if (Platform.isAndroid) {
      // 내비게이션 안내 용도의 오디오 속성: 음악은 작아졌다 돌아온다.
      await step('오디오 속성', _tts.setAudioAttributesForNavigation);
      // 1 = QUEUE_ADD: 앞 문장을 끊지 않고 뒤에 잇는다.
      await step('큐 모드', () => _tts.setQueueMode(1));
    }
  }

  @override
  Future<void> speak(String text) async {
    await (_ready ??= _setUp());
    // focus: 안드로이드에서 일시적 오디오 포커스(소리 줄임)를 요청한다.
    // 다 읽으면 플러그인이 포커스를 놓아 다른 앱 소리가 돌아온다.
    await _tts.speak(text, focus: true);
  }
}
