import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/avatar/ui/growth_summary.dart';
import 'package:runmagochi/core/theme.dart';

GrowthGain gain({
  int distanceXp = 50,
  int goalBonusXp = 0,
  int levelBefore = 1,
  int levelAfter = 1,
  int stageBefore = 1,
  int stageAfter = 1,
}) => GrowthGain(
  distanceXp: distanceXp,
  goalBonusXp: goalBonusXp,
  levelBefore: levelBefore,
  levelAfter: levelAfter,
  stageBefore: stageBefore,
  stageAfter: stageAfter,
);

Future<void> pumpIt(WidgetTester tester, GrowthGain g) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: appLightTheme(),
      home: Scaffold(
        body: GrowthSummary(
          kind: AvatarKind.chick,
          gain: g,
          distanceM: 5020,
          goalM: null,
          achieved: false,
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
      MaterialApp(
        theme: appLightTheme(),
        home: Scaffold(
          body: GrowthSummary(
            kind: null,
            gain: gain(stageAfter: 2),
            distanceM: 5020,
            goalM: null,
            achieved: false,
          ),
        ),
      ),
    );
    await settle(tester);
    expect(find.byType(AvatarView), findsNothing);
    expect(tester.getSize(find.byType(AvatarSlot)), const Size(192, 192));
  });

  group('빠른 이동 안내', () {
    Future<void> pumpExcluded(
      WidgetTester tester,
      double excludedM, {
      double scale = 1.0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: GrowthSummary(
                kind: AvatarKind.chick,
                gain: gain(),
                distanceM: 5020,
                goalM: null,
                achieved: false,
                excludedM: excludedM,
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
      required double? goalM,
      required bool achieved,
      double excludedM = 0,
      int bonus = 0,
      double scale = 1.0,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appLightTheme(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: GrowthSummary(
                kind: AvatarKind.chick,
                gain: gain(goalBonusXp: bonus),
                distanceM: distanceM,
                goalM: goalM,
                achieved: achieved,
                excludedM: excludedM,
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
        goalM: 5000,
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
        goalM: 5000,
        achieved: true,
        bonus: 0,
      );
      expect(find.text('보너스 +25'), findsOneWidget);
      expect(find.text('보너스 +0'), findsNothing);
    });

    testWidgets('미달이면 남은 거리를 보조 글자색으로 안내한다', (tester) async {
      await pumpGoal(tester, distanceM: 5020, goalM: 10000, achieved: false);
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
        goalM: 5000,
        achieved: false,
        excludedM: 1000,
      );
      expect(find.text('빠른 이동을 빼면 목표에 못 미쳤어요'), findsOneWidget);
      expect(find.textContaining('남았어요'), findsNothing);
    });

    testWidgets('목표가 없으면 목표 줄이 없다', (tester) async {
      await pumpGoal(tester, distanceM: 5020, goalM: null, achieved: false);
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
        goalM: 10000,
        achieved: true,
        bonus: 50,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      await pumpGoal(
        tester,
        distanceM: 5020,
        goalM: 10000,
        achieved: false,
        excludedM: 1200,
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
