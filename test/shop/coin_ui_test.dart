import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/ui/coin_chip.dart';
import 'package:runmagochi/shop/ui/coin_history_screen.dart';

import '../run/ui/fakes.dart';

CoinEntry _e(int amount, String reason, String? runId, DateTime at) =>
    CoinEntry(
      amount: amount,
      reason: reason,
      runId: runId,
      itemId: null,
      at: at,
    );

RunDetail _detail(String id, double distanceM, RunGoal? goal) => RunDetail(
  run: RunListItem(
    id: id,
    name: id,
    startedAt: DateTime(2026, 10, 17),
    distanceM: distanceM,
    movingTime: const Duration(minutes: 20),
    avgPaceSecPerKm: 360,
    goal: goal,
  ),
  calories: 0,
  route: const [],
  splits: const [],
);

Future<void> pump(
  WidgetTester tester,
  Widget child,
  FakeShop shop, {
  FakeRepo? repo,
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shopRepositoryProvider.overrideWithValue(shop),
        runRepositoryProvider.overrideWithValue(repo ?? FakeRepo((0, 0))),
      ],
      child: MaterialApp(
        theme: dark ? appDarkTheme() : appLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('칩이 천 단위 쉼표로 잔액을 보이고 누르면 호출된다', (tester) async {
    var taps = 0;
    await pump(tester, CoinChip(onTap: () => taps++), FakeShop([], 1240));
    expect(find.text('1,240'), findsOneWidget);
    expect(
      tester.getSize(find.byType(CoinChip)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(CoinChip));
    expect(taps, 1);
  });

  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    testWidgets('칩은 흰 알약에 앱 코인 그림($name), 글자 2배에서도 넘치지 않는다', (tester) async {
      final c = dark ? AppColors.dark : AppColors.light;
      await pump(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: CoinChip(onTap: () {}),
        ),
        FakeShop([], 1240),
        dark: dark,
        scale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.monetization_on), findsNothing);
      expect(find.byType(CoinIcon), findsOneWidget);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(CoinChip),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final d = box.decoration as BoxDecoration;
      expect(d.color, c.surface);
      expect(d.borderRadius, BorderRadius.circular(Radii.pill));
      final size = tester.getSize(find.byType(CoinChip));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(tester.widget<Text>(find.text('1,240')).style!.color, c.ink);
    });
  }

  testWidgets('칩을 누르면 작아졌다가 돌아온다', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: CoinChip(onTap: () {}),
      ),
      FakeShop([], 1240),
    );
    double scale() => tester
        .widget<AnimatedScale>(
          find.descendant(
            of: find.byType(CoinChip),
            matching: find.byType(AnimatedScale),
          ),
        )
        .scale;
    final g = await tester.startGesture(
      tester.getCenter(find.byType(CoinChip)),
    );
    await tester.pump();
    expect(scale(), Pressable.pressedScale);
    await g.up();
    await tester.pump();
    expect(scale(), 1);
  });

  group('내역', () {
    final repo = FakeRepo(
      (0, 0),
      details: {'r1': _detail('r1', 3130, const DistanceGoal(3000))},
    );
    final entries = [
      CoinEntry(
        amount: -100,
        reason: 'purchase',
        runId: null,
        itemId: 'cap',
        at: DateTime(2026, 10, 18, 9),
      ),
      _e(-120, 'purchase', null, DateTime(2026, 10, 18, 8)),
      _e(15, 'runGoal', 'r1', DateTime(2026, 10, 17, 17, 51)),
      _e(15, 'distance', 'r1', DateTime(2026, 10, 17, 17, 51)),
      _e(5, 'distance', 'gone', DateTime(2026, 10, 10, 8)),
      _e(5, 'runGoal', 'gone', DateTime(2026, 10, 10, 8)),
    ];

    testWidgets('최신순 줄, 사유 문구, 부호, 색', (tester) async {
      await pump(
        tester,
        const CoinHistoryScreen(),
        FakeShop(entries),
        repo: repo,
      );
      expect(find.text('코인 내역'), findsOneWidget);
      expect(find.text('러닝 캡 구매'), findsOneWidget);
      expect(find.text('아이템 구매'), findsOneWidget);
      expect(find.text('러닝 3.13km'), findsOneWidget);
      expect(find.text('목표 3km 달성'), findsOneWidget);
      // 지운 러닝은 숫자 없이
      expect(find.text('러닝'), findsOneWidget);
      expect(find.text('목표 달성'), findsOneWidget);
      expect(find.text('10월 17일 (토) 오후 5:51'), findsNWidgets(2));
      final c = AppColors.light;
      Color colorOf(String s) =>
          tester.widget<Text>(find.text(s).first).style!.color!;
      // 코인 +N 은 코인 색(관문 2 결과, 작업 14).
      expect(colorOf('+15'), c.coin);
      expect(colorOf('−100'), c.ink);
      final top = tester.getTopLeft(find.text('러닝 캡 구매')).dy;
      expect(top, lessThan(tester.getTopLeft(find.text('러닝 3.13km')).dy));
    });

    testWidgets('시간 목표 달성 줄은 목표 30분 달성이다', (tester) async {
      final repo = FakeRepo(
        (0, 0),
        details: {
          't1': _detail('t1', 4000, const TimeGoal(Duration(minutes: 30))),
        },
      );
      await pump(
        tester,
        const CoinHistoryScreen(),
        FakeShop([_e(25, 'runGoal', 't1', DateTime(2026, 10, 17, 17, 51))]),
        repo: repo,
      );
      expect(find.text('목표 30분 달성'), findsOneWidget);
    });

    testWidgets('배지 줄은 배지: 이름, 모르는 배지는 배지', (tester) async {
      await pump(
        tester,
        const CoinHistoryScreen(),
        FakeShop([
          CoinEntry(
            amount: 100,
            reason: 'badge',
            runId: null,
            itemId: 'dist_5k',
            at: DateTime(2026, 10, 17, 17, 51),
          ),
          CoinEntry(
            amount: 50,
            reason: 'badge',
            runId: null,
            itemId: 'nope',
            at: DateTime(2026, 10, 16, 17, 51),
          ),
        ]),
      );
      expect(find.text('배지: 첫 5km'), findsOneWidget);
      expect(find.text('배지'), findsOneWidget);
    });

    testWidgets('비면 안내 문구', (tester) async {
      await pump(tester, const CoinHistoryScreen(), FakeShop([]));
      expect(find.text('달리면 코인이 쌓여요'), findsOneWidget);
    });

    for (final dark in [false, true]) {
      final name = dark ? '다크' : '라이트';
      final c = dark ? AppColors.dark : AppColors.light;

      testWidgets('줄마다 코인 그림 + 금액(stat 22/800), 뒤로는 동그라미 버튼 ($name)', (
        tester,
      ) async {
        await pump(
          tester,
          const CoinHistoryScreen(),
          FakeShop(entries),
          repo: repo,
          dark: dark,
        );
        expect(
          tester.widget<CircleIconButton>(find.byType(CircleIconButton)).label,
          '뒤로',
        );
        final plus = tester.widget<Text>(find.text('+15').first);
        expect(plus.style!.color, c.coin);
        expect(plus.style!.fontSize, 22);
        expect(plus.style!.fontWeight, FontWeight.w800);
        final row = find.ancestor(
          of: find.text('러닝 3.13km'),
          matching: find.byType(AppCard),
        );
        expect(tester.widget<AppCard>(row).radius, Radii.md);
        expect(
          find.descendant(of: row, matching: find.byType(CoinIcon)),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(find.text('러닝 3.13km')).style!.fontWeight,
          FontWeight.w700,
        );
      });

      testWidgets('비면 코인 그림 빈 상태 카드 ($name)', (tester) async {
        await pump(tester, const CoinHistoryScreen(), FakeShop([]), dark: dark);
        final empty = find.byType(EmptyState);
        expect(empty, findsOneWidget);
        expect(
          find.descendant(of: empty, matching: find.byType(CoinIcon)),
          findsOneWidget,
        );
      });
    }

    for (final dark in [false, true]) {
      testWidgets('360×640 글자 1.3배 ${dark ? '다크' : '라이트'} 넘침 없음', (
        tester,
      ) async {
        await pump(
          tester,
          const CoinHistoryScreen(),
          FakeShop(entries),
          repo: repo,
          dark: dark,
          scale: 1.3,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
