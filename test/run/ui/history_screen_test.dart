import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
]) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo),
        runControllerProvider.overrideWith(() => c ?? FakeController()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('기록 탭에 러닝 2개가 최신순으로 보이고 이번 주 합계가 보인다', (tester) async {
    final repo = FakeRepo(
      (8000, 2),
      runs: [
        _item('b', '토요일 아침 러닝', DateTime(2026, 10, 17, 7), 5000),
        _item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000),
      ],
    );
    await pump(tester, repo);
    expect(find.text('이번 주 8.00 km · 2회'), findsOneWidget);
    final first = tester.getTopLeft(find.text('토요일 아침 러닝')).dy;
    final second = tester.getTopLeft(find.text('목요일 저녁 러닝')).dy;
    expect(first, lessThan(second));
    expect(find.text('5.00 km'), findsOneWidget);
  });

  testWidgets('항목을 누르면 상세로 이동한다', (tester) async {
    final repo = FakeRepo(
      (3000, 1),
      runs: [_item('a', '목요일 저녁 러닝', DateTime(2026, 10, 15, 19), 3000)],
    );
    await pump(tester, repo);
    await tester.tap(find.text('목요일 저녁 러닝'));
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
    expect(find.text('새 러닝'), findsOneWidget);
  });
}
