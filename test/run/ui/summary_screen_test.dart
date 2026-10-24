import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Split;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/domain/route_pace.dart';
import 'package:runmagochi/run/ui/route_painter.dart';
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
  layoutTests();
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
    // 기록 탭에서 연 상세는 방금 끝낸 러닝의 요약과 제목이 다르다.
    expect(find.widgetWithText(ScreenTitle, '러닝 기록'), findsOneWidget);
    expect(find.widgetWithText(ScreenTitle, '러닝 요약'), findsNothing);
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
    await pump(
      tester,
      SummaryScreen.fromSummary(_summary(), goal: const DistanceGoal(2000)),
    );
    expect(find.text('목표 2km 달성'), findsOneWidget);
    expect(find.text('보너스 +10'), findsOneWidget);
  });

  testWidgets('성장 반영에 실패해도(gain 없음) 목표 미달 안내는 보인다', (tester) async {
    await pump(
      tester,
      SummaryScreen.fromSummary(_summary(), goal: const DistanceGoal(5000)),
    );
    expect(find.text('목표 5km까지 2.50km 남았어요'), findsOneWidget);
  });

  testWidgets('시간 목표를 채웠으면(gain 없음) 목표 15분 달성과 보너스가 보인다', (tester) async {
    await pump(
      tester,
      SummaryScreen.fromSummary(
        _summary(),
        goal: const TimeGoal(Duration(minutes: 15)),
      ),
    );
    expect(find.text('목표 15분 달성'), findsOneWidget);
    expect(find.text('보너스 +15'), findsOneWidget);
  });

  testWidgets('시간 목표에 못 미치면(gain 없음) 남은 시간이 보인다', (tester) async {
    // 움직인 시간 16:15, 목표 30분 → 13:45.
    await pump(
      tester,
      SummaryScreen.fromSummary(
        _summary(),
        goal: const TimeGoal(Duration(minutes: 30)),
      ),
    );
    expect(find.text('목표 30분까지 13:45 남았어요'), findsOneWidget);
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
    FakeRepo repoWith(RunGoal? goal) => FakeRepo(
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
            goal: goal,
          ),
          calories: 168,
          route: const [],
          splits: const [],
        ),
      },
    );

    testWidgets('달성이면 보너스가 보인다', (tester) async {
      await pump(
        tester,
        const SummaryScreen.forRun('a'),
        repo: repoWith(const DistanceGoal(5000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('목표 5km 달성'), findsOneWidget);
      expect(find.text('보너스 +25'), findsOneWidget);
    });

    testWidgets('미달이면 남은 거리가 보인다', (tester) async {
      await pump(
        tester,
        const SummaryScreen.forRun('a'),
        repo: repoWith(const DistanceGoal(10000)),
      );
      await tester.pumpAndSettle();
      expect(find.text('목표 10km까지 4.98km 남았어요'), findsOneWidget);
    });

    testWidgets('시간 목표 달성이면 목표 30분 달성과 보너스가 보인다', (tester) async {
      await pump(
        tester,
        const SummaryScreen.forRun('a'),
        repo: repoWith(const TimeGoal(Duration(minutes: 30))),
      );
      await tester.pumpAndSettle();
      expect(find.text('목표 30분 달성'), findsOneWidget);
      expect(find.text('보너스 +25'), findsOneWidget);
    });

    testWidgets('시간 목표 미달이면 남은 시간이 보인다', (tester) async {
      await pump(
        tester,
        const SummaryScreen.forRun('a'),
        repo: repoWith(const TimeGoal(Duration(minutes: 60))),
      );
      await tester.pumpAndSettle();
      expect(find.text('목표 60분까지 30:00 남았어요'), findsOneWidget);
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

/// 북쪽으로 100m 간격 [count] 점(반 칸 띄워 시작).
List<LocationSample> _northRoute(int count) => [
  for (var i = 0; i < count; i++)
    LocationSample(
      time: DateTime(2026, 10, 16, 17, 51, i),
      latitude: 37.5 + (i * 100 + 50) / 6371000 * 180 / math.pi,
      longitude: 127.0,
      accuracy: 5,
    ),
];

/// 시안 c 요약(5.24km, 구간 6개, 페이스가 서로 다르다).
RunSummary _full({List<Split>? splits}) => RunSummary(
  startedAt: DateTime(2026, 10, 22, 7, 12),
  endedAt: DateTime(2026, 10, 22, 7, 45),
  distanceM: 5240,
  movingTime: const Duration(minutes: 32, seconds: 9),
  avgPaceSecPerKm: 368,
  calories: 353,
  name: '목요일 아침 러닝',
  splits:
      splits ??
      const [
        Split(index: 1, distanceM: 1000, duration: Duration(seconds: 375)),
        Split(index: 2, distanceM: 1000, duration: Duration(seconds: 369)),
        Split(index: 3, distanceM: 1000, duration: Duration(seconds: 364)),
        Split(index: 4, distanceM: 1000, duration: Duration(seconds: 371)),
        Split(index: 5, distanceM: 1000, duration: Duration(seconds: 362)),
        Split(index: 6, distanceM: 240, duration: Duration(seconds: 88)),
      ],
  points: _northRoute(53),
);

GrowthGain _gain({bool levelUp = true}) => GrowthGain(
  distanceXp: 52,
  goalBonusXp: 25,
  distanceCoins: 26,
  goalCoins: 25,
  levelBefore: 19,
  levelAfter: levelUp ? 20 : 19,
  stageBefore: 3,
  stageAfter: levelUp ? 4 : 3,
  newBadges: const ['goals_30'],
);

/// 시안 c 배치(작업 13). 글자 높이를 재므로 앱 글꼴(RunmagochiSans)을 읽는다.
void layoutTests() {
  group('시안 배치(작업 13)', () {
    setUpAll(() async {
      final font = File('assets/fonts/RunmagochiSans.ttf').readAsBytesSync();
      await (FontLoader(
        'RunmagochiSans',
      )..addFont(Future.value(ByteData.sublistView(font)))).load();
    });

    Future<void> open(
      WidgetTester tester,
      Widget screen, {
      Size size = const Size(390, 844),
      bool dark = false,
      double scale = 1,
    }) async {
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
            theme: dark ? appDarkTheme() : appLightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: screen,
          ),
        ),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Widget full({
      bool levelUp = true,
      RunGoal goal = const DistanceGoal(5000),
    }) => SummaryScreen.fromSummary(
      _full(),
      gain: _gain(levelUp: levelUp),
      goal: goal,
    );

    // 표에도 '5.24'·'km' 가 있어 거리 줄은 글자 크기로 고른다.
    final distance = find.byWidgetPredicate(
      (w) => w is Text && w.data == '5.24' && w.style?.fontSize == 64,
    );
    final unit = find.byWidgetPredicate(
      (w) => w is Text && w.data == 'km' && w.style?.fontSize == 22,
    );

    Rect cardOf(WidgetTester tester, Finder f) => tester.getRect(
      find.ancestor(of: f, matching: find.byType(AppCard)).first,
    );

    testWidgets('위에서 아래로: 마스코트 판·행 카드·날짜·이름·거리·지표·경로·구간', (tester) async {
      // 모든 줄이 한 번에 그려지게 길게 연다.
      await open(tester, full(), size: const Size(390, 3000));
      final ys = [
        tester.getRect(find.byKey(const ValueKey('level-up-card'))).top,
        cardOf(tester, find.text('달린 거리 5.24km')).top,
        tester.getRect(find.text('10월 22일 (목) 오전 7:12')).top,
        tester.getRect(find.text('목요일 아침 러닝')).top,
        tester.getRect(distance).top,
        tester.getRect(find.byType(StatsCard)).top,
        tester.getRect(find.byKey(const ValueKey('route-card'))).top,
        cardOf(tester, find.text('구간')).top,
      ];
      for (var i = 1; i < ys.length; i++) {
        expect(ys[i], greaterThan(ys[i - 1]), reason: '$i 번째 순서');
      }
      // 섹션 사이 28: 행 카드 아래 → 날짜.
      expect(
        tester.getRect(find.text('10월 22일 (목) 오전 7:12')).top -
            cardOf(tester, find.text('달린 거리 5.24km')).bottom,
        Gap.s7,
      );
      // 카드 사이 12: 지표 → 경로 → 구간.
      final stats = tester.getRect(find.byType(StatsCard));
      final route = tester.getRect(find.byKey(const ValueKey('route-card')));
      expect(route.top - stats.bottom, Gap.s3);
      expect(cardOf(tester, find.text('구간')).top - route.bottom, Gap.s3);
      // 좌우 여백 20.
      expect(stats.left, Gap.s5);
      expect(stats.right, 390 - Gap.s5);
    });

    testWidgets('이름은 title 26, 거리는 64, km 는 ink-muted', (tester) async {
      await open(tester, full(), size: const Size(390, 3000));
      final c = AppColors.of(tester.element(unit));
      expect(tester.widget<Text>(find.text('목요일 아침 러닝')).style!.fontSize, 26);
      expect(distance, findsOneWidget);
      expect(tester.widget<Text>(unit).style!.color, c.inkMuted);
    });

    testWidgets('지표 3칸은 흰 카드 하나(StatsCard)', (tester) async {
      await open(tester, full(), size: const Size(390, 3000));
      expect(find.byType(StatsCard), findsOneWidget);
      for (final label in ['평균 페이스', '시간', '칼로리']) {
        expect(
          find.descendant(
            of: find.byType(StatsCard),
            matching: find.text(label),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('32:09'), findsOneWidget);
      expect(find.text('353'), findsOneWidget);
    });

    testWidgets('구간 그래프와 표는 "구간" 카드 하나 안에 있다', (tester) async {
      await open(tester, full(), size: const Size(390, 3000));
      final card = cardOf(tester, find.text('구간'));
      expect(
        card.contains(tester.getCenter(find.byType(SplitPaceChart))),
        isTrue,
      );
      final rows = find.byKey(const ValueKey('split-row'));
      expect(rows, findsNWidgets(6));
      expect(card.contains(tester.getCenter(rows.last)), isTrue);
      expect(card.contains(tester.getCenter(find.text('페이스'))), isTrue);
    });

    testWidgets('경로 선은 구간 페이스 색, 범례가 있다', (tester) async {
      await open(tester, full(), size: const Size(390, 3000));
      final c = AppColors.of(tester.element(unit));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(const ValueKey('route-card')),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((w) => w.painter)
          .whereType<RoutePainter>()
          .single;
      expect(painter.colors, RoutePaceColors.of(c));
      final expected = routePaceSegments([
        for (final p in _full().points) (p.latitude, p.longitude),
      ], _full().splits);
      expect(
        [for (final s in painter.segments) s.pace],
        [for (final s in expected) s.pace],
      );
      expect(painter.segments.length, 6);
      final legend = find.byKey(const ValueKey('route-legend'));
      expect(legend, findsOneWidget);
      for (final t in ['천천히', '보통', '빠르게']) {
        expect(
          find.descendant(of: legend, matching: find.text(t)),
          findsOneWidget,
        );
      }
      expect(find.text('빠른 이동 · 제외'), findsNothing);
    });

    testWidgets('구간 페이스가 모두 같으면 한 색이고 범례가 없다', (tester) async {
      await open(
        tester,
        SummaryScreen.fromSummary(
          _full(
            splits: const [
              Split(
                index: 1,
                distanceM: 1000,
                duration: Duration(seconds: 360),
              ),
              Split(
                index: 2,
                distanceM: 1000,
                duration: Duration(seconds: 360),
              ),
            ],
          ),
        ),
        size: const Size(390, 3000),
      );
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byKey(const ValueKey('route-card')),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((w) => w.painter)
          .whereType<RoutePainter>()
          .single;
      expect(
        painter.segments.map((s) => s.pace),
        everyElement(RoutePace.single),
      );
      expect(find.byKey(const ValueKey('route-legend')), findsNothing);
    });

    testWidgets('공유는 48 높이 흰 알약 + 아이콘, 끝부분 잘라내기는 확인보다 작다', (tester) async {
      await open(tester, full());
      final c = AppColors.of(tester.element(find.text('확인')));
      final share = find.byKey(const ValueKey('share-button'));
      expect(tester.getSize(share).height, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: share, matching: find.byIcon(Icons.ios_share)),
        findsOneWidget,
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: share, matching: find.byType(DecoratedBox)).first,
      );
      expect((box.decoration as BoxDecoration).color, c.surface);
      final trim = tester.getRect(
        find.ancestor(
          of: find.text('끝부분 잘라내기'),
          matching: find.byType(AppButton),
        ),
      );
      final ok = tester.getRect(
        find.ancestor(of: find.text('확인'), matching: find.byType(AppButton)),
      );
      expect(trim.height, lessThan(ok.height));
      expect(trim.height, greaterThanOrEqualTo(48));
      expect(trim.bottom, lessThanOrEqualTo(ok.top));
    });

    for (final dark in [false, true]) {
      final theme = dark ? '다크' : '라이트';
      for (final levelUp in [true, false]) {
        for (final achieved in [true, false]) {
          testWidgets(
            '360×640 글자 1.3배 $theme · 레벨 업 ${levelUp ? '있음' : '없음'} · '
            '목표 ${achieved ? '달성' : '미달'}: 넘침 없이 끝까지 스크롤',
            (tester) async {
              await open(
                tester,
                full(
                  levelUp: levelUp,
                  goal: DistanceGoal(achieved ? 5000 : 10000),
                ),
                size: const Size(360, 640),
                dark: dark,
                scale: 1.3,
              );
              expect(tester.takeException(), isNull);
              // 끝까지 내린다.
              for (var i = 0; i < 6; i++) {
                await tester.drag(find.byType(ListView), const Offset(0, -600));
                await tester.pump();
              }
              expect(tester.takeException(), isNull);
              final last = find.byKey(const ValueKey('split-row')).last;
              expect(tester.getRect(last).bottom, lessThanOrEqualTo(640));
              // 버튼은 늘 화면 안.
              expect(
                tester.getRect(find.text('확인')).bottom,
                lessThanOrEqualTo(640),
              );
            },
          );
        }
      }
    }
  });
}
