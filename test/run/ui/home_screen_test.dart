import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/core/home_tab.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';
import 'package:runmagochi/run/ui/permission_screen.dart';
import 'package:runmagochi/run/ui/run_goal_picker.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/ui/coin_chip.dart';
import 'package:runmagochi/shop/ui/coin_history_screen.dart';

import 'fakes.dart';

Future<void> pumpHome(
  WidgetTester tester,
  FakeController controller, {
  FakeGate? gate,
  FakeRepo? repo,
  FakeGrowthService? growth,
  double textScale = 1,
  bool reduceMotion = false,
  int coins = 0,
  FakeShop? shop,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(() => controller),
        permissionGateProvider.overrideWithValue(
          gate ?? FakeGate(GateResult.ready),
        ),
        runRepositoryProvider.overrideWithValue(repo ?? FakeRepo((0, 0))),
        growthServiceProvider.overrideWithValue(
          growth ?? FakeGrowthService(growthState()),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
        shopRepositoryProvider.overrideWithValue(
          shop ?? FakeShop(const [], coins),
        ),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child!,
        ),
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pump();
}

/// 홈의 아바타 티커는 멈추지 않아 pumpAndSettle 이 끝나지 않는다. 고정 시간만 흘린다.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('장착을 바꾸면 홈 아바타가 새 아이템 레이어로 다시 그려진다', (tester) async {
    final shop = FakeShop(const [], 0, const Equipped(hatItemId: 'cap'));
    await pumpHome(tester, FakeController(), shop: shop);
    await settle(tester);
    Map<String, String> paths() =>
        tester.state<AvatarViewState>(find.byType(AvatarView)).layerPaths;
    expect(paths().keys.toList(), ['body', 'face', 'hat']);
    expect(paths()['hat'], contains('/hat/cap_'));

    shop.equippedNow = const Equipped(
      hatItemId: 'beanie',
      accessoryItemId: 'sunglasses',
    );
    ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    ).invalidate(equippedProvider);
    await settle(tester);
    expect(paths().keys.toList(), ['body', 'face', 'hat', 'accessory']);
    expect(paths()['hat'], contains('/hat/beanie_'));
  });

  testWidgets('코인 칩이 천 단위 쉼표 잔액을 보이고 누르면 상점 탭으로 바꾼다', (tester) async {
    await pumpHome(tester, FakeController(), coins: 1240);
    await tester.pump();
    expect(find.byType(CoinChip), findsOneWidget);
    expect(find.text('1,240'), findsOneWidget);
    await tester.tap(find.byType(CoinChip));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CoinHistoryScreen), findsNothing);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      ).read(homeTabProvider),
      3,
    );
  });

  testWidgets('아바타·레벨이 보이고 주간 목표는 없다', (tester) async {
    await pumpHome(tester, FakeController());
    await tester.pump();
    expect(
      tester.widget<AvatarView>(find.byType(AvatarView)).action,
      AvatarAction.idle,
    );
    expect(find.textContaining('주간'), findsNothing);
    expect(find.textContaining('이번 주'), findsNothing);
    expect(find.text('러니 Lv.3'), findsOneWidget);
    // 150 - 58 = 92 → 9.2km
    expect(find.text('다음 레벨까지 9.2km'), findsOneWidget);
  });

  testWidgets('시작 버튼 → 카운트다운 3 표시 → 3초 후 러닝 중 화면', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c);
    await tester.tap(find.text('시작'));
    await tester.pump();
    expect(find.text('3'), findsOneWidget);
    expect(c.calls, ['restore']);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(c.calls, ['restore', 'start']);
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('일시정지'), findsOneWidget);
  });

  testWidgets('권한이 준비되지 않으면 권한 화면이 열리고 준비되면 카운트다운이 이어진다', (tester) async {
    final gate = FakeGate(GateResult.needsLocation);
    final c = FakeController();
    await pumpHome(tester, c, gate: gate);
    await tester.tap(find.text('시작'));
    await settle(tester);
    expect(find.byType(PermissionScreen), findsOneWidget);
    expect(c.calls, ['restore']);

    gate.result = GateResult.ready;
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PermissionScreen), findsNothing);
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(c.calls, ['restore', 'start']);
  });

  testWidgets('권한 화면을 그냥 닫으면 시작하지 않는다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c, gate: FakeGate(GateResult.locationDeniedForever));
    await tester.tap(find.text('시작'));
    await settle(tester);
    expect(find.byType(PermissionScreen), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await settle(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(c.calls, ['restore']);
  });

  testWidgets('복구할 러닝이 있으면 다이얼로그 표시, 이어서 기록은 일시정지 화면', (tester) async {
    final c = FakeController(restore: true);
    await pumpHome(tester, c);
    await settle(tester);
    expect(find.text('기록 중이던 러닝이 있어요'), findsOneWidget);
    await tester.tap(find.text('이어서 기록'));
    await settle(tester);
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);
    expect(c.calls, ['restore']);
  });

  testWidgets('다시 읽는 동안에도 이전 값이 계속 보인다', (tester) async {
    final g = FakeGrowthService(growthState());
    final c = FakeController(restore: true);
    await pumpHome(tester, c, growth: g);
    await settle(tester);
    expect(find.text('러니 Lv.3'), findsOneWidget);

    g.holdLoad = Completer<void>();
    await tester.tap(find.text('종료하기'));
    await settle(tester);
    // load 가 아직 끝나지 않았다.
    expect(find.text('러니 Lv.3'), findsOneWidget);

    g.holdLoad!.complete();
    await settle(tester);
    expect(find.text('러니 Lv.3'), findsOneWidget);
  });

  testWidgets('복구 다이얼로그에서 종료하기는 end 후 홈에 남는다', (tester) async {
    final g = FakeGrowthService(growthState(name: '콩떡'));
    final c = FakeController(restore: true);
    await pumpHome(tester, c, growth: g);
    await settle(tester);
    expect(find.text('콩떡 Lv.3'), findsOneWidget);
    final before = g.loads;
    g.state = growthState(name: '말랑이');
    await tester.tap(find.text('종료하기'));
    await settle(tester);
    expect(c.calls, ['restore', 'end']);
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.text('말랑이 Lv.3'), findsOneWidget);
    expect(g.loads, greaterThan(before));
    expect(find.text('기록 중이던 러닝이 있어요'), findsNothing);
    expect(find.text('시작'), findsOneWidget);
    expect(find.byType(SummaryScreen), findsNothing);
  });

  testWidgets('복구할 러닝이 없으면 다이얼로그가 없고 restoreIfAny 는 한 번만 불린다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c);
    await settle(tester);
    expect(find.text('기록 중이던 러닝이 있어요'), findsNothing);
    expect(c.calls, ['restore']);
  });

  testWidgets('러닝이 끝나 홈으로 돌아오면 성장 상태를 다시 읽는다', (tester) async {
    final growth = FakeGrowthService(growthState(name: '콩떡'));
    final c = FakeController();
    await pumpHome(tester, c, growth: growth);
    expect(find.text('콩떡 Lv.3'), findsOneWidget);

    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    await tester.tap(find.text('일시정지'));
    await tester.pump();

    growth.state = growthState(name: '말랑이');
    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await settle(tester);
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.byType(SummaryScreen), findsOneWidget);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('말랑이 Lv.3'), findsOneWidget);
    expect(c.calls, ['restore', 'start', 'pause', 'end']);
    expect(c.state.snapshot.state, RunState.idle);
  });

  testWidgets('카운트다운 중 시작을 또 눌러도 start 는 한 번만 불린다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c);
    await tester.tap(find.text('시작'));
    await tester.pump();
    // 카운트다운 오버레이가 덮고 있어도 버튼 자체가 비활성이다.
    await tester.tap(find.text('시작'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('시작'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(c.calls.where((e) => e == 'start'), hasLength(1));
  });

  testWidgets('start 가 실패하면 카운트다운이 사라지고 시작 버튼이 다시 켜진다', (tester) async {
    final c = FakeController(startError: StateError('boom'));
    await pumpHome(tester, c);
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump();
    expect(find.text('러닝을 시작하지 못했어요'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(find.text('1'), findsNothing);
    expect(find.byType(InRunScreen), findsNothing);
    final button = tester.widget<AppButton>(
      find.widgetWithText(AppButton, '시작'),
    );
    expect(button.onPressed, isNotNull);
    await settle(tester);
  });

  Future<void> startRun(WidgetTester tester) async {
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  }

  Future<void> holdStop(WidgetTester tester) async {
    await tester.tap(find.text('일시정지'));
    await tester.pump();
    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await settle(tester);
  }

  testWidgets('이전 요약이 남아 있어도 end 없이 돌아오면 요약을 다시 보이지 않는다', (tester) async {
    final old = RunSummary(
      startedAt: DateTime(2026),
      endedAt: DateTime(2026),
      distanceM: 0,
      movingTime: Duration.zero,
      avgPaceSecPerKm: null,
      calories: 0,
      name: 'old',
      splits: const [],
      points: const [],
    );
    final c = FakeController(initialSummary: old);
    await pumpHome(tester, c);
    await startRun(tester);
    expect(find.byType(InRunScreen), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await settle(tester);
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.byType(SummaryScreen), findsNothing);
    expect(c.calls, isNot(contains('end')));
  });

  testWidgets('두 번째 러닝을 끝내면 새 요약이 보인다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c);
    await startRun(tester);
    await holdStop(tester);
    final first = c.state.lastSummary;
    await tester.tap(find.text('확인'));
    await settle(tester);

    await startRun(tester);
    await holdStop(tester);
    final second = c.state.lastSummary;
    expect(identical(first, second), isFalse);
    final screen = tester.widget<SummaryScreen>(find.byType(SummaryScreen));
    expect(screen.summary, same(second));
  });

  testWidgets('러닝을 끝내면 sync 한 번 후 요약에 gain 이 들어간다', (tester) async {
    final g = FakeGrowthService(growthState());
    final c = FakeController();
    // 컨트롤러는 끝나면 목표를 비우므로 요약은 저장된 러닝의 목표를 읽는다.
    final repo = FakeRepo(
      (0, 0),
      details: {
        'r': RunDetail(
          run: RunListItem(
            id: 'r',
            name: 'x',
            startedAt: DateTime(2026),
            distanceM: 0,
            movingTime: Duration.zero,
            avgPaceSecPerKm: null,
            goal: const DistanceGoal(3000),
          ),
          calories: 0,
          route: const [],
          splits: const [],
        ),
      },
    );
    await pumpHome(tester, c, growth: g, repo: repo);
    await startRun(tester);
    final before = g.syncs;
    // 러닝 중에 생긴 gain: 먼저 sync 한 쪽이 받는다.
    g.syncGain = const GrowthGain(
      distanceXp: 50,
      goalBonusXp: 50,
      levelBefore: 3,
      levelAfter: 4,
      stageBefore: 1,
      stageAfter: 1,
    );
    await holdStop(tester);
    // 우리 sync 한 번 + invalidate 뒤 provider 재계산의 sync 한 번.
    expect(g.syncs, before + 2);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.text('레벨 업!'), findsOneWidget);
    expect(find.text('Lv.3 → Lv.4'), findsOneWidget);
    expect(find.text('목표 3km까지 3.00km 남았어요'), findsOneWidget);
  });

  testWidgets('sync 가 실패해도 요약은 열리고 성장 영역만 빠진다', (tester) async {
    final g = FakeGrowthService(growthState())..syncFails = true;
    final c = FakeController();
    await pumpHome(tester, c, growth: g);
    await startRun(tester);
    await holdStop(tester);
    expect(find.byType(SummaryScreen), findsOneWidget);
    expect(find.textContaining('경험치'), findsNothing);
  });

  testWidgets('글자 크기 1.3배에서 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpHome(
      tester,
      FakeController(),
      growth: FakeGrowthService(growthState()),
      textScale: 1.3,
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('시작'), findsOneWidget);
  });

  group('시안 배치(작업 12)', () {
    /// 앱처럼 아래에 탭바를 둔 홈을 [size] 화면에 그린다.
    Future<void> pumpShell(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double textScale = 1,
      bool dark = false,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runControllerProvider.overrideWith(() => FakeController()),
            permissionGateProvider.overrideWithValue(
              FakeGate(GateResult.ready),
            ),
            runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
            growthServiceProvider.overrideWithValue(
              FakeGrowthService(growthState()),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
            shopRepositoryProvider.overrideWithValue(FakeShop(const [], 1860)),
          ],
          child: MaterialApp(
            theme: dark ? appDarkTheme() : appLightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(
              body: const HomeScreen(),
              bottomNavigationBar: AppTabBar(
                tabs: const [
                  AppTab(TabGlyph.run, '러닝'),
                  AppTab(TabGlyph.history, '기록'),
                  AppTab(TabGlyph.avatar, '아바타'),
                  AppTab(TabGlyph.shop, '상점'),
                ],
                index: 0,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('위에서부터 코인 칩·톱니 → 무대 → 이름 Lv·막대 → 오늘 목표 → 시작', (tester) async {
      await pumpShell(tester);
      final coin = tester.getRect(find.byType(CoinChip));
      final gear = tester.getRect(find.byKey(const ValueKey('home-settings')));
      final stage = tester.getRect(find.byKey(const ValueKey('home-stage')));
      final name = tester.getRect(find.text('러니 Lv.3'));
      final bar = tester.getRect(find.byType(ProgressBar));
      final picker = tester.getRect(find.byType(RunGoalPicker));
      final start = tester.getRect(find.byType(AppButton));
      // 코인 칩은 왼쪽, 톱니는 오른쪽 같은 줄. 둘 다 48 이상.
      expect(coin.left, Gap.s5);
      expect(gear.right, 390 - Gap.s5);
      expect(gear.center.dy, closeTo(coin.center.dy, 0.5));
      expect(gear.size, const Size(48, 48));
      expect(coin.height, greaterThanOrEqualTo(48));
      // 순서와 간격.
      expect(stage.top - coin.bottom, Gap.s4);
      expect(name.top, greaterThan(stage.bottom));
      expect(bar.top, greaterThan(name.bottom));
      expect(picker.top - bar.bottom, Gap.s4);
      expect(start.top - picker.bottom, Gap.s4);
      // 무대와 막대·카드·버튼은 좌우 여백 20 의 전체 폭.
      for (final r in [stage, bar, picker, start]) {
        expect(r.left, Gap.s5);
        expect(r.right, 390 - Gap.s5);
      }
      expect(name.center.dx, closeTo(195, 0.5));
    });

    testWidgets('무대: 사각 무대 위 8배 병아리와 다음 레벨 말풍선', (tester) async {
      await pumpShell(tester);
      final stage = find.byKey(const ValueKey('home-stage'));
      expect(tester.widget<PetStage>(stage).scale, 8);
      final pet = tester.getRect(find.byType(AvatarView));
      expect(pet.size, const Size(256, 256));
      expect(tester.getRect(stage).contains(pet.topLeft), isTrue);
      expect(
        find.descendant(
          of: find.byType(SpeechBubble),
          matching: find.text('다음 레벨까지 9.2km'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: stage, matching: find.byType(SpeechBubble)),
        findsOneWidget,
      );
    });

    for (final (size, scale) in [
      (const Size(390, 844), 1.0),
      (const Size(360, 640), 1.0),
      (const Size(360, 640), 1.3),
    ]) {
      testWidgets(
        '${size.width.toInt()}×${size.height.toInt()} 글자 $scale배: 말풍선은 펫 그림을 가리지 않는다',
        (tester) async {
          await pumpShell(tester, size: size, textScale: scale);
          final petScale = tester
              .widget<PetStage>(find.byKey(const ValueKey('home-stage')))
              .scale;
          expect(petScale, greaterThanOrEqualTo(3));
          final pet = tester.getRect(find.byType(AvatarView));
          final bubble = tester.getRect(find.byType(SpeechBubble));
          expect(
            bubble.bottom,
            lessThanOrEqualTo(pet.top + spriteTopGapRows * petScale),
          );
        },
      );
    }

    testWidgets('390×844 에서는 탭바와 함께 한 화면에 들어간다(스크롤 없음)', (tester) async {
      await pumpShell(tester);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scroll.position.maxScrollExtent, 0);
      expect(
        tester.getRect(find.byType(AppButton)).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(AppTabBar)).top),
      );
    });

    for (final dark in [false, true]) {
      testWidgets(
        '360×640 글자 1.3배 ${dark ? '다크' : '라이트'}: 탭바와 함께 넘침 없이 시작까지 한 화면에 들어간다',
        (tester) async {
          await pumpShell(
            tester,
            size: const Size(360, 640),
            textScale: 1.3,
            dark: dark,
          );
          expect(tester.takeException(), isNull);
          // 목표가 한 줄(작업 21)이 되어 작은 화면·큰 글자에서도 스크롤 없이 들어간다.
          final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
          expect(scroll.position.maxScrollExtent, 0);
          expect(
            tester
                .widget<PetStage>(find.byKey(const ValueKey('home-stage')))
                .scale,
            greaterThanOrEqualTo(3),
          );
          expect(
            tester.getRect(find.byType(AppButton)).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(AppTabBar)).top),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  testWidgets('레벨 막대가 하나 있다', (tester) async {
    await pumpHome(tester, FakeController());
    await settle(tester);
    expect(find.byType(ProgressBar), findsOneWidget);
    expect(find.widgetWithText(AppButton, '시작'), findsOneWidget);
  });

  testWidgets('종류를 읽기 전에는 병아리 대신 같은 크기의 빈 아바타 자리를 둔다', (tester) async {
    final g = FakeGrowthService(growthState(kind: AvatarKind.acorn))
      ..holdLoad = Completer<void>();
    await pumpHome(tester, FakeController(), growth: g);
    await settle(tester);
    expect(find.byType(AvatarView), findsNothing);
    final before = tester.getRect(find.byType(AvatarSlot));

    g.holdLoad!.complete();
    await settle(tester);
    expect(find.byType(AvatarSlot), findsNothing);
    expect(
      tester.widget<AvatarView>(find.byType(AvatarView)).kind,
      AvatarKind.acorn,
    );
    final after = tester.getRect(find.byType(AvatarView));
    expect(after.size, before.size);
    expect(after.center, before.center);
  });

  testWidgets('읽는 동안에도 시작 버튼과 무대 자리가 읽은 뒤와 같다', (tester) async {
    final g = FakeGrowthService(growthState())..holdLoad = Completer<void>();
    await pumpHome(tester, FakeController(), growth: g);
    await settle(tester);
    final button = tester.getRect(find.byType(AppButton));
    final stage = tester.getRect(find.byKey(const ValueKey('home-stage')));

    g.holdLoad!.complete();
    await settle(tester);
    expect(tester.getRect(find.byType(AppButton)), button);
    expect(tester.getRect(find.byKey(const ValueKey('home-stage'))), stage);
  });

  testWidgets('카운트다운 숫자는 number-l(64) 크기다', (tester) async {
    await pumpHome(tester, FakeController());
    await tester.tap(find.text('시작'));
    await tester.pump();
    expect(tester.widget<Text>(find.text('3')).style!.fontSize, 64);
    await tester.pump(const Duration(seconds: 4));
    await settle(tester);
  });

  group('오늘 목표 선택', () {
    /// 홈의 오늘 목표 줄.
    final row = find.byType(RunGoalPicker);

    /// 홈 줄에 보이는 값.
    Finder rowText(String text) =>
        find.descendant(of: row, matching: find.text(text));

    /// 시트 안 값 칩.
    Finder chip(String label) => find.widgetWithText(AppChip, label);

    /// 선택된 칩은 primary 바탕이다.
    Color? chipColor(WidgetTester tester, String label) {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: chip(label),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.decoration! as BoxDecoration).color;
    }

    Color primary(WidgetTester tester) =>
        AppColors.of(tester.element(find.byType(HomeScreen))).primary;

    FixedExtentScrollController wheel(WidgetTester tester) => tester
        .widget<CupertinoPicker>(find.byType(CupertinoPicker))
        .scrollController!;

    int wheelCount(WidgetTester tester) => tester
        .widget<CupertinoPicker>(find.byType(CupertinoPicker))
        .childDelegate
        .estimatedChildCount!;

    Future<void> openSheet(WidgetTester tester) async {
      await tester.tap(row);
      await settle(tester);
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AppButton, '확인'));
      await settle(tester);
    }

    Future<void> startAndWait(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(AppButton, '시작'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
    }

    testWidgets('러닝이 없으면 한 줄에 "오늘 목표 3km" 가 보이고 홈에는 칩이 없다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      expect(rowText('오늘 목표'), findsOneWidget);
      expect(rowText('3km'), findsOneWidget);
      expect(find.byType(AppChip), findsNothing);
      expect(find.byType(CupertinoPicker), findsNothing);
    });

    for (final (goal, label) in [
      (const DistanceGoal(5000), '5km'),
      (const DistanceGoal(12000), '12km'),
      (const TimeGoal(Duration(minutes: 20)), '20분'),
      (const TimeGoal(Duration(minutes: 45)), '45분'),
    ]) {
      testWidgets('지난 목표가 $label 이면 줄에 $label 이 보인다', (tester) async {
        await pumpHome(
          tester,
          FakeController(),
          repo: FakeRepo((0, 0))..lastRunGoal = goal,
        );
        await settle(tester);
        expect(rowText(label), findsOneWidget);
      });
    }

    testWidgets('고르지 않고 시작하면 지난 목표로 바로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(
        tester,
        c,
        repo: FakeRepo((0, 0))
          ..lastRunGoal = const TimeGoal(Duration(minutes: 20)),
      );
      await settle(tester);
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 20))]);
    });

    testWidgets('러닝이 없고 고르지 않고 시작하면 기본 3km 로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(3000)]);
    });

    testWidgets('줄은 높이 48 이상이고 "오늘 목표 3km" 버튼으로 읽힌다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      final handle = tester.ensureSemantics();
      final node = find.bySemanticsLabel('오늘 목표 3km');
      expect(node, findsOneWidget);
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: '오늘 목표 3km',
          hint: '눌러서 바꾸기',
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(tester.getSize(node).height, greaterThanOrEqualTo(48));
      handle.dispose();
    });

    testWidgets('줄을 누르면 시트에 거리·시간, 3·5·10km 칩, 3~42km 휠, 확인이 있다', (
      tester,
    ) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await openSheet(tester);
      for (final label in ['거리', '시간', '3km', '5km', '10km']) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      expect(chip('직접'), findsNothing);
      expect(chipColor(tester, '거리'), primary(tester));
      expect(chipColor(tester, '3km'), primary(tester));
      expect(chipColor(tester, '5km'), isNot(primary(tester)));
      expect(wheelCount(tester), 40);
      expect(wheel(tester).selectedItem, 0);
      expect(find.widgetWithText(AppButton, '확인'), findsOneWidget);
    });

    testWidgets('시트에서 10km 칩 → 확인 → 줄이 10km, 시작하면 10km 목표', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('10km'));
      await settle(tester);
      expect(chipColor(tester, '10km'), primary(tester));
      expect(wheel(tester).selectedItem, 7); // 3,4,…,10
      await confirm(tester);
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(rowText('10km'), findsOneWidget);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(10000)]);
    });

    testWidgets('휠 가운데 칸은 surface-soft 알약(경계 없음), 고른 값은 굵은 ink', (
      tester,
    ) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await openSheet(tester);
      final c0 = AppColors.of(tester.element(find.byType(CupertinoPicker)));
      final pill = tester
          .widgetList<Container>(
            find.descendant(
              of: find.bySemanticsLabel('목표 값'),
              matching: find.byType(Container),
            ),
          )
          .map((e) => e.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color == c0.surfaceSoft);
      expect(pill.border, isNull);
      final selected = tester.widget<Text>(
        find.descendant(
          of: find.byType(CupertinoPicker),
          matching: find.text('3km'),
        ),
      );
      expect(selected.style!.color, c0.ink);
      expect(selected.style!.fontWeight, FontWeight.w700);
    });

    testWidgets('휠을 끌어 고른 값이 시작에 쓰인다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await openSheet(tester);
      final extent = tester
          .widget<CupertinoPicker>(find.byType(CupertinoPicker))
          .itemExtent;
      await tester.drag(find.byType(CupertinoPicker), Offset(0, -extent * 4));
      await settle(tester);
      expect(wheel(tester).selectedItem, 4);
      // 칩에 없는 값이면 칩은 하나도 골라지지 않는다.
      for (final label in ['3km', '5km', '10km']) {
        expect(chipColor(tester, label), isNot(primary(tester)));
      }
      await confirm(tester);
      expect(rowText('7km'), findsOneWidget);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(7000)]);
    });

    for (final (index, km) in [(0, 3), (39, 42), (9, 12)]) {
      testWidgets('거리 휠 $index번째 → ${km}km 로 시작한다', (tester) async {
        final c = FakeController();
        await pumpHome(tester, c, repo: FakeRepo((0, 0))..lastGoalM = 5000);
        await settle(tester);
        await openSheet(tester);
        wheel(tester).jumpToItem(index);
        await settle(tester);
        await confirm(tester);
        await startAndWait(tester);
        expect(c.startGoals, [DistanceGoal(km * 1000.0)]);
      });
    }

    for (final (index, minutes) in [(0, 15), (33, 180), (6, 45)]) {
      testWidgets('시간 휠(5분 단위 34칸) $index번째 → $minutes분으로 시작한다', (
        tester,
      ) async {
        final c = FakeController();
        await pumpHome(tester, c);
        await settle(tester);
        await openSheet(tester);
        await tester.tap(chip('시간'));
        await settle(tester);
        expect(wheelCount(tester), 34);
        wheel(tester).jumpToItem(index);
        await settle(tester);
        await confirm(tester);
        expect(rowText('$minutes분'), findsOneWidget);
        await startAndWait(tester);
        expect(c.startGoals, [TimeGoal(Duration(minutes: minutes))]);
      });
    }

    testWidgets('시간을 누르면 칩이 20·30·60분으로 바뀌고 30분이 골라진다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('시간'));
      await settle(tester);
      for (final label in ['20분', '30분', '60분']) {
        expect(chip(label), findsOneWidget, reason: label);
      }
      expect(chip('3km'), findsNothing);
      expect(chipColor(tester, '시간'), primary(tester));
      expect(chipColor(tester, '30분'), primary(tester));
      expect(chipColor(tester, '20분'), isNot(primary(tester)));
      expect(wheel(tester).selectedItem, 3); // 15,20,25,30
      await confirm(tester);
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 30))]);
    });

    testWidgets('거리로 되돌리면 3km 가 골라진다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('시간'));
      await settle(tester);
      await tester.tap(chip('거리'));
      await settle(tester);
      expect(chipColor(tester, '3km'), primary(tester));
      expect(chip('20분'), findsNothing);
      expect(wheelCount(tester), 40);
      expect(wheel(tester).selectedItem, 0);
    });

    testWidgets('확인 없이 시트를 닫으면 목표가 그대로다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c, repo: FakeRepo((0, 0))..lastGoalM = 5000);
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('시간'));
      await settle(tester);
      await tester.tap(chip('60분'));
      await settle(tester);
      // 시트 밖(위쪽 어두운 막)을 눌러 닫는다.
      await tester.tapAt(const Offset(10, 10));
      await settle(tester);
      expect(find.byType(CupertinoPicker), findsNothing);
      expect(rowText('5km'), findsOneWidget);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(5000)]);
    });

    testWidgets('지난 목표 45분이면 시트가 시간·45분으로 열린다', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))
          ..lastRunGoal = const TimeGoal(Duration(minutes: 45)),
      );
      await settle(tester);
      await openSheet(tester);
      expect(chipColor(tester, '시간'), primary(tester));
      expect(chipColor(tester, '거리'), isNot(primary(tester)));
      for (final label in ['20분', '30분', '60분']) {
        expect(chipColor(tester, label), isNot(primary(tester)));
      }
      expect(wheel(tester).selectedItem, 6);
    });

    testWidgets('5분 단위가 아닌 지난 목표(47분)도 휠에 있어 확인하면 그대로다', (tester) async {
      final c = FakeController();
      await pumpHome(
        tester,
        c,
        repo: FakeRepo((0, 0))
          ..lastRunGoal = const TimeGoal(Duration(minutes: 47)),
      );
      await settle(tester);
      expect(rowText('47분'), findsOneWidget);
      await openSheet(tester);
      expect(wheelCount(tester), 35);
      expect(wheel(tester).selectedItem, 7); // 15…45, 47
      await confirm(tester);
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 47))]);
    });

    testWidgets('러닝이 끝나 돌아오면 최근 목표를 다시 보인다', (tester) async {
      final repo = FakeRepo((0, 0))..lastGoalM = 5000;
      await pumpHome(tester, FakeController(), repo: repo);
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('시간'));
      await settle(tester);
      await tester.tap(chip('20분'));
      await settle(tester);
      await confirm(tester);
      await startAndWait(tester);
      repo.lastRunGoal = const TimeGoal(Duration(minutes: 20));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      expect(rowText('20분'), findsOneWidget);
    });

    testWidgets('시트의 칩은 높이 48 이상이고 버튼·선택 상태로 읽힌다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await openSheet(tester);
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.bySemanticsLabel('목표 3km'));
      expect(node.flagsCollection.isSelected, isNotNull);
      for (final label in ['목표 종류 거리', '목표 종류 시간', '목표 5km', '목표 10km']) {
        expect(
          tester.getSize(find.bySemanticsLabel(label)).height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('애니메이션 줄이기면 칩을 누르는 즉시 휠이 그 값에 선다', (tester) async {
      await pumpHome(tester, FakeController(), reduceMotion: true);
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('10km'));
      await tester.pump();
      expect(wheel(tester).selectedItem, 7);
      expect(chipColor(tester, '10km'), primary(tester));
    });

    testWidgets('칩을 빠르게 연달아 누르면 도는 동안에도 마지막 칩이 골라져 있다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await openSheet(tester);
      await tester.tap(chip('10km'));
      await tester.pump();
      await tester.pump(Motion.enter ~/ 2); // 휠이 3km 와 10km 사이
      expect(wheel(tester).selectedItem, inExclusiveRange(0, 7));
      await tester.tap(chip('3km'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(chipColor(tester, '3km'), primary(tester), reason: '$i');
      }
      await settle(tester);
      expect(wheel(tester).selectedItem, 0);
      expect(chipColor(tester, '3km'), primary(tester));
      await confirm(tester);
      expect(rowText('3km'), findsOneWidget);
    });

    testWidgets('휠은 "목표 값" 으로 지금 값을 읽히고 늘리기·줄이기로 한 칸씩 움직인다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await openSheet(tester);
      final handle = tester.ensureSemantics();
      final node = find.bySemanticsLabel('목표 값');
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: '목표 값',
          value: '3km',
          increasedValue: '4km',
          hasIncreaseAction: true,
        ),
      );
      final wheelNode = find.semantics.byLabel('목표 값');
      tester.semantics.increase(wheelNode);
      await settle(tester);
      tester.semantics.increase(wheelNode);
      await settle(tester);
      expect(wheel(tester).selectedItem, 2);
      expect(
        tester.getSemantics(node),
        matchesSemantics(
          label: '목표 값',
          value: '5km',
          increasedValue: '6km',
          decreasedValue: '4km',
          hasIncreaseAction: true,
          hasDecreaseAction: true,
        ),
      );
      tester.semantics.decrease(wheelNode);
      await settle(tester);
      expect(wheel(tester).selectedItem, 1);
      handle.dispose();
      await confirm(tester);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(4000)]);
    });

    testWidgets('휠 끝 칸에서는 더 늘릴 수 없다(42km)', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))..lastGoalM = 42000,
      );
      await settle(tester);
      await openSheet(tester);
      final handle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.bySemanticsLabel('목표 값')),
        matchesSemantics(
          label: '목표 값',
          value: '42km',
          decreasedValue: '41km',
          hasDecreaseAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('읽는 동안에도 선택 영역과 시작 버튼 자리가 같다', (tester) async {
      final repo = FakeRepo((0, 0))
        ..lastGoalM = 5000
        ..holdLastGoal = Completer<void>();
      await pumpHome(tester, FakeController(), repo: repo);
      await settle(tester);
      final picker = tester.getRect(row);
      final button = tester.getRect(find.byType(AppButton));
      repo.holdLastGoal!.complete();
      await settle(tester);
      expect(tester.getRect(row), picker);
      expect(tester.getRect(find.byType(AppButton)), button);
    });

    /// 360×640 글자 1.3배 화면에 [goal] 이 지난 목표인 홈을 그린다.
    Future<void> pumpSmall(
      WidgetTester tester, {
      required RunGoal goal,
      required bool dark,
    }) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runControllerProvider.overrideWith(() => FakeController()),
            permissionGateProvider.overrideWithValue(
              FakeGate(GateResult.ready),
            ),
            runRepositoryProvider.overrideWithValue(
              FakeRepo((0, 0))..lastRunGoal = goal,
            ),
            growthServiceProvider.overrideWithValue(
              FakeGrowthService(growthState()),
            ),
            clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
          ],
          child: MaterialApp(
            theme: dark ? appDarkTheme() : appLightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await settle(tester);
    }

    for (final dark in [false, true]) {
      final name = dark ? '다크' : '라이트';
      for (final (goal, label) in [
        (const DistanceGoal(42000), '42km'),
        (const TimeGoal(Duration(minutes: 180)), '180분'),
      ]) {
        testWidgets('$label 줄이 360×640 글자 1.3배 $name 에서 넘침 없이 그려진다', (
          tester,
        ) async {
          await pumpSmall(tester, goal: goal, dark: dark);
          expect(tester.takeException(), isNull);
          expect(rowText(label), findsOneWidget);
          expect(find.text('시작'), findsOneWidget);
        });
      }

      testWidgets('시트가 360×640 글자 1.3배 $name 에서 넘침 없이 열리고 확인을 누를 수 있다', (
        tester,
      ) async {
        await pumpSmall(
          tester,
          goal: const TimeGoal(Duration(minutes: 45)),
          dark: dark,
        );
        await tester.ensureVisible(row);
        await settle(tester);
        await openSheet(tester);
        expect(tester.takeException(), isNull);
        for (final label in ['거리', '시간', '20분', '30분', '60분']) {
          expect(chip(label), findsOneWidget, reason: label);
        }
        final ok = find.widgetWithText(AppButton, '확인');
        await tester.ensureVisible(ok);
        await settle(tester);
        expect(tester.getRect(ok).bottom, lessThanOrEqualTo(640));
        await tester.tap(chip('60분'));
        await settle(tester);
        await tester.ensureVisible(ok);
        await settle(tester);
        await tester.tap(ok);
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(CupertinoPicker), findsNothing);
        expect(rowText('60분'), findsOneWidget);
      });
    }
  });

  group('goalWheelValues', () {
    test('거리는 3~42km 1km 단위 40칸', () {
      final values = goalWheelValues(const DistanceGoal(5000));
      expect(values.length, 40);
      expect(values.first, const DistanceGoal(3000));
      expect(values.last, const DistanceGoal(42000));
      expect(values[1], const DistanceGoal(4000));
    });

    test('시간은 15~180분 5분 단위 34칸', () {
      final values = goalWheelValues(const TimeGoal(Duration(minutes: 30)));
      expect(values.length, 34);
      expect(values.first, const TimeGoal(Duration(minutes: 15)));
      expect(values.last, const TimeGoal(Duration(minutes: 180)));
      expect(values[1], const TimeGoal(Duration(minutes: 20)));
    });

    test('칸에 없는 지금 값은 순서에 맞게 끼워 넣는다', () {
      final time = goalWheelValues(const TimeGoal(Duration(minutes: 47)));
      expect(time.length, 35);
      expect(time.indexOf(const TimeGoal(Duration(minutes: 47))), 7);
      final km = goalWheelValues(const DistanceGoal(3500));
      expect(km.length, 41);
      expect(km.indexOf(const DistanceGoal(3500)), 1);
    });
  });
}
