import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'run/app/providers.dart';
import 'run/app/run_guard.dart';

/// E2E 용. 디버그 빌드에서만 자동 종료 기준(초)을 줄인다. 릴리스는 무시한다.
const _autoEndIdleSec = String.fromEnvironment('RUN_AUTO_END_IDLE_SEC');
const _autoEndMaxSec = String.fromEnvironment('RUN_AUTO_END_MAX_SEC');

void main() {
  final guard = kDebugMode
      ? runGuardConfigFromSeconds(
          idleSec: _autoEndIdleSec,
          maxSec: _autoEndMaxSec,
        )
      : null;
  runApp(
    ProviderScope(
      overrides: [
        if (guard != null) runGuardConfigProvider.overrideWithValue(guard),
      ],
      child: const RunmagochiApp(),
    ),
  );
}
