import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/backup/data/drift_backup_repository.dart';
import 'package:runmagochi/backup/domain/backup_codec.dart';
import 'package:runmagochi/run/data/app_database.dart';

final _t = DateTime.utc(2026, 10, 5, 7, 30, 15, 123);
final _now = DateTime.utc(2026, 10, 18, 1);

Future<void> _seed(AppDatabase db, {String suffix = ''}) async {
  Future<void> run(String id, String status, {DateTime? deletedAt}) => db
      .into(db.runs)
      .insert(
        RunsCompanion.insert(
          id: id,
          startedAt: _t,
          status: status,
          createdAt: _t,
          updatedAt: _t,
          endedAt: Value(status == 'completed' ? _t : null),
          distanceM: const Value(5012.5),
          avgPaceSecPerKm: const Value(331.25),
          deletedAt: Value(deletedAt),
          encodedRoute: const Value('_p~iF~ps|U'),
          goalM: status == 'completed' ? const Value(5000) : const Value(null),
        ),
      );
  await run('r1$suffix', 'completed');
  await run('r2$suffix', 'completed', deletedAt: _t);
  await run('ra$suffix', 'active');
  for (final r in ['r1$suffix', 'ra$suffix']) {
    await db
        .into(db.splits)
        .insert(
          SplitsCompanion.insert(
            id: 's-$r',
            runId: r,
            idx: 0,
            distanceM: 1000,
            durationMs: 330000,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await db
        .into(db.runPoints)
        .insert(
          RunPointsCompanion.insert(
            id: 'p-$r',
            runId: r,
            segment: 0,
            time: _t,
            latitude: 37.5,
            longitude: 127.0,
            accuracy: 5,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
  }
  await db
      .into(db.xpTxns)
      .insert(
        XpTxnsCompanion.insert(
          id: 'x1$suffix',
          amount: 50,
          reason: 'distance',
          runId: Value('r1$suffix'),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.xpTxns)
      .insert(
        XpTxnsCompanion.insert(
          id: 'x2$suffix',
          amount: 30,
          reason: 'weeklyGoal',
          weekStart: const Value('2026-10-05'),
          createdAt: _t,
          updatedAt: _t,
          deletedAt: Value(_t),
        ),
      );
  await db
      .into(db.xpTxns)
      .insert(
        XpTxnsCompanion.insert(
          id: 'xa$suffix',
          amount: 1,
          reason: 'distance',
          runId: Value('ra$suffix'),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.avatars)
      .insert(
        AvatarsCompanion.insert(
          id: 'a1$suffix',
          name: '러니$suffix',
          kind: const Value('chick'),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.weeklyGoals)
      .insert(
        WeeklyGoalsCompanion.insert(
          id: 'g1$suffix',
          weekStart: '2026-10-05',
          targetM: 10000,
          achievedAt: Value(_t),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
  await db
      .into(db.profiles)
      .insert(
        ProfilesCompanion.insert(
          id: 'pf$suffix',
          weightKg: const Value(70.5),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
}

Future<Map<String, List<Object?>>> _dump(AppDatabase db) async => {
  'runs': [for (final r in await db.select(db.runs).get()) r.toJson()],
  'points': [for (final r in await db.select(db.runPoints).get()) r.toJson()],
  'splits': [for (final r in await db.select(db.splits).get()) r.toJson()],
  'avatars': [for (final r in await db.select(db.avatars).get()) r.toJson()],
  'goals': [for (final r in await db.select(db.weeklyGoals).get()) r.toJson()],
  'xp': [for (final r in await db.select(db.xpTxns).get()) r.toJson()],
  'profiles': [for (final r in await db.select(db.profiles).get()) r.toJson()],
};

void main() {
  late AppDatabase src;
  late AppDatabase dst;

  setUp(() {
    src = AppDatabase(NativeDatabase.memory());
    dst = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await src.close();
    await dst.close();
  });

  test('내보내기 파일에는 형식 필드가 있고 진행 중 러닝·RunPoint 는 없다', () async {
    await _seed(src);
    final json = await DriftBackupRepository(src).exportJson(_now);
    final m = jsonDecode(json) as Map<String, dynamic>;
    expect(m['format'], 'runmagochi-backup');
    expect(m['version'], 1);
    expect(m['schemaVersion'], 7);
    expect(m['exportedAt'], '2026-10-18T01:00:00.000Z');
    final tables = m['tables'] as Map<String, dynamic>;
    expect(tables.keys, isNot(contains('runPoints')));
    final runs = tables['runs'] as List;
    expect(runs.map((r) => r['id']), unorderedEquals(['r1', 'r2']));
    expect((tables['splits'] as List).map((r) => r['id']), ['s-r1']);
    expect(
      (tables['xpTxns'] as List).map((r) => r['id']),
      unorderedEquals(['x1', 'x2']),
    );
    // 삭제 표시 행은 들어간다.
    expect(runs.firstWhere((r) => r['id'] == 'r2')['deletedAt'], isNotNull);
  });

  test('내보내기 → 빈 DB 가져오기 → 모든 테이블이 같다 (삭제 행 포함)', () async {
    await _seed(src);
    final json = await DriftBackupRepository(src).exportJson(_now);
    await DriftBackupRepository(dst).importJson(json);

    final a = await _dump(src);
    final b = await _dump(dst);
    // 진행 중 러닝과 딸린 행, 점은 옮겨지지 않는다.
    expect(b['points'], isEmpty);
    expect(b['runs'], hasLength(2));
    for (final k in ['runs', 'splits', 'avatars', 'goals', 'xp', 'profiles']) {
      final expected = a[k]!.where((r) {
        final m = r as Map<String, dynamic>;
        return m['status'] != 'active' &&
            m['runId'] != 'ra' &&
            !(k == 'splits' && m['runId'] == 'ra');
      }).toList();
      expect(b[k], unorderedEquals(expected), reason: k);
    }
    // 두 번째 내보내기도 같은 내용이다.
    final again = await DriftBackupRepository(dst).exportJson(_now);
    expect(again, json);
  });

  test('v4 왕복에 러닝 목표가 유지된다', () async {
    await _seed(src);
    final json = await DriftBackupRepository(src).exportJson(_now);
    await DriftBackupRepository(dst).importJson(json);
    final runs = await dst.select(dst.runs).get();
    expect(runs.map((r) => r.goalM), [5000, 5000]);
  });

  test('v3 백업 파일(goalM 없음)을 가져오면 목표가 null 이다', () async {
    await _seed(src);
    final m =
        jsonDecode(await DriftBackupRepository(src).exportJson(_now))
            as Map<String, dynamic>;
    m['schemaVersion'] = 3;
    for (final r in (m['tables'] as Map)['runs'] as List) {
      (r as Map).remove('goalM');
    }
    await DriftBackupRepository(dst).importJson(jsonEncode(m));
    final runs = await dst.select(dst.runs).get();
    expect(runs, hasLength(2));
    expect(runs.map((r) => r.goalM), [null, null]);
  });

  test('v4 백업 파일(코인·보유·장착 없음)을 가져오면 코인·보유 없이 열린다', () async {
    await _seed(src);
    final m =
        jsonDecode(await DriftBackupRepository(src).exportJson(_now))
            as Map<String, dynamic>;
    m['schemaVersion'] = 4;
    (m['tables'] as Map).remove('coinTxns');
    (m['tables'] as Map).remove('ownedItems');
    for (final r in (m['tables'] as Map)['avatars'] as List) {
      (r as Map)
        ..remove('hatItemId')
        ..remove('accessoryItemId');
    }
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(jsonEncode(m));
    expect(await dst.select(dst.coinTxns).get(), isEmpty);
    expect(await dst.select(dst.ownedItems).get(), isEmpty);
    final a = (await dst.select(dst.avatars).get()).single;
    expect(a.hatItemId, isNull);
    expect(a.accessoryItemId, isNull);
  });

  test('v5 왕복에 코인·보유·장착이 유지된다', () async {
    await _seed(src);
    await src
        .into(src.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: 'c1',
            amount: 50,
            reason: 'distance',
            runId: const Value('r1'),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await src
        .into(src.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: 'c2',
            amount: -30,
            reason: 'purchase',
            itemId: const Value('hat1'),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await src
        .into(src.ownedItems)
        .insert(
          OwnedItemsCompanion.insert(
            id: 'o1',
            itemId: 'hat1',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await (src.update(
      src.avatars,
    )).write(const AvatarsCompanion(hatItemId: Value('hat1')));
    final json = await DriftBackupRepository(src).exportJson(_now);
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(json);
    final coins = await dst.select(dst.coinTxns).get();
    expect(coins.map((c) => c.id), unorderedEquals(['c1', 'c2']));
    expect((await dst.select(dst.ownedItems).get()).single.itemId, 'hat1');
    expect((await dst.select(dst.avatars).get()).single.hatItemId, 'hat1');
  });

  test('v6 왕복에 시간 목표·배지·음성 안내가 유지된다', () async {
    await _seed(src);
    await (src.update(src.runs)..where((r) => r.id.equals('r1'))).write(
      const RunsCompanion(goalM: Value(null), goalSec: Value(1800)),
    );
    await src
        .into(src.badges)
        .insert(
          BadgesCompanion.insert(
            id: 'b1',
            badgeId: 'first-run',
            runId: const Value('r1'),
            earnedAt: _t,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await src
        .into(src.badges)
        .insert(
          BadgesCompanion.insert(
            id: 'b2',
            badgeId: 'streak-3',
            earnedAt: _t,
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await (src.update(src.profiles)).write(
      const ProfilesCompanion(
        voiceGuide: Value(false),
        themeMode: Value('dark'),
      ),
    );
    final json = await DriftBackupRepository(src).exportJson(_now);
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(json);

    final r1 = (await dst.select(dst.runs).get()).firstWhere(
      (r) => r.id == 'r1',
    );
    expect(r1.goalM, isNull);
    expect(r1.goalSec, 1800);
    final badges = await dst.select(dst.badges).get();
    expect(
      badges.map((b) => b.badgeId),
      unorderedEquals(['first-run', 'streak-3']),
    );
    expect(badges.firstWhere((b) => b.id == 'b1').runId, 'r1');
    expect((await dst.select(dst.profiles).get()).single.voiceGuide, isFalse);
    expect((await dst.select(dst.profiles).get()).single.themeMode, 'dark');
    expect(await DriftBackupRepository(dst).exportJson(_now), json);
  });

  test('v5 백업 파일(시간 목표·배지·음성 안내 없음)을 가져온다', () async {
    await _seed(src);
    final m =
        jsonDecode(await DriftBackupRepository(src).exportJson(_now))
            as Map<String, dynamic>;
    m['schemaVersion'] = 5;
    (m['tables'] as Map).remove('badges');
    for (final r in (m['tables'] as Map)['runs'] as List) {
      (r as Map).remove('goalSec');
    }
    for (final r in (m['tables'] as Map)['profiles'] as List) {
      (r as Map).remove('voiceGuide');
    }
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(jsonEncode(m));
    final runs = await dst.select(dst.runs).get();
    expect(runs.map((r) => r.goalM), [5000, 5000]);
    expect(runs.map((r) => r.goalSec), [null, null]);
    expect(await dst.select(dst.badges).get(), isEmpty);
    expect((await dst.select(dst.profiles).get()).single.voiceGuide, isTrue);
  });

  test('v6 백업 파일(화면 모드 없음)을 가져오면 시스템이다', () async {
    await _seed(src);
    await (src.update(
      src.profiles,
    )).write(const ProfilesCompanion(themeMode: Value('dark')));
    final m =
        jsonDecode(await DriftBackupRepository(src).exportJson(_now))
            as Map<String, dynamic>;
    m['schemaVersion'] = 6;
    for (final r in (m['tables'] as Map)['profiles'] as List) {
      (r as Map).remove('themeMode');
    }
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(jsonEncode(m));
    expect((await dst.select(dst.profiles).get()).single.themeMode, 'system');
  });

  test('가져오면 기존 데이터를 모두 바꾼다 (진행 중 러닝·점 포함)', () async {
    await _seed(src);
    final json = await DriftBackupRepository(src).exportJson(_now);
    await _seed(dst, suffix: '-old');
    await DriftBackupRepository(dst).importJson(json);

    final runs = await dst.select(dst.runs).get();
    expect(runs.map((r) => r.id), unorderedEquals(['r1', 'r2']));
    expect(await dst.select(dst.runPoints).get(), isEmpty);
    expect((await dst.select(dst.avatars).get()).single.id, 'a1');
    expect((await dst.select(dst.profiles).get()).single.id, 'pf');
    expect((await dst.select(dst.weeklyGoals).get()).single.id, 'g1');
  });

  group('잘못된 파일은 오류를 내고 기존 데이터가 그대로다', () {
    late String good;
    setUp(() async {
      await _seed(src);
      good = await DriftBackupRepository(src).exportJson(_now);
      await _seed(dst, suffix: '-old');
    });

    Future<void> expectRejected(String json) async {
      final before = await _dump(dst);
      await expectLater(
        DriftBackupRepository(dst).importJson(json),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            startsWith('백업 파일을 읽을 수 없어요'),
          ),
        ),
      );
      expect(await _dump(dst), before);
    }

    Map<String, dynamic> parsed() => jsonDecode(good) as Map<String, dynamic>;

    test('깨진 JSON', () => expectRejected(good.substring(0, good.length ~/ 2)));
    test('JSON 이 객체가 아님', () => expectRejected('[1,2]'));
    test('형식 이름이 다름', () {
      return expectRejected(jsonEncode(parsed()..['format'] = 'other'));
    });
    test('파일 버전이 다름', () {
      return expectRejected(jsonEncode(parsed()..['version'] = 2));
    });
    test('스키마 버전이 다름', () async {
      await expectRejected(jsonEncode(parsed()..['schemaVersion'] = 8));
      await expectRejected(jsonEncode(parsed()..['schemaVersion'] = 2));
    });
    test('테이블이 없음', () {
      final m = parsed();
      (m['tables'] as Map).remove('splits');
      return expectRejected(jsonEncode(m));
    });
    test('테이블 타입이 틀림', () {
      final m = parsed();
      (m['tables'] as Map)['runs'] = {'a': 1};
      return expectRejected(jsonEncode(m));
    });
    test('행 값 타입이 틀림', () {
      final m = parsed();
      ((m['tables'] as Map)['runs'] as List)[0]['distanceM'] = 'abc';
      return expectRejected(jsonEncode(m));
    });
    test('필수 필드가 빠진 행', () {
      final m = parsed();
      ((m['tables'] as Map)['avatars'] as List)[0].remove('name');
      return expectRejected(jsonEncode(m));
    });
    test('진행 중 러닝이 들어 있음', () {
      final m = parsed();
      ((m['tables'] as Map)['runs'] as List)[0]['status'] = 'active';
      return expectRejected(jsonEncode(m));
    });
  });

  test('내보내기는 한 시점의 스냅샷이다 (도중에 생긴 진행 중 러닝의 구간이 섞이지 않는다)', () async {
    await _seed(src);
    final exporting = DriftBackupRepository(src).exportJson(_now);
    // 내보내기가 첫 읽기를 하는 사이에 새 진행 중 러닝과 구간이 생긴다.
    final writes = Future.wait([
      src
          .into(src.runs)
          .insert(
            RunsCompanion.insert(
              id: 'rb',
              startedAt: _t,
              status: 'active',
              createdAt: _t,
              updatedAt: _t,
            ),
          ),
      src
          .into(src.splits)
          .insert(
            SplitsCompanion.insert(
              id: 's-rb',
              runId: 'rb',
              idx: 0,
              distanceM: 1000,
              durationMs: 330000,
              createdAt: _t,
              updatedAt: _t,
            ),
          ),
    ]);
    final json = await exporting;
    await writes;
    final tables =
        (jsonDecode(json) as Map<String, dynamic>)['tables']
            as Map<String, dynamic>;
    final runIds = {for (final r in tables['runs'] as List) r['id']};
    for (final s in tables['splits'] as List) {
      expect(runIds, contains(s['runId']), reason: '${s['id']}');
    }
  });

  test('가져오기 중 제약 위반이 나면 롤백되어 기존 데이터가 그대로다', () async {
    await _seed(src);
    final m =
        jsonDecode(await DriftBackupRepository(src).exportJson(_now))
            as Map<String, dynamic>;
    // 같은 주의 목표 두 개 → weekStart 유니크 위반 (런·분할은 이미 들어간 뒤)
    final goals = (m['tables'] as Map)['weeklyGoals'] as List;
    goals.add({...goals.first as Map<String, dynamic>, 'id': 'g2'});

    await _seed(dst, suffix: '-old');
    final before = await _dump(dst);
    await expectLater(
      DriftBackupRepository(dst).importJson(jsonEncode(m)),
      throwsA(isA<Object>()),
    );
    expect(await _dump(dst), before);
  });


  test('초기화하면 기록·캐릭터 데이터를 모두 지우고 설정값은 남기며 첫 실행 표시를 지운다', () async {
    await _seed(dst);
    await (dst.update(dst.profiles)..where((p) => p.id.equals('pf'))).write(
      ProfilesCompanion(
        onboardedAt: Value(_t),
        voiceGuide: const Value(false),
        themeMode: const Value('dark'),
      ),
    );
    await dst
        .into(dst.coinTxns)
        .insert(
          CoinTxnsCompanion.insert(
            id: 'c1',
            amount: 10,
            reason: 'distance',
            runId: const Value('r1'),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await dst
        .into(dst.ownedItems)
        .insert(
          OwnedItemsCompanion.insert(
            id: 'o1',
            itemId: 'cap',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    await dst
        .into(dst.badges)
        .insert(
          BadgesCompanion.insert(
            id: 'b1',
            badgeId: 'first_run',
            runId: const Value('r1'),
            earnedAt: _t,
            createdAt: _t,
            updatedAt: _t,
          ),
        );

    await DriftBackupRepository(dst).resetData(_now);

    expect(await dst.select(dst.runs).get(), isEmpty);
    expect(await dst.select(dst.runPoints).get(), isEmpty);
    expect(await dst.select(dst.splits).get(), isEmpty);
    expect(await dst.select(dst.xpTxns).get(), isEmpty);
    expect(await dst.select(dst.coinTxns).get(), isEmpty);
    expect(await dst.select(dst.ownedItems).get(), isEmpty);
    expect(await dst.select(dst.badges).get(), isEmpty);
    expect(await dst.select(dst.weeklyGoals).get(), isEmpty);
    expect(await dst.select(dst.avatars).get(), isEmpty);
    final profile = (await dst.select(dst.profiles).get()).single;
    expect(profile.weightKg, 70.5);
    expect(profile.voiceGuide, isFalse);
    expect(profile.themeMode, 'dark');
    expect(profile.onboardedAt, isNull);
    expect(profile.updatedAt, _now);
  });

  test('프로필이 없을 때 초기화해도 실패하지 않는다', () async {
    await DriftBackupRepository(dst).resetData(_now);
    expect(await dst.select(dst.profiles).get(), isEmpty);
  });
}
