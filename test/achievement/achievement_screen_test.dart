import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/app/providers.dart';
import 'package:runmagochi/achievement/data/badge_repository.dart';
import 'package:runmagochi/achievement/domain/badges.dart';
import 'package:runmagochi/achievement/ui/achievement_screen.dart';
import 'package:runmagochi/achievement/ui/badge_image.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_summary.dart';

RunDetail _run(double distanceM, {int minutes = 30, List<Split>? splits}) =>
    RunDetail(
      run: RunListItem(
        id: 'r$distanceM',
        name: 'n',
        startedAt: DateTime(2026, 1, 1, 12),
        distanceM: distanceM,
        movingTime: Duration(minutes: minutes),
        avgPaceSecPerKm: 360,
      ),
      calories: 0,
      route: const [],
      splits:
          splits ??
          [
            for (var i = 0; i < (distanceM / 1000).floor(); i++)
              Split(
                index: i,
                distanceM: 1000,
                duration: const Duration(seconds: 360),
              ),
          ],
    );

EarnedBadge _earned(String id) =>
    EarnedBadge(badgeId: id, earnedAt: DateTime(2026, 1, 1));

Future<void> _pump(
  WidgetTester tester, {
  List<RunDetail> runs = const [],
  List<EarnedBadge> earned = const [],
  double textScale = 1.0,
  bool dark = false,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        achievementRunsProvider.overrideWith((ref) async => runs),
        earnedBadgesProvider.overrideWith((ref) async => earned),
      ],
      child: MaterialApp(
        theme: dark ? appDarkTheme() : appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AchievementScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  _designTests();
  testWidgets('기록이 없으면 개인 기록은 -, 배지는 0 / 12', (tester) async {
    await _pump(tester);
    expect(find.text('개인 기록'), findsOneWidget);
    expect(find.text('최장 거리'), findsOneWidget);
    expect(find.text('최고 5km'), findsOneWidget);
    expect(find.text('-'), findsNWidgets(4));
    expect(find.text('배지 0 / 12'), findsOneWidget);
  });

  testWidgets('개인 기록 값을 보여 준다', (tester) async {
    await _pump(tester, runs: [_run(6200, minutes: 40)]);
    expect(find.text('6.20km'), findsOneWidget);
    expect(find.text('40:00'), findsOneWidget);
    expect(find.text('6:00'), findsOneWidget); // 최고 1km
    expect(find.text('30:00'), findsOneWidget); // 최고 5km
  });

  testWidgets('받은 배지 수와 12개 이름', (tester) async {
    await _pump(tester, earned: [_earned('first_run'), _earned('dist_5k')]);
    expect(find.text('배지 2 / 12'), findsOneWidget);
    expect(find.text('첫 러닝'), findsOneWidget);
    expect(find.text('하프 완주'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('badge-earned-first_run')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('badge-locked-dist_10k')), findsOneWidget);
    expect(find.byKey(const ValueKey('badge-locked-first_run')), findsNothing);
  });

  testWidgets('배지 12개를 도트 그림으로: 받은 것은 컬러, 못 받은 것은 회색', (tester) async {
    await _pump(
      tester,
      runs: [_run(4000)],
      earned: [_earned('first_run'), _earned('dawn')],
    );
    expect(find.byIcon(Icons.directions_run), findsNothing);
    for (final b in badgeCatalog) {
      final earned = b.id == 'first_run' || b.id == 'dawn';
      final key = ValueKey('badge-${earned ? 'earned' : 'locked'}-${b.id}');
      final image = tester.widget<BadgeImage>(find.byKey(key));
      expect(image.id, b.id);
      expect(image.earned, earned, reason: b.id);
      // 3열 칸에 크게(24px 그림의 3배).
      expect(image.size, 72);
    }
    // 다음 배지 줄(첫 5km 80%)은 같은 그림을 회색으로.
    final next = find.descendant(
      of: find.ancestor(
        of: find.byKey(const ValueKey('next-badge-bar')),
        matching: find.byType(Column),
      ),
      matching: find.byType(BadgeImage),
    );
    final nextImage = tester.widget<BadgeImage>(next.first);
    expect(nextImage.id, 'dist_5k');
    expect(nextImage.earned, isFalse);
  });

  testWidgets('다음 배지는 진행률이 가장 높은 것을 이름·코인·막대로', (tester) async {
    // 4km 한 번: 첫 러닝은 받을 차례, 5km 배지가 80%.
    await _pump(tester, runs: [_run(4000)], earned: [_earned('first_run')]);
    expect(find.text('다음 배지'), findsOneWidget);
    expect(find.text('첫 5km'), findsWidgets);
    expect(find.text('코인 +100'), findsOneWidget);
    final bar = tester.widget<FractionallySizedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('next-badge-bar')),
        matching: find.byType(FractionallySizedBox),
      ),
    );
    expect(bar.widthFactor, closeTo(0.8, 0.001));
  });

  testWidgets('새벽 러너는 막대 대신 안내 문구', (tester) async {
    final all = [
      'first_run',
      'first_goal',
      'dist_5k',
      'dist_10k',
      'dist_half',
      'total_50',
      'total_100',
      'total_300',
      'goals_10',
      'goals_30',
      'streak_3',
    ];
    await _pump(tester, earned: [for (final id in all) _earned(id)]);
    expect(find.text('새벽 러너'), findsWidgets);
    expect(find.byKey(const ValueKey('next-badge-bar')), findsNothing);
    expect(find.text('오전 6시 전에 시작해 보세요'), findsOneWidget);
  });

  testWidgets('모두 받으면 다음 배지 영역이 없다', (tester) async {
    final all = [
      'first_run',
      'first_goal',
      'dist_5k',
      'dist_10k',
      'dist_half',
      'total_50',
      'total_100',
      'total_300',
      'goals_10',
      'goals_30',
      'streak_3',
      'dawn',
    ];
    await _pump(tester, earned: [for (final id in all) _earned(id)]);
    expect(find.text('배지 12 / 12'), findsOneWidget);
    expect(find.text('다음 배지'), findsNothing);
  });

  for (final dark in [false, true]) {
    testWidgets('다음 배지 막대 트랙이 카드와 다른 색이다 (다크 $dark)', (tester) async {
      await _pump(
        tester,
        runs: [_run(4000)],
        earned: [_earned('first_run')],
        dark: dark,
      );
      final colors = dark ? AppColors.dark : AppColors.light;
      final bar = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('next-badge-bar')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(bar.color, colors.surfaceSoft);
      expect(bar.color, isNot(colors.surface));
      final locked = tester.widget<BadgeImage>(
        find.byKey(const ValueKey('badge-locked-dist_10k')),
      );
      expect(locked.earned, isFalse);
    });

    testWidgets('360×640 글자 1.3배에서 넘치지 않는다 (다크 $dark)', (tester) async {
      await _pump(
        tester,
        runs: [_run(4000)],
        earned: [_earned('first_run')],
        textScale: 1.3,
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('다음 배지'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets('긴 기록 1:05:00 과 배지 4개가 360×640 글자 1.3배에서 넘치지 않는다 (다크 $dark)', (
      tester,
    ) async {
      await _pump(
        tester,
        runs: [_run(21500, minutes: 65)],
        earned: [
          for (final id in ['first_run', 'dist_5k', 'dist_10k', 'dist_half'])
            _earned(id),
        ],
        textScale: 1.3,
        dark: dark,
      );
      expect(find.text('1:05:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void _designTests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;

    testWidgets('머리줄 뒤로는 48 흰 동그라미, 섹션은 흰 카드, 섹션 사이 28 ($name)', (
      tester,
    ) async {
      await _pump(
        tester,
        runs: [_run(4000)],
        earned: [_earned('first_run')],
        dark: dark,
      );
      final back = find.byType(CircleIconButton);
      expect(back, findsOneWidget);
      expect(tester.widget<CircleIconButton>(back).label, '뒤로');
      final records = tester.getRect(
        find.byKey(const ValueKey('records-card')),
      );
      final badges = find.text('배지 1 / 12');
      expect(tester.getRect(badges).top - records.bottom, Gap.s7);
      final card = tester.widget<AppCard>(
        find.byKey(const ValueKey('records-card')),
      );
      expect(card.radius, Radii.lg);
      expect(card.padding, const EdgeInsets.all(Gap.s5));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('badge-card')),
          matching: find.byType(BadgeImage),
        ),
        findsNWidgets(12),
      );
    });

    testWidgets('개인 기록은 2×2 칸, 값은 stat 22/800 ($name)', (tester) async {
      await _pump(tester, runs: [_run(6200, minutes: 40)], dark: dark);
      final value = tester.widget<Text>(find.text('6.20km'));
      expect(value.style!.fontSize, 22);
      expect(value.style!.fontWeight, FontWeight.w800);
      final a = tester.getRect(find.text('최장 거리'));
      final b = tester.getRect(find.text('최장 시간'));
      final d = tester.getRect(find.text('최고 1km'));
      expect(a.top, b.top); // 같은 줄
      expect(b.left, greaterThan(a.left));
      expect(d.top, greaterThan(a.bottom)); // 다음 줄
      expect(tester.widget<Text>(find.text('최장 거리')).style!.color, c.inkMuted);
    });

    testWidgets(
      '받은 배지 이름은 ink, 못 받은 것은 inkMuted, 다음 배지 코인은 코인 색 + 코인 그림 ($name)',
      (tester) async {
        await _pump(
          tester,
          runs: [_run(4000)],
          earned: [_earned('first_run')],
          dark: dark,
        );
        expect(tester.widget<Text>(find.text('첫 러닝')).style!.color, c.ink);
        expect(
          tester.widget<Text>(find.text('하프 완주')).style!.color,
          c.inkMuted,
        );
        await tester.scrollUntilVisible(
          find.text('코인 +100'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tester.widget<Text>(find.text('코인 +100')).style!.color, c.coin);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('next-badge-card')),
            matching: find.byType(CoinIcon),
          ),
          findsOneWidget,
        );
      },
    );
  }
}
