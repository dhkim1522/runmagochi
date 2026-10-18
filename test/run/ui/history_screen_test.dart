import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
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
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo),
        runControllerProvider.overrideWith(() => c ?? FakeController()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
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

void main() {
  _loadingLayoutTests();
  _deleteTests();
  testWidgets('기록 탭에 러닝 2개가 최신순으로 보이고 이번 주 합계가 보인다', (tester) async {
    final repo = FakeRepo(
      (8000, 2),
      runs: [
        _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
        _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
      ],
    );
    await pump(tester, repo);
    expect(find.text('이번 주'), findsOneWidget);
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
    final cards = find.byType(ClayCard);
    // 첫 카드는 이번 주 합계, 이후가 러닝 카드.
    final a = tester.getRect(cards.at(1));
    final b = tester.getRect(cards.at(2));
    expect(b.top - a.bottom, Gap.s3 - Borders.lip);
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
    expect(find.text('기록과 이 러닝으로 받은 경험치가 함께 빠져요.'), findsOneWidget);

    await tester.tap(find.text('삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['a']);
    expect(growth.removed, [('a', a.startedAt)]);
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
    expect(growth.removed, isEmpty);
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
    expect(growth.removed, isEmpty);
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
    final repo = FakeRepo((8000, 2))..holdWeekly = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runRepositoryProvider.overrideWithValue(repo),
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
    final card = find.byType(ClayCard).first;
    final before = tester.getSize(card).height;
    expect(find.text('러닝 -회'), findsOneWidget);
    repo.holdWeekly!.complete();
    await tester.pumpAndSettle();
    expect(find.text('러닝 2회'), findsOneWidget);
    expect(tester.getSize(card).height, before);
  });
}
