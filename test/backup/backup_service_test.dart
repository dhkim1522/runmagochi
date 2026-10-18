import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/growth_service.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/backup/app/backup_service.dart';
import 'package:runmagochi/backup/data/backup_file_store.dart';
import 'package:runmagochi/backup/data/drift_backup_repository.dart';
import 'package:runmagochi/run/data/app_database.dart';

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  test('성장 재계산이 실패해도 가져오기는 성공이다', () async {
    await _addRun(src, 'new');
    await service(src).export();
    files.toPick = utf8.decode(files.savedBytes!);
    growth.fail = true;
    expect(await service(dst).import(), isA<BackupDone>());
    expect(await _runIds(dst), ['new']);
  });
}
