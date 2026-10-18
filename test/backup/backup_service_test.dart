import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/data/drift_growth_repository.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/backup/app/backup_service.dart';
import 'package:runmagochi/backup/data/backup_file_store.dart';
import 'package:runmagochi/backup/data/drift_backup_repository.dart';
import 'package:runmagochi/run/data/app_database.dart';
import 'package:runmagochi/run/data/drift_run_repository.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

class _Files implements BackupFileStore {
  String? toPick;
  bool saveResult = true;
  String? savedName;
  Uint8List? savedBytes;
  int picks = 0;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    savedName = fileName;
    savedBytes = bytes;
    return saveResult;
  }

  @override
  Future<String?> pickJson() async {
    picks++;
    return toPick;
  }
}

class _Growth implements GrowthService {
  int syncs = 0;
  bool fail = false;

  @override
  Future<GrowthGain> sync() async {
    syncs++;
    if (fail) throw StateError('sync');
    return const GrowthGain(
      distanceXp: 0,
      goalBonusXp: 0,
      levelBefore: 1,
      levelAfter: 1,
      stageBefore: 0,
      stageAfter: 0,
    );
  }

  @override
  Future<T> exclusive<T>(Future<T> Function() job) => job();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [getRun] 이 상세를 읽은 뒤 [hold] 가 풀릴 때까지 멈춰, sync 가 도는 중인 상태를 만든다.
class _HeldRuns implements RunRepository {
  _HeldRuns(this._inner);
  final RunRepository _inner;
  Completer<void>? hold;
  final reading = Completer<void>();

  @override
  Future<RunDetail?> getRun(String id) async {
    final d = await _inner.getRun(id);
    if (!reading.isCompleted) reading.complete();
    await hold?.future;
    return d;
  }

  @override
  Future<List<RunListItem>> listRuns() => _inner.listRuns();
  @override
  Future<(double, int)> weeklyTotal(DateTime now) => _inner.weeklyTotal(now);
  @override
  Future<Map<String, DateTime>> deletedRunStarts(Set<String> ids) =>
      _inner.deletedRunStarts(ids);
  @override
  Future<Set<String>> existingRunIds(Set<String> ids) =>
      _inner.existingRunIds(ids);
  @override
  Future<Map<String, DateTime>> completedRunRevisions() =>
      _inner.completedRunRevisions();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final _t = DateTime.utc(2026, 10, 5, 7);
final _now = DateTime(2026, 10, 18, 9);

Future<void> _addRun(AppDatabase db, String id) => db
    .into(db.runs)
    .insert(
      RunsCompanion.insert(
        id: id,
        startedAt: _t,
        status: 'completed',
        createdAt: _t,
        updatedAt: _t,
      ),
    );

Future<List<String>> _runIds(AppDatabase db) async =>
    ((await db.select(db.runs).get()).map((r) => r.id).toList()..sort());

void main() {
  late AppDatabase src;
  late AppDatabase dst;
  late _Files files;
  late _Growth growth;
  late bool active;

  BackupService service(AppDatabase db) => BackupService(
    DriftBackupRepository(db),
    files,
    growth,
    () async => active,
    () => _now,
  );

  setUp(() {
    src = AppDatabase(NativeDatabase.memory());
    dst = AppDatabase(NativeDatabase.memory());
    files = _Files();
    growth = _Growth();
    active = false;
  });
  tearDown(() async {
    await src.close();
    await dst.close();
  });

  test('내보내기는 날짜 이름으로 JSON 을 저장한다', () async {
    await _addRun(src, 'r1');
    final r = await service(src).export();
    expect(r, isA<BackupDone>());
    expect(files.savedName, 'runmagochi-backup-20261018.json');
    final json = jsonDecode(utf8.decode(files.savedBytes!)) as Map;
    expect(json['format'], 'runmagochi-backup');
  });

  test('저장을 취소하면 cancelled', () async {
    files.saveResult = false;
    expect(await service(src).export(), isA<BackupCancelled>());
  });

  test('러닝 중에는 내보내기도 막는다', () async {
    active = true;
    expect(await service(src).export(), isA<BackupBlockedByRun>());
    expect(files.savedName, isNull);
  });

  test('파일 선택을 취소하면 아무것도 안 한다', () async {
    await _addRun(dst, 'old');
    expect(await service(dst).import(), isA<BackupCancelled>());
    expect(await _runIds(dst), ['old']);
    expect(growth.syncs, 0);
  });

  test('러닝 중에는 가져오기를 막고 파일 선택창을 띄우지 않는다', () async {
    active = true;
    expect(await service(dst).import(), isA<BackupBlockedByRun>());
    expect(files.picks, 0);
    expect(growth.syncs, 0);
  });

  test('가져오면 데이터를 바꾸고 성장을 다시 계산한다', () async {
    await _addRun(src, 'new');
    await service(src).export();
    files.toPick = utf8.decode(files.savedBytes!);
    await _addRun(dst, 'old');
    expect(await service(dst).import(), isA<BackupDone>());
    expect(await _runIds(dst), ['new']);
    expect(growth.syncs, 1);
  });

  test('깨진 파일은 형식 메시지로 실패하고 DB 는 그대로다', () async {
    await _addRun(dst, 'old');
    files.toPick = '{"format": "other"}';
    final r = await service(dst).import();
    expect(r, isA<BackupFailed>());
    expect((r as BackupFailed).message, isNotEmpty);
    expect(r.message, isNot('백업 파일을 가져오지 못했어요'));
    expect(await _runIds(dst), ['old']);
    expect(growth.syncs, 0);
  });

  test('가져오기는 도는 중인 sync 가 끝난 뒤에 DB 를 바꾸고, 옛 러닝 경험치가 섞이지 않는다', () async {
    RunSummary summary(DateTime start, double m) => RunSummary(
      startedAt: start,
      endedAt: start.add(const Duration(minutes: 40)),
      distanceM: m,
      movingTime: const Duration(minutes: 35),
      avgPaceSecPerKm: 360,
      calories: 0,
      name: '러닝',
      splits: const [],
      points: const [],
    );
    Future<String> complete(RunRepository repo, DateTime at, double m) async {
      final id = await repo.createActiveRun(at);
      await repo.completeRun(id, summary(at, m));
      return id;
    }

    // 백업: 3km 러닝 1건과 그 경험치(30).
    final srcRuns = DriftRunRepository(src);
    final srcGrowth = DriftGrowthRepository(src);
    await complete(srcRuns, DateTime(2026, 10, 13, 7), 3000);
    await GrowthService(srcRuns, srcGrowth, () => _now).sync();
    final importedXp = await srcGrowth.totalXp();
    expect(importedXp, 30);
    await service(src).export();
    files.toPick = utf8.decode(files.savedBytes!);

    // 지금 기기: 8km 러닝 1건, 아직 경험치 없음. sync 가 상세를 읽은 채 멈춘다.
    final dstGrowth = DriftGrowthRepository(dst);
    final runs = _HeldRuns(DriftRunRepository(dst))..hold = Completer<void>();
    final oldId = await complete(
      DriftRunRepository(dst),
      DateTime(2026, 10, 14, 7),
      8000,
    );
    final realGrowth = GrowthService(runs, dstGrowth, () => _now);
    final syncing = realGrowth.sync();
    await runs.reading.future;

    final importing = BackupService(
      DriftBackupRepository(dst),
      files,
      realGrowth,
      () async => false,
      () => _now,
    ).import();
    await pumpEventQueue();
    runs.hold!.complete();
    await syncing;
    expect(await importing, isA<BackupDone>());

    expect(await dstGrowth.totalXp(), importedXp);
    // 옛 러닝 경험치가 가져온 DB 에 쓰인 적이 없다(무른 행도 없다).
    final xpRows = await dst.select(dst.xpTxns).get();
    expect(xpRows.where((x) => x.runId == oldId), isEmpty);
  });

  test('성장 재계산이 실패해도 가져오기는 성공이다', () async {
    await _addRun(src, 'new');
    await service(src).export();
    files.toPick = utf8.decode(files.savedBytes!);
    growth.fail = true;
    expect(await service(dst).import(), isA<BackupDone>());
    expect(await _runIds(dst), ['new']);
  });
}
