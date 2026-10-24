import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/app/share_service.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_stats.dart';
import 'package:runmagochi/run/ui/history_screen.dart';
import 'package:runmagochi/run/ui/recap_card.dart';
import 'package:runmagochi/run/ui/share_card.dart' show shareCardSize;
import 'package:runmagochi/shop/app/providers.dart';

import 'fakes.dart';
import 'share_card_test.dart' show FakeSharer;

RunListItem _item(String id, DateTime at, double m) => RunListItem(
  id: id,
  name: '러닝',
  startedAt: at,
  distanceM: m,
  movingTime: Duration(seconds: (m * 0.3).round()),
  avgPaceSecPerKm: 300,
);

final _runs = [
  _item('a', DateTime(2026, 10, 17, 7), 5000),
  _item('b', DateTime(2026, 10, 15, 19), 3000),
];

void main() {
  testWidgets('결산 카드: 기간·거리·러닝 수·시간·페이스·캐릭터 이름과 레벨', (tester) async {
    final stats = statsFor(_runs, StatsPeriod.week, DateTime(2026, 10, 17));
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        home: Center(
          child: RecapCard(
            title: '2026년 10월 12일 ~ 10월 18일',
            heading: '이번 주 결산',
            stats: stats,
            kind: AvatarKind.jelly,
            stage: 2,
            mood: AvatarMood.normal,
            name: '말랑이',
            level: 9,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(RecapCard)), shareCardSize);
    expect(find.text('이번 주 결산'), findsOneWidget);
    expect(find.text('2026년 10월 12일 ~ 10월 18일'), findsOneWidget);
    expect(find.text('8.00'), findsOneWidget);
    expect(find.text('2회'), findsOneWidget);
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('말랑이 Lv.9'), findsOneWidget);
  });

  group('기록 화면 결산 공유', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('recap'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Future<FakeSharer> pump(
      WidgetTester tester, {
      List<RunListItem>? runs,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final sharer = FakeSharer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(
              FakeRepo((0, 0), runs: runs ?? _runs),
            ),
            runControllerProvider.overrideWith(() => FakeController()),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
            growthServiceProvider.overrideWithValue(
              FakeGrowthService(growthState(name: '말랑이')),
            ),
            shopRepositoryProvider.overrideWithValue(FakeShop()),
            sharerProvider.overrideWithValue(sharer),
            shareTempDirProvider.overrideWithValue(() async => tmp),
          ],
          child: MaterialApp(
            theme: appLightTheme(),
            home: const Scaffold(body: HistoryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sharer;
    }

    testWidgets('주·월 탭에 결산 공유가 있고 누르면 PNG 를 공유한다', (tester) async {
      final s = await pump(tester);
      expect(find.text('결산 공유'), findsOneWidget);
      await tester.tap(find.text('결산 공유'));
      await tester.pump();
      for (var i = 0; i < 40 && s.paths.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(s.paths.single, endsWith('.png'));
      expect(s.sizes.single, greaterThan(1000));

      await tester.tap(find.text('월'));
      await tester.pumpAndSettle();
      expect(find.text('결산 공유'), findsOneWidget);
    });

    testWidgets('년·전체 탭과 러닝이 없는 기간에는 결산 공유가 없다', (tester) async {
      await pump(tester);
      await tester.tap(find.text('년'));
      await tester.pumpAndSettle();
      expect(find.textContaining('결산 공유'), findsNothing);
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle();
      expect(find.textContaining('결산 공유'), findsNothing);
      await tester.tap(find.text('주'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stats-prev')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stats-prev')));
      await tester.pumpAndSettle();
      expect(find.textContaining('결산 공유'), findsNothing);
    });
  });
}
