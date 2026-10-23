import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../run/app/providers.dart';
import '../data/drift_profile_repository.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => DriftProfileRepository(ref.watch(appDatabaseProvider)),
);

/// 저장된 화면 모드. 읽기 전에는 시스템을 따른다. 바꾸거나 가져온 뒤 invalidate 한다.
final themeModeProvider = FutureProvider<ThemeMode>(
  (ref) => ref.read(profileRepositoryProvider).themeMode(),
);
