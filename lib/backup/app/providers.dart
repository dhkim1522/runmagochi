import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../run/app/providers.dart';
import '../../run/domain/run_engine.dart';
import '../data/backup_file_store.dart';
import '../data/backup_repository.dart';
import '../data/drift_backup_repository.dart';
import 'backup_service.dart';

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => DriftBackupRepository(ref.watch(appDatabaseProvider)),
);

final backupFileStoreProvider = Provider<BackupFileStore>(
  (_) => const FilePickerBackupFileStore(),
);

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(backupRepositoryProvider),
    ref.watch(backupFileStoreProvider),
    ref.watch(growthServiceProvider),
    () async {
      final state = ref.read(runControllerProvider).snapshot.state;
      if (state == RunState.recording ||
          state == RunState.paused ||
          state == RunState.autoPaused) {
        return true;
      }
      return await ref.read(runRepositoryProvider).findActiveRun() != null;
    },
    ref.watch(clockProvider),
  );
});
