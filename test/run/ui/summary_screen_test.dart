import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/core/ui/clay.dart';
import 'package:runmagochi/run/ui/split_pace_chart.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';

import 'fakes.dart';

final _splits = [
  const Split(index: 1, distanceM: 1000, duration: Duration(seconds: 385)),
  const Split(index: 2, distanceM: 1000, duration: Duration(seconds: 390)),
  const Split(index: 3, distanceM: 500, duration: Duration(seconds: 200)),
];

RunSummary _summary() => RunSummary(
  startedAt: DateTime(2026, 10, 16, 17, 51),
  endedAt: DateTime(2026, 10, 16, 18, 20),
  distanceM: 2500,
  movingTime: const Duration(minutes: 16, seconds: 15),
  avgPaceSecPerKm: 390,
  calories: 168.35,
  name: '금요일 오후 러닝',
  splits: _splits,
  points: [
    for (var i = 0; i < 3; i++)
      LocationSample(
        time: DateTime(2026, 10, 16, 17, 51 + i),
        latitude: 37.5 + i * 0.001,
        longitude: 127.0 + i * 0.001,
        accuracy: 5,
      ),
  ],
);

Future<void> pump(WidgetTester tester, Widget screen, {FakeRepo? repo}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo ?? FakeRepo((0, 0))),
        growthServiceProvider.overrideWithValue(
          FakeGrowthService(growthState()),
        ),
      ],
      child: MaterialApp(theme: appLightTheme(), home: screen),
    ),
  );
}

void main() {
  testWidgets('구간이 1개면 그래프가 없다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = _summary();
    await pump(
      tester,
      SummaryScreen.fromSummary(
        RunSummary(
          startedAt: s.startedAt,
          endedAt: s.endedAt,
          distanceM: 1000,
          movingTime: const Duration(minutes: 6),
          avgPaceSecPerKm: 385,
          calories: 60,
          name: s.name,
          splits: [_splits.first],
          points: s.points,
        ),
      ),
    );
    expect(find.byType(SplitPaceChart), findsNothing);
    expect(find.byKey(const ValueKey('split-row')), findsOneWidget);
  });

  testWidgets('요약 화면에 구간 행 수 = splits 수', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, SummaryScreen.fromSummary(_summary()));
    expect(find.byKey(const ValueKey('split-row')), findsNWidgets(3));
    expect(find.byType(SplitPaceChart), findsOneWidget);
    String rowText(int i) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('split-row')).at(i),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .join('|');
    expect(rowText(0), '1|6\'25"');
    expect(rowText(1), '2|6\'30"');
    // 마지막 짧은 구간은 번호 대신 누적 거리.
    expect(rowText(2), '2.5|6\'40"');
    expect(find.text('금요일 오후 러닝'), findsOneWidget);
    expect(find.text('2.50'), findsOneWidget);
    expect(find.text('6\'30"'), findsWidgets);
    expect(find.text('16:15'), findsOneWidget);
    expect(find.text('168'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('확인 버튼이 홈으로 돌아간다', (tester) async {
    await pump(tester, const Scaffold(body: Text('home')));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen.fromSummary(_summary()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsNothing);
  });

  testWidgets('forRun 은 불러오는 동안 진행 표시를 보이고 상세를 그린다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(
      (0, 0),
      details: {
        'a': RunDetail(
          run: RunListItem(
            id: 'a',
            name: '아침 러닝',
            startedAt: DateTime(2026, 10, 10, 7),
            distanceM: 2500,
            movingTime: const Duration(minutes: 16, seconds: 15),
            avgPaceSecPerKm: 390,
          ),
          calories: 168,
          route: const [(37.5, 127.0), (37.501, 127.001)],
          splits: _splits,
        ),
      },
    );
    await pump(tester, const SummaryScreen.forRun('a'), repo: repo);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('아침 러닝'), findsOneWidget);
    expect(find.byKey(const ValueKey('split-row')), findsNWidgets(3));
  });

  testWidgets('forRun 에서 getRun 이 null 이면 찾을 수 없다는 안내', (tester) async {
    await pump(tester, const SummaryScreen.forRun('none'));
    await tester.pumpAndSettle();
    expect(find.text('기록을 찾을 수 없어요'), findsOneWidget);
    expect(find.text('기록 삭제'), findsNothing);
  });

  testWidgets('러닝 종료 직후 요약에는 기록 삭제가 없다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, SummaryScreen.fromSummary(_summary()));
    expect(find.text('기록 삭제'), findsNothing);
  });

  testWidgets('forRun 은 글자 1.3배에서 기록 삭제까지 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(
      (0, 0),
      details: {
        'a': RunDetail(
          run: RunListItem(
            id: 'a',
            name: '아침 러닝',
            startedAt: DateTime(2026, 10, 10, 7),
            distanceM: 2500,
            movingTime: const Duration(minutes: 16, seconds: 15),
            avgPaceSecPerKm: 390,
          ),
          calories: 168,
          route: const [],
          splits: _splits,
        ),
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState()),
          ),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const SummaryScreen.forRun('a'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('기록 삭제'), 200);
    expect(find.text('기록 삭제'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('경로가 비어 있으면 안내 문구', (tester) async {
    final s = _summary();
    final empty = RunSummary(
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      distanceM: s.distanceM,
      movingTime: s.movingTime,
      avgPaceSecPerKm: s.avgPaceSecPerKm,
      calories: s.calories,
      name: s.name,
      splits: s.splits,
      points: const [],
    );
    await pump(tester, SummaryScreen.fromSummary(empty));
    expect(find.text('경로가 없어요'), findsOneWidget);
  });

  testWidgets('fromSummary 에 gain 이 있으면 성장 영역이 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(
      tester,
      SummaryScreen.fromSummary(
        _summary(),
        gain: const GrowthGain(
          distanceXp: 25,
          goalBonusXp: 0,
          levelBefore: 1,
          levelAfter: 1,
          stageBefore: 1,
          stageAfter: 1,
        ),
      ),
    );
    expect(find.text('달린 거리 2.50km'), findsOneWidget);
    expect(find.text('경험치 +25'), findsOneWidget);
  });

  testWidgets('gain 이 없으면 성장 영역이 없다', (tester) async {
    await pump(tester, SummaryScreen.fromSummary(_summary()));
    expect(find.textContaining('경험치'), findsNothing);
  });

  testWidgets('성장 반영에 실패해도(gain 없음) 목표 달성 줄은 보인다', (tester) async {
    await pump(tester, SummaryScreen.fromSummary(_summary(), goalM: 2000));
    expect(find.text('목표 2km 달성'), findsOneWidget);
    expect(find.text('보너스 +10'), findsOneWidget);
  });

  testWidgets('성장 반영에 실패해도(gain 없음) 목표 미달 안내는 보인다', (tester) async {
    await pump(tester, SummaryScreen.fromSummary(_summary(), goalM: 5000));
    expect(find.text('목표 5km까지 2.50km 남았어요'), findsOneWidget);
  });

  testWidgets('forRun 에는 성장 영역이 없다', (tester) async {
    final repo = FakeRepo(
      (0, 0),
      details: {
        'a': RunDetail(
          run: RunListItem(
            id: 'a',
            name: '아침 러닝',
            startedAt: DateTime(2026, 10, 10, 7),
            distanceM: 2500,
            movingTime: const Duration(minutes: 16, seconds: 15),
            avgPaceSecPerKm: 390,
          ),
          calories: 168,
          route: const [],
          splits: const [],
        ),
      },
    );
    await pump(tester, const SummaryScreen.forRun('a'), repo: repo);
    await tester.pumpAndSettle();
    expect(find.textContaining('경험치'), findsNothing);
  });

  group('기록 상세의 목표 줄', () {
    FakeRepo repoWith(double? goalM) => FakeRepo(
      (0, 0),
      details: {
        'a': RunDetail(
          run: RunListItem(
            id: 'a',
            name: '아침 러닝',
            startedAt: DateTime(2026, 10, 10, 7),
            distanceM: 5020,
            movingTime: const Duration(minutes: 30),
            avgPaceSecPerKm: 360,
            goal: goalM == null ? null : DistanceGoal(goalM),
          ),
          calories: 168,
          route: const [],
          splits: const [],
        ),
      },
    );

    testWidgets('달성이면 보너스가 보인다', (tester) async {
      await pump(tester, const SummaryScreen.forRun('a'), repo: repoWith(5000));
      await tester.pumpAndSettle();
      expect(find.text('목표 5km 달성'), findsOneWidget);
      expect(find.text('보너스 +25'), findsOneWidget);
    });

    testWidgets('미달이면 남은 거리가 보인다', (tester) async {
      await pump(
        tester,
        const SummaryScreen.forRun('a'),
        repo: repoWith(10000),
      );
      await tester.pumpAndSettle();
      expect(find.text('목표 10km까지 4.98km 남았어요'), findsOneWidget);
    });

    testWidgets('목표 없는 예전 러닝은 목표 줄이 없다', (tester) async {
      await pump(tester, const SummaryScreen.forRun('a'), repo: repoWith(null));
      await tester.pumpAndSettle();
      expect(find.textContaining('목표'), findsNothing);
    });
  });

  for (final size in [const Size(390, 844), const Size(360, 640)]) {
    testWidgets(
      '글자 크기 1.3배, 레벨업 요약이 ${size.width.toInt()}x${size.height.toInt()} 에서 overflow 없이 그려진다',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
              growthServiceProvider.overrideWithValue(
                FakeGrowthService(growthState()),
              ),
            ],
            child: MaterialApp(
              theme: appLightTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
              home: SummaryScreen.fromSummary(
                _summary(),
                gain: const GrowthGain(
                  distanceXp: 25,
                  goalBonusXp: 50,
                  levelBefore: 3,
                  levelAfter: 4,
                  stageBefore: 1,
                  stageAfter: 1,
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull);
        expect(find.text('레벨 업!'), findsOneWidget);
      },
    );
  }

  testWidgets('제목은 헤더다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, SummaryScreen.fromSummary(_summary()));
    expect(
      tester.getSemantics(find.widgetWithText(ScreenTitle, '러닝 요약')),
      matchesSemantics(label: '러닝 요약', isHeader: true),
    );
    handle.dispose();
  });
}
