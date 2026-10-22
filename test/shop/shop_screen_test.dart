import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/profile/app/providers.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/ui/coin_chip.dart';
import 'package:runmagochi/shop/ui/coin_history_screen.dart';
import 'package:runmagochi/shop/ui/shop_screen.dart';

import '../run/ui/fakes.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpShop(
  WidgetTester tester,
  FakeShop shop, {
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
        home: const Scaffold(body: ShopScreen()),
      ),
    ),
  );
  await settle(tester);
}

Map<String, String> stagePaths(WidgetTester tester) => tester
    .state<AvatarViewState>(find.byKey(const ValueKey('shop-stage-avatar')))
    .layerPaths;

AppButton bottomButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byKey(const ValueKey('shop-action')));

void main() {
  _designTests();
  testWidgets('제목, 코인 칩, 모자 3개와 가격이 보인다', (tester) async {
    await pumpShop(tester, FakeShop(const [], 1240));
    expect(find.text('상점'), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    expect(find.text('러닝 캡'), findsOneWidget);
    expect(find.text('비니'), findsOneWidget);
    expect(find.text('밀짚모자'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('선글라스'), findsNothing);
    await tester.tap(find.text('소품'));
    await settle(tester);
    expect(find.text('선글라스'), findsOneWidget);
    expect(find.text('러닝 캡'), findsNothing);
  });

  testWidgets('코인 칩을 누르면 코인 내역을 연다', (tester) async {
    await pumpShop(tester, FakeShop(const [], 10));
    await tester.tap(find.byType(CoinChip));
    await settle(tester);
    expect(find.byType(CoinHistoryScreen), findsOneWidget);
  });

  testWidgets('잔액이 모자라면 부족한 만큼 알리고 버튼이 꺼진다', (tester) async {
    await pumpShop(tester, FakeShop(const [], 80));
    expect(find.text('코인이 20 부족해요'), findsOneWidget);
    expect(bottomButton(tester).onPressed, isNull);
    expect(bottomButton(tester).label, '100 코인으로 구매하고 장착');
  });

  testWidgets('아이템을 고르면 무대 아바타에 입혀 보고, 고르지 않은 부위는 장착한 채다', (tester) async {
    final shop = FakeShop(const [], 500, const Equipped(hatItemId: 'cap'), {
      'cap',
    });
    await pumpShop(tester, shop);
    expect(stagePaths(tester)['hat'], contains('/hat/cap_'));
    await tester.tap(find.text('비니'));
    await settle(tester);
    expect(stagePaths(tester)['hat'], contains('/hat/beanie_'));
    // 장착 상태는 그대로다.
    expect(shop.equippedNow.hatItemId, 'cap');
  });

  testWidgets('구매하면 확인 창 뒤 사고 바로 장착한다', (tester) async {
    final shop = FakeShop(const [], 250);
    await pumpShop(tester, shop);
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    expect(find.text('러닝 캡을 100 코인에 살까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await settle(tester);
    expect(shop.purchases, isEmpty);

    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    await tester.tap(find.text('구매'));
    await settle(tester);
    expect(shop.purchases, [('cap', 100)]);
    expect(shop.bal, 150);
    expect(shop.owned, {'cap'});
    expect(shop.equippedNow.hatItemId, 'cap');
    expect(find.text('150'), findsOneWidget);
    expect(bottomButton(tester).label, '벗기');
    expect(find.text('장착 중'), findsOneWidget);
  });

  testWidgets('을·를 조사가 이름에 맞는다', (tester) async {
    await pumpShop(tester, FakeShop(const [], 500));
    await tester.tap(find.text('비니'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    expect(find.text('비니를 200 코인에 살까요?'), findsOneWidget);
  });

  testWidgets('구매 버튼을 빠르게 두 번 눌러도 한 번만 산다', (tester) async {
    final shop = FakeShop(const [], 500);
    shop.holdPurchase = Completer<void>();
    await pumpShop(tester, shop);
    final button = find.byKey(const ValueKey('shop-action'));
    await tester.tap(button);
    await tester.tap(button);
    await settle(tester);
    await tester.tap(find.text('구매'));
    await tester.pump();
    // 진행 중에는 버튼이 막힌다.
    expect(bottomButton(tester).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    shop.holdPurchase!.complete();
    await settle(tester);
    expect(shop.purchases, hasLength(1));
    expect(shop.bal, 400);
  });

  testWidgets('이미 샀거나 잔액이 모자라 실패하면 짧게 알리고 새로 읽는다', (tester) async {
    final shop = FakeShop(const [], 500);
    await pumpShop(tester, shop);
    shop.bal = 50; // 화면은 아직 500 으로 알고 있다.
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    await tester.tap(find.text('구매'));
    await settle(tester);
    expect(find.text('코인이 모자라요'), findsOneWidget);
    expect(find.text('코인이 50 부족해요'), findsOneWidget);
    expect(shop.owned, isEmpty);
  });

  testWidgets('다른 곳에서 이미 산 아이템이면 알리고 보유로 바뀐다', (tester) async {
    final shop = FakeShop(const [], 500);
    await pumpShop(tester, shop);
    shop.owned.add('cap'); // 화면은 아직 미보유로 알고 있다.
    expect(bottomButton(tester).label, '100 코인으로 구매하고 장착');
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    await tester.tap(find.text('구매'));
    await settle(tester);
    expect(find.text('이미 가진 아이템이에요'), findsOneWidget);
    expect(bottomButton(tester).label, '장착하기');
  });

  testWidgets('보유한 아이템은 장착하기, 장착 중이면 벗기로 해제한다', (tester) async {
    final shop = FakeShop(const [], 0, const Equipped(), {'cap'});
    await pumpShop(tester, shop);
    expect(find.text('보유'), findsOneWidget);
    expect(bottomButton(tester).label, '장착하기');
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    expect(shop.equippedNow.hatItemId, 'cap');
    expect(bottomButton(tester).label, '벗기');
    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    expect(shop.equippedNow.hatItemId, isNull);
    expect(bottomButton(tester).label, '장착하기');
  });

  for (final dark in [false, true]) {
    testWidgets('360×640 글자 1.3배 ${dark ? '다크' : '라이트'} 넘침 없음', (tester) async {
      final shop = FakeShop(const [], 12345);
      await pumpShop(tester, shop, dark: dark, scale: 1.3);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('소품'));
      await settle(tester);
      await tester.ensureVisible(find.text('꽃 머리핀'));
      await settle(tester);
      await tester.tap(find.text('꽃 머리핀'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('shop-action')));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('꽃 머리핀을 350 코인에 살까요?'), findsOneWidget);
    });
  }

  testWidgets('앱: 탭 4개, 홈 칩이 상점 탭을 열고 구매가 홈 아바타에 반영된다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final shop = FakeShop(const [], 300);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          profileRepositoryProvider.overrideWithValue(FakeProfile()),
          notificationSchedulerProvider.overrideWithValue(
            FakeNotificationScheduler(),
          ),
          shopRepositoryProvider.overrideWithValue(shop),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState()),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await settle(tester);
    Map<String, String> homePaths() => tester
        .state<AvatarViewState>(
          find.descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(AvatarView),
          ),
        )
        .layerPaths;
    expect(homePaths().containsKey('hat'), isFalse);

    // 홈 칩 → 상점 탭
    await tester.tap(find.byType(CoinChip).first);
    await settle(tester);
    expect(find.byType(CoinHistoryScreen), findsNothing);
    expect(
      tester.getRect(find.byType(ShopScreen)).left,
      0,
      reason: '상점 탭이 보인다',
    );
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);

    await tester.tap(find.byKey(const ValueKey('shop-action')));
    await settle(tester);
    await tester.tap(find.text('구매'));
    await settle(tester);
    expect(shop.equippedNow.hatItemId, 'cap');

    await tester.tap(find.text('러닝'));
    await settle(tester);
    expect(homePaths()['hat'], contains('/hat/cap_'));
  });
}

void _designTests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;

    testWidgets('미리보기는 폭 전체 사각 무대 6배, 무대 위 글자 없음 ($name)', (tester) async {
      await pumpShop(tester, FakeShop(const [], 500), dark: dark);
      final stage = find.byKey(const ValueKey('shop-stage'));
      final w = tester.widget<PetStage>(stage);
      expect(w.scale, 6);
      expect(w.radius, Stage.radius);
      expect(tester.getRect(stage).width, 360 - 2 * Gap.s5);
      expect(
        find.descendant(
          of: stage,
          matching: find.byKey(const ValueKey('shop-stage-avatar')),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<AvatarView>(find.byKey(const ValueKey('shop-stage-avatar')))
            .scale,
        6,
      );
      expect(
        find.descendant(of: stage, matching: find.byType(Text)),
        findsNothing,
      );
    });

    testWidgets('아이템 카드 미리보기도 작은 사각 무대(하늘·땅) 위 3배, 가격은 코인 그림 ($name)', (
      tester,
    ) async {
      await pumpShop(tester, FakeShop(const [], 500), dark: dark);
      final card = find.byKey(const ValueKey('item-beanie'));
      final mini = tester.widget<PetStage>(
        find.descendant(of: card, matching: find.byType(PetStage)),
      );
      expect(mini.scale, 3);
      expect(mini.groundHeight, Stage.groundHeightMini);
      expect(mini.radius, Radii.sm);
      final pet = tester.widget<AvatarView>(
        find.descendant(of: card, matching: find.byType(AvatarView)),
      );
      expect(pet.hatItemId, 'beanie');
      expect(
        find.descendant(of: card, matching: find.byType(CoinIcon)),
        findsOneWidget,
      );
      final app = tester.widget<AppCard>(
        find.descendant(of: card, matching: find.byType(AppCard)),
      );
      expect(app.radius, Radii.md);
      // 고른 카드(첫 아이템)만 경계선.
      final chosen = tester.widget<AppCard>(
        find.descendant(
          of: find.byKey(const ValueKey('item-cap')),
          matching: find.byType(AppCard),
        ),
      );
      expect(chosen.borderColor, c.primaryEdge);
      expect(app.borderColor, isNull);
    });

    testWidgets('구매 확인은 테마 다이얼로그: 취소 글자 버튼 + 구매 연두 버튼 ($name)', (tester) async {
      await pumpShop(tester, FakeShop(const [], 500), dark: dark);
      await tester.tap(find.byKey(const ValueKey('shop-action')));
      await settle(tester);
      expect(
        find.ancestor(of: find.text('구매'), matching: find.byType(FilledButton)),
        findsOneWidget,
      );
      expect(
        find.ancestor(of: find.text('취소'), matching: find.byType(TextButton)),
        findsOneWidget,
      );
    });
  }
}
