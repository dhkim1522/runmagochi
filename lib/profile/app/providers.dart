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

/// 첫 실행 안내를 마쳤는지. 읽지 못하면 사용자를 첫 실행에 가두지 않고 마친 것으로 본다.
/// 첫 실행을 마치거나 설정에서 초기화한 뒤 invalidate 한다.
final onboardedProvider = FutureProvider<bool>((ref) async {
  try {
    return await ref.read(profileRepositoryProvider).isOnboarded();
  } catch (_) {
    return true;
  }
});
