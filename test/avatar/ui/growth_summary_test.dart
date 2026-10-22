import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/ui/badge_image.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/avatar/ui/growth_summary.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/shop/app/providers.dart';

import '../../run/ui/fakes.dart';

GrowthGain gain({
  int distanceXp = 50,
  int goalBonusXp = 0,
  int levelBefore = 1,
  int levelAfter = 1,
  int stageBefore = 1,
  int stageAfter = 1,
  List<String> newBadges = const [],
}) => GrowthGain(
  distanceXp: distanceXp,
  goalBonusXp: goalBonusXp,
  levelBefore: levelBefore,
  levelAfter: levelAfter,
  stageBefore: stageBefore,
  stageAfter: stageAfter,
  newBadges: newBadges,
);

Widget _scope(Widget child) => ProviderScope(
  overrides: [shopRepositoryProvider.overrideWithValue(FakeShop())],
  child: child,
);

Future<void> pumpIt(WidgetTester tester, GrowthGain g) async {
  await tester.pumpWidget(
    _scope(
      MaterialApp(
        theme: appLightTheme(),
        home: Scaffold(
          body: GrowthSummary(
            kind: AvatarKind.chick,
            gain: g,
            distanceM: 5020,
            goal: null,
            movingTime: Duration.zero,
            achieved: false,
          ),
        ),
      ),
    ),
  );
}

/// 아바타 티커는 멈추지 않아 pumpAndSettle 을 쓸 수 없다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  coinTests();
  layoutTests();
  testWidgets('레벨업이면 경험치 행과 레벨 업 문구가 보인다', (tester) async {
    await pumpIt(tester, gain(levelAfter: 2));
    expect(find.text('달린 거리 5.02km'), findsOneWidget);
    expect(find.text('경험치 +50'), findsOneWidget);
    expect(find.text('레벨 업!'), findsOneWidget);
    expect(find.text('Lv.1 에서 Lv.2 로'), findsOneWidget);
    expect(find.text('새 외형 단계!'), findsNothing);
    await settle(tester);
  });

  testWidgets('레벨업이 없으면 레벨 업 문구가 없다', (tester) async {
    await pumpIt(tester, gain());
    expect(find.text('경험치 +50'), findsOneWidget);
    expect(find.text('레벨 업!'), findsNothing);
    expect(find.byType(AvatarView), findsNothing);
  });

  testWidgets('새 배지마다 배지 획득 줄과 코인 줄을 보인다', (tester) async {
    await pumpIt(tester, gain(newBadges: ['dist_5k', 'first_run']));
    expect(find.text('배지 획득: 첫 5km'), findsOneWidget);
    expect(find.text('코인 +100'), findsOneWidget);
    expect(find.text('배지 획득: 첫 러닝'), findsOneWidget);
    expect(find.text('코인 +50'), findsOneWidget);
    // 배지 줄마다 받은 배지 그림(컬러)을 이름 앞에 둔다.
    for (final id in ['dist_5k', 'first_run']) {
      final image = tester.widget<BadgeImage>(
        find.byKey(ValueKey('new-badge-$id')),
      );
      expect(image.id, id);
      expect(image.earned, isTrue);
    }
  });

  testWidgets('새 배지 줄이 360×640 글자 1.3배에서 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _scope(
        MaterialApp(
          theme: appLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrowthSummary(
                kind: AvatarKind.chick,
                gain: gain(newBadges: ['dist_half', 'goals_30']),
                distanceM: 5020,
                goal: null,
                movingTime: Duration.zero,
                achieved: false,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.text('배지 획득: 하프 완주'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('새 배지가 없으면 배지 줄이 없다', (tester) async {
    await pumpIt(tester, gain());
    expect(find.textContaining('배지 획득'), findsNothing);
  });

  testWidgets('경험치가 0이어도 경험치 +0 을 보인다', (tester) async {
    await pumpIt(tester, gain(distanceXp: 0));
    expect(find.text('경험치 +0'), findsOneWidget);
    expect(find.textContaining('목표'), findsNothing);
  });

  testWidgets('단계가 오르면 문구와 함께 아바타가 이전 단계에서 새 단계로 바뀐다', (tester) async {
    await pumpIt(
      tester,
      gain(levelBefore: 4, levelAfter: 5, stageBefore: 1, stageAfter: 2),
    );
    expect(find.text('새 외형 단계!'), findsOneWidget);
    expect(find.text('레벨 업!'), findsOneWidget);
    expect(tester.widget<AvatarView>(find.byType(AvatarView)).stage, 1);
    await settle(tester);
    expect(tester.widget<AvatarView>(find.byType(AvatarView)).stage, 2);
  });

  testWidgets('레벨업 아바타가 0.6초 동안 커졌다 돌아온다', (tester) async {
    await pumpIt(tester, gain(levelAfter: 2));
    double scaleNow() => tester
        .widget<Transform>(find.byKey(const ValueKey('level-up-scale')))
        .transform
        .storage[0];
    expect(scaleNow(), closeTo(1, 0.001));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(scaleNow(), greaterThan(1.1));
    await tester.pump(const Duration(milliseconds: 350));
    expect(scaleNow(), closeTo(1, 0.001));
  });

  testWidgets('종류를 모르면 아바타 대신 같은 크기의 빈 자리를 둔다', (tester) async {
    await tester.pumpWidget(
      _scope(
        MaterialApp(
          theme: appLightTheme(),
          home: Scaffold(
            body: GrowthSummary(
              kind: null,
              gain: gain(stageAfter: 2),
              distanceM: 5020,
              goal: null,
              movingTime: Duration.zero,
              achieved: false,
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(AvatarView), findsNothing);
    // 마스코트 판 무대의 8배 자리(작업 13, 예전 6배).
    expect(tester.getSize(find.byType(AvatarSlot)), const Size(256, 256));
  });

  group('빠른 이동 안내', () {
    Future<void> pumpExcluded(
      WidgetTester tester,
      double excludedM, {
      double scale = 1.0,
    }) async {
      await tester.pumpWidget(
        _scope(
          MaterialApp(
            theme: appLightTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: GrowthSummary(
                  kind: AvatarKind.chick,
                  gain: gain(),
                  distanceM: 5020,
                  goal: null,
                  movingTime: Duration.zero,
                  achieved: false,
                  excludedM: excludedM,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('뺀 거리가 있으면 한 줄 안내가 보인다', (tester) async {
      await pumpExcluded(tester, 1200);
      expect(find.text('빠른 이동 1.20km는 경험치에서 뺐어요'), findsOneWidget);
    });

    testWidgets('0 이면 아무것도 안 보인다', (tester) async {
      await pumpExcluded(tester, 0);
      expect(find.textContaining('빠른 이동'), findsNothing);
    });

    testWidgets('글자 1.3배에서 넘치지 않는다', (tester) async {
      await pumpExcluded(tester, 1200, scale: 1.3);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('빠른 이동'), findsOneWidget);
    });
  });

  group('오늘 목표 결과', () {
    Future<void> pumpGoal(
      WidgetTester tester, {
      required double distanceM,
      required RunGoal? goal,
      Duration movingTime = Duration.zero,
      required bool achieved,
      double excludedM = 0,
      int bonus = 0,
      double scale = 1.0,
    }) async {
      await tester.pumpWidget(
        _scope(
          MaterialApp(
            theme: appLightTheme(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: GrowthSummary(
                  kind: AvatarKind.chick,
                  gain: gain(goalBonusXp: bonus),
                  distanceM: distanceM,
                  goal: goal,
                  movingTime: movingTime,
                  achieved: achieved,
                  excludedM: excludedM,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('달성이면 목표 줄과 보너스가 success 색으로 보인다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const DistanceGoal(5000),
        achieved: true,
        bonus: 25,
      );
      expect(find.text('목표 5km 달성'), findsOneWidget);
      final bonus = tester.widget<Text>(find.text('보너스 +25'));
      final ctx = tester.element(find.text('보너스 +25'));
      expect(bonus.style!.color, AppColors.of(ctx).success);
    });

    testWidgets('달성인데 이번 증가분 보너스가 0 이어도 목표 보너스를 보여 준다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const DistanceGoal(5000),
        achieved: true,
        bonus: 0,
      );
      expect(find.text('보너스 +25'), findsOneWidget);
      expect(find.text('보너스 +0'), findsNothing);
    });

    testWidgets('미달이면 남은 거리를 보조 글자색으로 안내한다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const DistanceGoal(10000),
        achieved: false,
      );
      final finder = find.text('목표 10km까지 4.98km 남았어요');
      expect(finder, findsOneWidget);
      final ctx = tester.element(finder);
      expect(
        tester.widget<Text>(finder).style!.color,
        AppColors.of(ctx).inkMuted,
      );
      expect(find.textContaining('보너스'), findsNothing);
    });

    testWidgets('빠른 이동 때문에 미달이면 이유를 보인다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const DistanceGoal(5000),
        achieved: false,
        excludedM: 1000,
      );
      expect(find.text('빠른 이동을 빼면 목표에 못 미쳤어요'), findsOneWidget);
      expect(find.textContaining('남았어요'), findsNothing);
    });

    testWidgets('시간 목표 달성이면 목표 30분 달성과 보너스를 보인다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const TimeGoal(Duration(minutes: 30)),
        movingTime: const Duration(minutes: 31),
        achieved: true,
        bonus: 25,
      );
      expect(find.text('목표 30분 달성'), findsOneWidget);
      expect(find.text('보너스 +25'), findsOneWidget);
    });

    testWidgets('시간 목표 미달이면 남은 시간을 안내한다', (tester) async {
      await pumpGoal(
        tester,
        distanceM: 4000,
        goal: const TimeGoal(Duration(minutes: 30)),
        movingTime: const Duration(minutes: 25, seconds: 48),
        achieved: false,
      );
      expect(find.text('목표 30분까지 4:12 남았어요'), findsOneWidget);
      expect(find.textContaining('보너스'), findsNothing);
    });

    testWidgets('목표가 없으면 목표 줄이 없다', (tester) async {
      await pumpGoal(tester, distanceM: 5020, goal: null, achieved: false);
      expect(find.textContaining('목표'), findsNothing);
      expect(find.textContaining('보너스'), findsNothing);
    });

    testWidgets('글자 1.3배 360x640 에서 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpGoal(
        tester,
        distanceM: 10020,
        goal: const DistanceGoal(10000),
        achieved: true,
        bonus: 50,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await pumpGoal(
        tester,
        distanceM: 5020,
        goal: const DistanceGoal(10000),
        achieved: false,
        excludedM: 1200,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

void coinTests() {
  Future<void> pumpGoal(
    WidgetTester tester,
    GrowthGain g, {
    bool dark = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _scope(
        MaterialApp(
          theme: dark ? appDarkTheme() : appLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: GrowthSummary(
                kind: AvatarKind.chick,
                gain: g,
                distanceM: 3130,
                goal: const DistanceGoal(3000),
                movingTime: Duration.zero,
                achieved: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GrowthGain coinGain(int d, int g) => GrowthGain(
    distanceXp: 31,
    goalBonusXp: 15,
    distanceCoins: d,
    goalCoins: g,
    levelBefore: 1,
    levelAfter: 1,
    stageBefore: 1,
    stageAfter: 1,
  );

  testWidgets('거리 줄과 달성 줄 아래에 코인 줄이 보인다', (tester) async {
    await pumpGoal(tester, coinGain(15, 15));
    expect(find.text('경험치 +31'), findsOneWidget);
    expect(find.text('보너스 +15'), findsOneWidget);
    expect(find.text('코인 +15'), findsNWidgets(2));
  });

  testWidgets('코인이 0이면 코인 줄이 없다', (tester) async {
    await pumpGoal(tester, coinGain(0, 0));
    expect(find.textContaining('코인'), findsNothing);
    expect(find.text('경험치 +31'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('360×640 글자 1.3배 ${dark ? '다크' : '라이트'} 넘침 없음', (tester) async {
      await pumpGoal(tester, coinGain(15, 15), dark: dark, scale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}

/// 시안 c 요약 배치(작업 13): 마스코트 판, 흰 카드 하나에 행들.
void layoutTests() {
  Future<void> pumpAt(
    WidgetTester tester,
    GrowthGain g, {
    double width = 390,
    bool dark = false,
    double scale = 1,
    RunGoal? goal = const DistanceGoal(5000),
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _scope(
        MaterialApp(
          theme: dark ? appDarkTheme() : appLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1600),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
                child: GrowthSummary(
                  kind: AvatarKind.chick,
                  gain: g,
                  distanceM: 5240,
                  goal: goal,
                  movingTime: const Duration(minutes: 32),
                  achieved: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  GrowthGain full({bool levelUp = true, bool stageUp = true}) => GrowthGain(
    distanceXp: 52,
    goalBonusXp: 25,
    distanceCoins: 26,
    goalCoins: 25,
    levelBefore: 19,
    levelAfter: levelUp ? 20 : 19,
    stageBefore: 3,
    stageAfter: stageUp ? 4 : 3,
    newBadges: const ['goals_30'],
  );

  Rect card(WidgetTester tester, String text) => tester.getRect(
    find.ancestor(of: find.text(text), matching: find.byType(AppCard)).first,
  );

  group('시안 배치(작업 13)', () {
    for (final dark in [false, true]) {
      testWidgets('마스코트 판: 흰 카드 안 카드 폭 사각 무대, 8배 펫 (${dark ? '다크' : '라이트'})', (
        tester,
      ) async {
        await pumpAt(tester, full(), dark: dark);
        final c = AppColors.of(tester.element(find.text('레벨 업!')));
        final board = find.byKey(const ValueKey('level-up-card'));
        final boardBox = tester.widget<AppCard>(board);
        expect(boardBox.color ?? c.surface, c.surface);
        expect(boardBox.radius, Radii.xl);
        final stage = tester.widget<PetStage>(find.byType(PetStage));
        expect(stage.radius, Stage.radiusInCard);
        expect(stage.scale, 8);
        expect(tester.widget<AvatarView>(find.byType(AvatarView)).scale, 8);
        final boardRect = tester.getRect(board);
        final stageRect = tester.getRect(find.byType(PetStage));
        expect(stageRect.left, boardRect.left + Gap.s5);
        expect(stageRect.right, boardRect.right - Gap.s5);
        expect(stageRect.bottom, boardRect.bottom - Gap.s5);
        // 무대 위에는 글자를 두지 않는다: 문구는 모두 무대 위쪽.
        for (final t in ['레벨 업!', 'Lv.19 에서 Lv.20 로', '새 외형 단계!']) {
          expect(tester.getRect(find.text(t)).bottom, lessThan(stageRect.top));
        }
        expect(
          tester.widget<Text>(find.text('레벨 업!')).style!.color,
          c.primaryDeep,
        );
      });
    }

    testWidgets('새 외형 단계! 는 무대색 알약에 stage-ink 글자', (tester) async {
      await pumpAt(tester, full());
      final c = AppColors.of(tester.element(find.text('새 외형 단계!')));
      expect(
        tester.widget<Text>(find.text('새 외형 단계!')).style!.color,
        c.stageInk,
      );
      final pill = tester.widget<DecoratedBox>(
        find
            .ancestor(
              of: find.text('새 외형 단계!'),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((pill.decoration as BoxDecoration).color, c.stageSky);
    });

    testWidgets('카드 폭이 256 보다 좁으면 들어가는 가장 큰 배율로 줄인다', (tester) async {
      // 320 - 좌우 20 - 판 안 20 × 2 = 240 → 7배(224).
      await pumpAt(tester, full(), width: 320);
      expect(tester.widget<PetStage>(find.byType(PetStage)).scale, 7);
      expect(tester.takeException(), isNull);
    });

    testWidgets('행 3개(거리·목표·배지)는 흰 카드 하나 안에 있다', (tester) async {
      await pumpAt(tester, full());
      final rows = card(tester, '달린 거리 5.24km');
      expect(card(tester, '목표 5km 달성'), rows);
      expect(card(tester, '배지 획득: 목표 달성 30번'), rows);
      // 마스코트 판과 행 카드 사이는 카드 사이 간격.
      final board = tester.getRect(find.byKey(const ValueKey('level-up-card')));
      expect(rows.top - board.bottom, Gap.s3);
    });

    testWidgets('레벨 업이 없으면 무대 없이 행 카드만', (tester) async {
      await pumpAt(tester, full(levelUp: false, stageUp: false));
      expect(find.byType(PetStage), findsNothing);
      expect(find.byKey(const ValueKey('level-up-card')), findsNothing);
      expect(card(tester, '달린 거리 5.24km'), card(tester, '목표 5km 달성'));
    });

    testWidgets('배지 줄 코인 +200 은 다른 코인 +N 보다 크고 굵다', (tester) async {
      await pumpAt(tester, full());
      final c = AppColors.of(tester.element(find.text('코인 +200')));
      final badge = tester.widget<Text>(find.text('코인 +200')).style!;
      final other = tester.widget<Text>(find.text('코인 +26')).style!;
      expect(badge.color, c.coin);
      expect(other.color, c.coin);
      expect(badge.fontSize!, greaterThan(other.fontSize!));
      expect(badge.fontWeight!.value, greaterThan(other.fontWeight!.value));
      // 경험치 값과 같은 크기·굵기.
      final xp = tester.widget<Text>(find.text('경험치 +52')).style!;
      expect(badge.fontSize, xp.fontSize);
      expect(badge.fontWeight, xp.fontWeight);
    });

    for (final dark in [false, true]) {
      testWidgets('360 폭 글자 1.3배 넘침 없음 (${dark ? '다크' : '라이트'})', (
        tester,
      ) async {
        await pumpAt(tester, full(), width: 360, dark: dark, scale: 1.3);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
