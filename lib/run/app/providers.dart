import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../data/app_database.dart';
import '../data/drift_run_repository.dart';
import '../data/geolocator_location_source.dart';
import '../data/location_source.dart';
import '../data/run_repository.dart';
import 'run_controller.dart';

final runRepositoryProvider = Provider<RunRepository>((ref) {
  final db = AppDatabase.production();
  ref.onDispose(db.close);
  return DriftRunRepository(db);
});

final locationSourceProvider = Provider<LocationSource>(
  (_) => GeolocatorLocationSource(),
);

final clockProvider = Provider<Clock>((_) => DateTime.now);

final runControllerProvider = NotifierProvider<RunController, RunViewState>(
  RunController.new,
);
