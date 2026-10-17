import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../data/app_database.dart';
import '../data/drift_run_repository.dart';
import '../data/geolocator_location_source.dart';
import '../data/location_source.dart';
import '../data/run_repository.dart';
import 'app_lifecycle.dart';
import 'run_controller.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.production();
  ref.onDispose(db.close);
  return db;
});

final runRepositoryProvider = Provider<RunRepository>(
  (ref) => DriftRunRepository(ref.watch(appDatabaseProvider)),
);

final locationSourceProvider = Provider<LocationSource>(
  (_) => GeolocatorLocationSource(),
);

final clockProvider = Provider<Clock>((_) => DateTime.now);

final appLifecycleProvider = Provider<AppLifecycle>((ref) {
  final lifecycle = FlutterAppLifecycle();
  ref.onDispose(lifecycle.dispose);
  return lifecycle;
});

final runControllerProvider = NotifierProvider<RunController, RunViewState>(
  RunController.new,
);
