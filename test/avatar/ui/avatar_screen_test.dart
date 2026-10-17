import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/ui/avatar_screen.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';

import '../../run/ui/fakes.dart';

GrowthState stateFor(int totalXp) {
  final lv = levelFor(totalXp);
  return GrowthState(
    kind: AvatarKind.chick,
    name: '러니',
    totalXp: totalXp,
    level: lv,
    stage: stageForLevel(lv.level),
    xpToNextStage: xpToNextStage(totalXp),
    mood: AvatarMood.normal,
    weekTargetM: 10000,
    weekDistanceM: 0,
    weekAchieved: false,
    streakWeeks: 0,
    totalDistanceM: 34800,
    runCount: 12,
  );
}

Future<void> pumpIt(
  WidgetTester tester,
  int totalXp, {
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        growthServiceProvider.overrideWithValue(
          FakeGrowthService(stateFor(totalXp)),
        ),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: AvatarScreen()),
      ),
    ),
  );
  // 아바타 티커는 멈추지 않아 pumpAndSettle 을 쓸 수 없다.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('이름·레벨·누적 기록·다음 단계까지 남은 거리를 보여 준다', (tester) async {
    await pumpIt(tester, 348); // Lv.4, 다음 단계(500)까지 152
    expect(find.text('러니 Lv.4'), findsOneWidget);
    expect(find.text('누적 34.80km · 러닝 12회'), findsOneWidget);
    expect(find.text('다음 성장 단계까지 15.2km'), findsOneWidget);
    expect(find.text('성장 단계'), findsOneWidget);
  });

  testWidgets('단계 4행과 현재·잠김·달성 상태', (tester) async {
    await pumpIt(tester, 600); // Lv.5 → 2단계
    expect(find.text('1단계 알·새싹'), findsOneWidget);
    expect(find.text('2단계 어린 러너'), findsOneWidget);
    expect(find.text('3단계 러너'), findsOneWidget);
    expect(find.text('4단계 마라토너'), findsOneWidget);
    expect(find.text('달성'), findsOneWidget);
    expect(find.text('현재'), findsOneWidget);
    expect(find.text('잠김'), findsNWidgets(2));
    // 현재 아바타 1 + 행 미리보기 4
    expect(find.byType(AvatarView), findsNWidgets(5));
  });

  testWidgets('최고 단계면 최고 단계 문구를 보여 준다', (tester) async {
    await pumpIt(tester, 9500);
    expect(find.text('최고 단계'), findsOneWidget);
    expect(find.textContaining('다음 성장 단계까지'), findsNothing);
    expect(find.text('달성'), findsNWidgets(3));
    expect(find.text('현재'), findsOneWidget);
    expect(find.text('잠김'), findsNothing);
  });

  testWidgets('레벨 범위는 단계 이름과 따로 보인다', (tester) async {
    await pumpIt(tester, 600);
    expect(find.text('Lv.1~4'), findsOneWidget);
    expect(find.text('Lv.5~9'), findsOneWidget);
    expect(find.text('Lv.10~19'), findsOneWidget);
    expect(find.text('Lv.20~'), findsOneWidget);
  });

  testWidgets('글자 크기 1.3배에서 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpIt(tester, 348, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('현재 단계 카드는 primary 테두리, 잠긴 미리보기는 흐리다', (tester) async {
    await pumpIt(tester, 600);
    final cards = tester.widgetList<ClayCard>(find.byType(ClayCard)).toList();
    // 단계 카드 4 (무대 카드는 립이 없는 별도 상자)
    expect(cards, hasLength(4));
    const c = AppColors.light;
    expect(cards[1].borderColor, c.primary);
    expect(cards[1].lipColor, c.primaryDeep);
    expect(cards[0].borderColor, isNull);
    expect(
      tester
          .widgetList<Opacity>(find.byType(Opacity))
          .where((o) => o.opacity == 0.45),
      hasLength(2),
    );
  });
}
