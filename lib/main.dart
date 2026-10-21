import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/local_notifications.dart';
import 'run/app/providers.dart';
import 'run/app/run_guard.dart';

/// E2E 용. 디버그 빌드에서만 자동 종료 기준(초)을 줄인다. 릴리스는 무시한다.
const _stillEndSec = String.fromEnvironment('RUN_STILL_END_SEC');
const _pauseEndSec = String.fromEnvironment('RUN_PAUSE_END_SEC');
const _endWarningSec = String.fromEnvironment('RUN_END_WARNING_SEC');
const _autoEndMaxSec = String.fromEnvironment('RUN_AUTO_END_MAX_SEC');
const _autoEndFastSec = String.fromEnvironment('RUN_AUTO_END_FAST_SEC');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final notificationActions = registerRunNotificationActionPort();
  final guard = kDebugMode
      ? runGuardConfigFromSeconds(
          stillSec: _stillEndSec,
          pausedSec: _pauseEndSec,
          warningSec: _endWarningSec,
          maxSec: _autoEndMaxSec,
          fastSec: _autoEndFastSec,
        )
      : null;
  runApp(
    ProviderScope(
      overrides: [
        runNotificationActionsProvider.overrideWithValue(notificationActions),
        if (guard != null) runGuardConfigProvider.overrideWithValue(guard),
      ],
      child: const RunmagochiApp(),
    ),
  );
}
