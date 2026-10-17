import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Runs extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get status => text()(); // active | completed
  RealColumn get distanceM => real().withDefault(const Constant(0))();
  IntColumn get movingTimeS => integer().withDefault(const Constant(0))();
  RealColumn get avgPaceSecPerKm => real().nullable()();
  RealColumn get calories => real().withDefault(const Constant(0))();
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get encodedRoute => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class RunPoints extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(Runs, #id)();
  IntColumn get segment => integer()();
  DateTimeColumn get time => dateTime()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get accuracy => real()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SplitRow')
class Splits extends Table {
  TextColumn get id => text()();
  TextColumn get runId => text().references(Runs, #id)();
  IntColumn get idx => integer()();
  RealColumn get distanceM => real()();
  IntColumn get durationMs => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Avatars extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get kind => text().withDefault(const Constant('default'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WeeklyGoals extends Table {
  TextColumn get id => text()();
  TextColumn get weekStart => text()(); // 현지 날짜 YYYY-MM-DD
  RealColumn get targetM => real()();
  DateTimeColumn get achievedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {weekStart},
  ];
}

class XpTxns extends Table {
  TextColumn get id => text()();
  IntColumn get amount => integer()();
  TextColumn get reason => text()(); // distance | weeklyGoal
  TextColumn get runId => text().nullable().references(Runs, #id)();
  TextColumn get weekStart => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {runId, reason},
    {weekStart, reason},
  ];
}

@DriftDatabase(tables: [Runs, RunPoints, Splits, Avatars, WeeklyGoals, XpTxns])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.production() : super(driftDatabase(name: 'runmagochi'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(avatars);
        await m.createTable(weeklyGoals);
        await m.createTable(xpTxns);
      }
    },
  );

  // 밀리초까지 보존하고 문자열 정렬이 시간순이 되도록 ISO-8601 문자열로 저장한다.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}
