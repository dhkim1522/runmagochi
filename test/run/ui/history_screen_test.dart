import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/route_painter.dart';
import 'package:runmagochi/run/ui/split_pace_chart.dart';
import 'package:runmagochi/run/ui/stats_chart.dart';
import 'package:runmagochi/run/ui/history_screen.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';

import 'fakes.dart';

RunListItem _item(String id, String name, DateTime at, double m) => RunListItem(
  id: id,
  name: name,
  startedAt: at,
  distanceM: m,
  movingTime: const Duration(minutes: 20),
  avgPaceSecPerKm: 400,
);

Future<void> pump(
  WidgetTester tester,
  FakeRepo repo, [
  FakeController? c,
  double scale = 1.0,
  ThemeData? theme,
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo),
        runControllerProvider.overrideWith(() => c ?? FakeController()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: MaterialApp(
        theme: theme ?? appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: HistoryScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 목록 카드가 모두 그려지게 긴 폰 화면(390×1400)으로 둔다.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  _loadingLayoutTests();
  _deleteTests();
  _statsTests();
  _designTests();
  testWidgets('기록 탭에 러닝 2개가 최신순으로 보이고 이번 주 합계가 보인다', (tester) async {
    _tall(tester);
    final repo = FakeRepo(
      (8000, 2),
      runs: [
        _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
        _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
      ],
    );
    await pump(tester, repo);
    expect(find.text('2026년 10월 12일 ~ 10월 18일'), findsOneWidget);
    expect(find.text('8.00'), findsOneWidget);
    expect(find.text('러닝 2회'), findsOneWidget);
    expect(find.text('최근 러닝'), findsOneWidget);
    final first = tester.getTopLeft(find.textContaining('토요일 아침 러닝')).dy;
    final second = tester.getTopLeft(find.textContaining('목요일 저녁 러닝')).dy;
    expect(first, lessThan(second));
    expect(find.text("5.00km · 6'40\" · 20:00"), findsOneWidget);
  });

  testWidgets('항목을 누르면 상세로 이동한다', (tester) async {
    final repo = FakeRepo(
      (3000, 1),
      runs: [_item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000)],
    );
    await pump(tester, repo);
    await tester.tap(find.textContaining('목요일 저녁 러닝'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('기록을 찾을 수 없어요'), findsOneWidget);
  });

  testWidgets('기록이 없으면 안내 문구', (tester) async {
    await pump(tester, FakeRepo((0, 0)));
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
  });

  testWidgets('러닝이 끝나면 목록을 다시 읽는다', (tester) async {
    final repo = FakeRepo((0, 0));
    final c = FakeController();
    await pump(tester, repo, c);
    expect(find.text('아직 기록이 없어요'), findsOneWidget);
    repo.runs = [_item('a', '새 러닝', DateTime(2026, 10, 17, 7), 1000)];
    await c.end();
    await tester.pumpAndSettle();
    expect(find.textContaining('새 러닝'), findsOneWidget);
  });

  testWidgets('글자 크기 1.3배에서 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(
      (12400, 3),
      runs: [
        _item('a', '토요일 점심 러닝', DateTime(2026, 10, 17, 12), 5020),
        _item('b', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 4280),
      ],
    );
    await pump(tester, repo, null, 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('러닝 카드는 버튼 시맨틱이고 카드 사이 간격은 12다', (tester) async {
    _tall(tester);
    final handle = tester.ensureSemantics();
    final repo = FakeRepo(
      (8000, 2),
      runs: [
        _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
        _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
      ],
    );
    await pump(tester, repo);
    final node = tester.getSemantics(
      find.bySemanticsLabel(RegExp('토요일 아침 러닝')),
    );
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    final cards = find.byType(AppCard);
    // 첫 카드는 이번 주 합계, 이후가 러닝 카드.
    final a = tester.getRect(cards.at(1));
    final b = tester.getRect(cards.at(2));
    expect(b.top - a.bottom, Gap.s3);
    handle.dispose();
  });

  testWidgets('제목은 헤더다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakeRepo((0, 0)));
    expect(
      tester.getSemantics(find.widgetWithText(ScreenTitle, '기록')),
      matchesSemantics(label: '기록', isHeader: true),
    );
    handle.dispose();
  });
}

void _deleteTests() {
  RunDetail detail(RunListItem item) =>
      RunDetail(run: item, calories: 100, route: const [], splits: const []);

  final a = _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000);
  final b = _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000);

  Future<(FakeRepo, FakeGrowthService, ProviderContainer)> open(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = FakeRepo(
      (8000, 2),
      runs: [b, a],
      details: {'a': detail(a), 'b': detail(b)},
    );
    final growth = FakeGrowthService(growthState());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          runControllerProvider.overrideWith(() => FakeController()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
          growthServiceProvider.overrideWithValue(growth),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HistoryScreen)),
    );
    await container.read(growthStateProvider.future);
    await tester.tap(find.textContaining('목요일 저녁 러닝'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
    return (repo, growth, container);
  }

  testWidgets('기록 상세에서 삭제를 확인하면 목록으로 돌아가고 사라진다', (tester) async {
    final (repo, growth, container) = await open(tester);
    final loadsBefore = growth.loads;
    await tester.tap(find.text('기록 삭제'));
    await tester.pumpAndSettle();
    expect(find.text('이 러닝을 지울까요?'), findsOneWidget);
    expect(find.text('기록에서 지워요. 받은 경험치는 그대로예요.'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a']);
    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.textContaining('목요일 저녁 러닝'), findsNothing);
    expect(find.textContaining('토요일 아침 러닝'), findsOneWidget);
    expect(find.text('5.00'), findsOneWidget);
    expect(find.text('러닝 1회'), findsOneWidget);
    await container.read(growthStateProvider.future);
    expect(growth.loads, loadsBefore + 1);
  });

  testWidgets('취소하면 상세에 남고 기록도 그대로다', (tester) async {
    final (repo, growth, _) = await open(tester);
    await tester.tap(find.text('기록 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('이 러닝을 지울까요?'), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(repo.deleted, isEmpty);
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.textContaining('목요일 저녁 러닝'), findsOneWidget);
  });

  testWidgets('지우지 못하면 알림 줄을 띄우고 상세에 남는다', (tester) async {
    final (repo, growth, _) = await open(tester);
    repo.deleteError = StateError('db');
    await tester.tap(find.text('기록 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();
    expect(find.text('지우지 못했어요'), findsOneWidget);
    expect(find.byType(SummaryScreen), findsOneWidget);
  });

  testWidgets('삭제 동작은 이름 있는 버튼이다', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    final data = tester
        .getSemantics(find.bySemanticsLabel('기록 삭제'))
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}

void _loadingLayoutTests() {
  testWidgets('이번 주 카드는 불러오는 동안에도 불러온 뒤와 높이가 같다', (tester) async {
    final hold = Completer<List<RunListItem>>();
    final repo = FakeRepo((8000, 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
          runListProvider.overrideWith((ref) => hold.future),
          runControllerProvider.overrideWith(() => FakeController()),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          home: const Scaffold(body: HistoryScreen()),
        ),
      ),
    );
    await tester.pump();
    final card = find.byType(AppCard).first;
    final before = tester.getSize(card).height;
    expect(find.text('러닝 -회'), findsOneWidget);
    hold.complete([
      _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
      _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('러닝 2회'), findsOneWidget);
    expect(tester.getSize(card).height, before);
  });
}

List<RunListItem> _statsRuns() => [
  _item('a', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
  _item('b', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
  _item('c', '지난주 러닝', DateTime(2026, 10, 5, 8), 2000),
  _item('d', '9월 러닝', DateTime(2026, 9, 20, 8), 4000),
  _item('e', '작년 러닝', DateTime(2025, 6, 1, 8), 6000),
];

void _statsTests() {
  Finder next() => find.byKey(const Key('stats-next'));
  Finder prev() => find.byKey(const Key('stats-prev'));

  testWidgets('주·월·년·전체 탭을 바꾸면 통계가 바뀐다', (tester) async {
    await pump(tester, FakeRepo((0, 0), runs: _statsRuns()));
    expect(find.text('8.00'), findsOneWidget);
    expect(find.text('러닝 2회'), findsOneWidget);
    expect(find.textContaining('5\'00"'), findsOneWidget);
    expect(find.textContaining('40:00'), findsWidgets);

    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
    expect(find.text('러닝 3회'), findsOneWidget);

    await tester.tap(find.text('년'));
    await tester.pumpAndSettle();
    expect(find.text('2026년'), findsOneWidget);
    expect(find.text('14.00'), findsOneWidget);
    expect(find.text('러닝 4회'), findsOneWidget);

    await tester.tap(find.text('전체'));
    await tester.pumpAndSettle();
    expect(find.text('20.00'), findsOneWidget);
    expect(find.text('러닝 5회'), findsOneWidget);
    expect(prev(), findsNothing);
    expect(next(), findsNothing);
  });

  testWidgets('화살표로 이전 기간으로 가고 미래로는 못 간다', (tester) async {
    await pump(tester, FakeRepo((0, 0), runs: _statsRuns()));
    await tester.tap(find.text('월'));
    await tester.pumpAndSettle();
    // 이번 달에서 다음 달로는 못 간다.
    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);

    await tester.tap(prev());
    await tester.pumpAndSettle();
    expect(find.text('2026년 9월'), findsOneWidget);
    expect(find.text('4.00'), findsOneWidget);
    expect(find.text('러닝 1회'), findsOneWidget);

    await tester.tap(next());
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월'), findsOneWidget);
    expect(find.text('10.00'), findsOneWidget);
  });

  testWidgets('러닝 없는 기간은 0 과 빈 그래프로 그려지고 탭을 바꾸면 이번 기간으로 돌아온다', (tester) async {
    await pump(tester, FakeRepo((0, 0), runs: _statsRuns()));
    await tester.tap(prev());
    await tester.pumpAndSettle();
    expect(find.text('2026년 10월 5일 ~ 10월 11일'), findsOneWidget);
    await tester.tap(prev());
    await tester.pumpAndSettle();
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('러닝 0회'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('년'));
    await tester.pumpAndSettle();
    expect(find.text('2026년'), findsOneWidget);
  });

  testWidgets('그래프는 기간을 요약하는 시맨틱 라벨이 있다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakeRepo((0, 0), runs: _statsRuns()));
    expect(
      find.bySemanticsLabel(RegExp('^막대 그래프, 요일별 .*토 5.00km')),
      findsOneWidget,
    );
    handle.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets('360x640 글자 1.3배 ${dark ? '다크' : '라이트'} 에서 모든 탭이 넘치지 않는다', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        FakeRepo((0, 0), runs: _statsRuns()),
        null,
        1.3,
        dark ? appDarkTheme() : appLightTheme(),
      );
      for (final tab in ['주', '월', '년', '전체']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tab);
      }
    });
  }
}

void _designTests() {
  final runs = [
    _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
    _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
  ];

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;
    final theme = dark ? appDarkTheme() : appLightTheme();

    testWidgets('막대 채움은 primaryDeep(연두 채움 금지), 그래프 높이 160 ($name)', (
      tester,
    ) async {
      await pump(tester, FakeRepo((0, 0), runs: runs), null, 1, theme);
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(StatsChart),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = paint.painter! as StatsChartPainter;
      expect(painter.barColor, c.primaryDeep);
      expect(painter.barColor, isNot(c.primary));
      expect(tester.getSize(find.byType(StatsChart)).height, 160);
    });

    testWidgets('기간 카드: 거리 64 + km inkMuted, 화살표 48×48 ($name)', (
      tester,
    ) async {
      await pump(tester, FakeRepo((0, 0), runs: runs), null, 1, theme);
      expect(tester.widget<Text>(find.text('8.00')).style!.fontSize, 64);
      expect(
        tester.widget<Text>(find.text('km').first).style!.color,
        c.inkMuted,
      );
      for (final key in ['stats-prev', 'stats-next']) {
        expect(tester.getSize(find.byKey(Key(key))), const Size(48, 48));
      }
      final card = tester.widget<AppCard>(find.byType(AppCard).first);
      expect(card.radius, Radii.lg);
      expect(card.padding, const EdgeInsets.all(Gap.s5));
    });

    testWidgets('섹션 사이 28, 러닝 카드는 작은 카드 + 오른쪽 화살표 ($name)', (tester) async {
      _tall(tester);
      await pump(tester, FakeRepo((0, 0), runs: runs), null, 1, theme);
      final stats = tester.getRect(find.byType(AppCard).first);
      final section = tester.getRect(find.text('최근 러닝'));
      expect(section.top - stats.bottom, Gap.s7);
      final tile = tester.widget<AppCard>(find.byType(AppCard).at(1));
      expect(tile.radius, Radii.md);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(2 + 1));
      final line = tester.widget<Text>(find.text("5.00km · 6'40\" · 20:00"));
      expect(line.style!.fontSize, 17);
      expect(
        line.style!.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      // 좌우 여백 20.
      expect(stats.left, Gap.s5);
    });

    testWidgets('기록이 없으면 빈 상태 카드(기록 그림 + 안내) ($name)', (tester) async {
      await pump(tester, FakeRepo((0, 0)), null, 1, theme);
      final empty = find.byType(EmptyState);
      expect(empty, findsOneWidget);
      expect(
        find.descendant(of: empty, matching: find.text('아직 기록이 없어요')),
        findsOneWidget,
      );
      final icon = tester.widget<TabIcon>(
        find.descendant(of: empty, matching: find.byType(TabIcon)),
      );
      expect(icon.glyph, TabGlyph.history);
      expect(icon.color, c.inkMuted);
    });
  }

  testWidgets('기록 상세는 요약의 경로 페이스 색·범례·구간 그래프를 쓴다', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = runs.first;
    final repo = FakeRepo(
      (0, 0),
      runs: [item],
      details: {
        'b': RunDetail(
          run: item,
          calories: 300,
          route: [for (var i = 0; i < 30; i++) (37.5 + i * 0.0015, 127.0)],
          splits: const [
            Split(index: 1, distanceM: 1000, duration: Duration(seconds: 300)),
            Split(index: 2, distanceM: 1000, duration: Duration(seconds: 360)),
            Split(index: 3, distanceM: 1000, duration: Duration(seconds: 420)),
          ],
        ),
      },
    );
    await pump(tester, repo);
    await tester.tap(find.textContaining('토요일 아침 러닝'));
    await tester.pumpAndSettle();
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.byType(RoutePaceLegend), findsOneWidget);
    expect(find.byType(SplitPaceChart), findsOneWidget);
  });
}
