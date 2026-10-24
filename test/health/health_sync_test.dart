import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/health/app/health_sync_service.dart';
import 'package:runmagochi/health/data/health_source.dart';
import 'package:runmagochi/health/domain/health_workout.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/drift_run_repository.dart';

import '../run/ui/fakes.dart';

class _Source implements HealthSource {
  bool available = true;
  bool granted = true;
  bool grantOnRequest = true;
  List<HealthWorkout> workouts = [];
  int requests = 0;
  DateTime? since;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> hasPermission() async => granted;

  @override
  Future<bool> requestPermission() async {
    requests++;
    if (grantOnRequest) granted = true;
    return granted;
  }

  @override
  Future<List<HealthWorkout>> readRunningWorkouts(DateTime since) async {
    this.since = since;
    return workouts;
  }
}

HealthWorkout _w(String id, DateTime start, {double km = 5}) => HealthWorkout(
  id: id,
  startedAt: start,
  endedAt: start.add(Duration(minutes: (km * 6).round())),
  distanceM: km * 1000,
  energyKcal: 300,
  isRunning: true,
  writtenByThisApp: false,
);

void main() {
  late AppDatabase db;
  late DriftRunRepository runs;
  late _Source source;
  late FakeProfile profile;
  late FakeGrowthService growth;
  late HealthSyncService service;
  final now = DateTime(2026, 10, 24, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    runs = DriftRunRepository(db);
    source = _Source();
    profile = FakeProfile()..healthOn = true;
    growth = FakeGrowthService(growthState());
    service = HealthSyncService(
      profile: profile,
      source: source,
      store: runs,
      growth: growth,
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  test('건강 앱의 러닝을 러닝 기록으로 들이고 성장을 다시 계산한다', () async {
    source.workouts = [_w('w1', DateTime(2026, 10, 20, 7))];
    final n = await service.sync();
    expect(n, 1);
    final list = await runs.listRuns();
    expect(list, hasLength(1));
    expect(list.single.distanceM, 5000);
    expect(list.single.name, '화요일 아침 러닝');
    expect(growth.syncs, 1);
    final row = (await db.select(db.runs).get()).single;
    expect(row.source, 'health:w1');
    expect(row.status, 'completed');
  });

  test('같은 운동은 다시 들이지 않는다', () async {
    source.workouts = [_w('w1', DateTime(2026, 10, 20, 7))];
    await service.sync();
    expect(await service.sync(), 0);
    expect(await runs.listRuns(), hasLength(1));
  });

  test('지운 기록도 다시 들이지 않는다', () async {
    source.workouts = [_w('w1', DateTime(2026, 10, 20, 7))];
    await service.sync();
    final id = (await runs.listRuns()).single.id;
    await runs.deleteRun(id);
    expect(await service.sync(), 0);
    expect(await runs.listRuns(), isEmpty);
  });

  test('꺼져 있거나 기기가 지원하지 않거나 권한이 없으면 읽지 않는다', () async {
    source.workouts = [_w('w1', DateTime(2026, 10, 20, 7))];
    profile.healthOn = false;
    expect(await service.sync(), 0);
    profile.healthOn = true;
    source.available = false;
    expect(await service.sync(), 0);
    source.available = true;
    source.granted = false;
    expect(await service.sync(), 0);
    expect(source.since, isNull);
    expect(source.requests, 0);
  });

  test('처음 켜면 최근 30일 안의 운동만 읽는다', () async {
    await service.sync();
    expect(source.since, now.subtract(const Duration(days: 30)));
  });

  test('들인 뒤에는 마지막으로 들인 시각 이후만 읽는다', () async {
    source.workouts = [_w('w1', DateTime(2026, 10, 20, 7))];
    await service.sync();
    await service.sync();
    expect(
      source.since,
      DateTime(2026, 10, 20, 7).subtract(const Duration(days: 1)),
    );
  });

  test('권한 요청이 거절되면 켜짐을 되돌린다', () async {
    source.granted = false;
    source.grantOnRequest = false;
    expect(await service.enable(), isFalse);
    expect(profile.healthOn, isFalse);
    source.grantOnRequest = true;
    expect(await service.enable(), isTrue);
    expect(profile.healthOn, isTrue);
  });

  test('쓸 수 있는 기기인지 알려 준다', () async {
    expect(await service.isSupported(), isTrue);
    source.available = false;
    expect(await service.isSupported(), isFalse);
  });

  test('읽기에 실패해도 던지지 않는다', () async {
    final bad = HealthSyncService(
      profile: profile,
      source: _Throwing(),
      store: runs,
      growth: growth,
      clock: () => now,
    );
    expect(await bad.sync(), 0);
  });
}

class _Throwing implements HealthSource {
  @override
  Future<bool> isAvailable() async => throw StateError('x');
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<List<HealthWorkout>> readRunningWorkouts(DateTime since) async => [];
}
