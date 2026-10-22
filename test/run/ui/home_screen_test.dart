import 'dart:async';

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
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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
    expect(find.text('Lv.3 에서 Lv.4 로'), findsOneWidget);
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

  testWidgets('무대 안에 레벨 막대가 하나 있다', (tester) async {
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
    /// 선택된 칩은 primary 바탕이다.
    Color? chipColor(WidgetTester tester, String label) {
      final chip = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (chip.decoration! as BoxDecoration).color;
    }

    Future<void> startAndWait(WidgetTester tester) async {
      await tester.tap(find.text('시작'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
    }

    testWidgets('러닝이 없으면 3km 가 골라져 있다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '3km'), primary);
      expect(chipColor(tester, '5km'), isNot(primary));
      expect(find.text('오늘 목표'), findsOneWidget);
      expect(find.text('직접'), findsOneWidget);
    });

    testWidgets('최근 러닝 목표가 5km 면 5km 가 골라져 있다', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))..lastGoalM = 5000,
      );
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '5km'), primary);
      expect(chipColor(tester, '3km'), isNot(primary));
    });

    testWidgets('최근 목표가 12km 면 직접 칩이 12km 를 보인다', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))..lastGoalM = 12000,
      );
      await settle(tester);
      expect(find.text('12km'), findsOneWidget);
      expect(find.text('직접'), findsNothing);
    });

    testWidgets('10km 를 누르고 시작하면 그 목표로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await tester.tap(find.text('10km'));
      await tester.pump();
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(10000)]);
    });

    testWidgets('고르지 않고 시작하면 기본 3km 로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(3000)]);
    });

    testWidgets('직접 입력 12 → 12km 로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await tester.tap(find.text('직접'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '12');
      await tester.pump();
      await tester.tap(find.text('저장'));
      await settle(tester);
      expect(find.text('12km'), findsOneWidget);
      await startAndWait(tester);
      expect(c.startGoals, [DistanceGoal(12000)]);
    });

    for (final text in ['2', '43', '']) {
      testWidgets('직접 입력 "$text" 는 저장할 수 없다', (tester) async {
        await pumpHome(tester, FakeController());
        await settle(tester);
        await tester.tap(find.text('직접'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '저장'),
        );
        expect(save.onPressed, isNull);
        expect(find.textContaining('3~42km'), findsWidgets);
      });
    }

    testWidgets('러닝이 끝나 돌아오면 최근 목표를 다시 보인다', (tester) async {
      final repo = FakeRepo((0, 0))..lastGoalM = 5000;
      await pumpHome(tester, FakeController(), repo: repo);
      await settle(tester);
      await tester.tap(find.text('10km'));
      await tester.pump();
      await startAndWait(tester);
      repo.lastGoalM = 10000;
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '10km'), primary);
    });

    testWidgets('시간을 누르면 칩이 20분·30분·60분·직접으로 바뀌고 30분이 골라진다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      expect(find.text('20분'), findsNothing);
      await tester.tap(find.text('시간'));
      await settle(tester);
      for (final label in ['20분', '30분', '60분', '직접']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('3km'), findsNothing);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '30분'), primary);
      expect(chipColor(tester, '20분'), isNot(primary));
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 30))]);
    });

    testWidgets('거리로 되돌리면 3km 가 골라진다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await tester.tap(find.text('시간'));
      await settle(tester);
      await tester.tap(find.text('거리'));
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '3km'), primary);
      expect(find.text('20분'), findsNothing);
    });

    testWidgets('60분을 누르고 시작하면 시간 목표 60분으로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await tester.tap(find.text('시간'));
      await settle(tester);
      await tester.tap(find.text('60분'));
      await tester.pump();
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 60))]);
    });

    testWidgets('지난번 목표가 시간 20분이면 시간 선택과 20분 칩이 골라져 있다', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))
          ..lastRunGoal = const TimeGoal(Duration(minutes: 20)),
      );
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '20분'), primary);
      expect(chipColor(tester, '시간'), primary);
      expect(chipColor(tester, '거리'), isNot(primary));
    });

    testWidgets('지난번 시간 목표가 45분이면 직접 칩이 45분을 보인다', (tester) async {
      await pumpHome(
        tester,
        FakeController(),
        repo: FakeRepo((0, 0))
          ..lastRunGoal = const TimeGoal(Duration(minutes: 45)),
      );
      await settle(tester);
      expect(find.text('45분'), findsOneWidget);
      expect(find.text('직접'), findsNothing);
    });

    testWidgets('시간 직접 입력 45 → 45분으로 시작한다', (tester) async {
      final c = FakeController();
      await pumpHome(tester, c);
      await settle(tester);
      await tester.tap(find.text('시간'));
      await settle(tester);
      await tester.tap(find.text('직접'));
      await settle(tester);
      await tester.enterText(find.byType(TextField), '45');
      await tester.pump();
      await tester.tap(find.text('저장'));
      await settle(tester);
      expect(find.text('45분'), findsOneWidget);
      await startAndWait(tester);
      expect(c.startGoals, [const TimeGoal(Duration(minutes: 45))]);
    });

    for (final (text, ok) in [
      ('14', false),
      ('181', false),
      ('', false),
      ('15', true),
      ('180', true),
    ]) {
      testWidgets('시간 직접 입력 "$text" ${ok ? '는 저장할 수 있다' : '는 저장할 수 없다'}', (
        tester,
      ) async {
        await pumpHome(tester, FakeController());
        await settle(tester);
        await tester.tap(find.text('시간'));
        await settle(tester);
        await tester.tap(find.text('직접'));
        await settle(tester);
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '저장'),
        );
        expect(save.onPressed == null, !ok);
        expect(
          find.text('15~180분 사이 정수로 입력해 주세요'),
          ok ? findsNothing : findsWidgets,
        );
      });
    }

    testWidgets('러닝이 끝나 돌아오면 지난번 시간 목표를 다시 보인다', (tester) async {
      final repo = FakeRepo((0, 0))..lastGoalM = 5000;
      await pumpHome(tester, FakeController(), repo: repo);
      await settle(tester);
      await tester.tap(find.text('시간'));
      await settle(tester);
      await tester.tap(find.text('20분'));
      await tester.pump();
      await startAndWait(tester);
      repo.lastRunGoal = const TimeGoal(Duration(minutes: 20));
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await settle(tester);
      final primary = AppColors.of(
        tester.element(find.byType(HomeScreen)),
      ).primary;
      expect(chipColor(tester, '20분'), primary);
    });

    testWidgets('거리·시간 선택과 시간 칩도 높이 48 이상이다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      await tester.tap(find.text('시간'));
      await settle(tester);
      final handle = tester.ensureSemantics();
      for (final label in ['목표 종류 거리', '목표 종류 시간', '목표 20분', '목표 직접 입력']) {
        expect(
          tester.getSize(find.bySemanticsLabel(label)).height,
          greaterThanOrEqualTo(48),
          reason: label,
        );
      }
      handle.dispose();
    });

    testWidgets('칩은 높이 48 이상이고 버튼·선택 상태로 읽힌다', (tester) async {
      await pumpHome(tester, FakeController());
      await settle(tester);
      final handle = tester.ensureSemantics();
      final node = tester.getSemantics(find.bySemanticsLabel('목표 3km'));
      expect(node.flagsCollection.isSelected, isNotNull);
      expect(
        tester.getSize(find.bySemanticsLabel('목표 5km')).height,
        greaterThanOrEqualTo(48),
      );
      handle.dispose();
    });

    testWidgets('읽는 동안에도 선택 영역과 시작 버튼 자리가 같다', (tester) async {
      final repo = FakeRepo((0, 0))
        ..lastGoalM = 5000
        ..holdLastGoal = Completer<void>();
      await pumpHome(tester, FakeController(), repo: repo);
      await settle(tester);
      final picker = tester.getRect(find.byType(RunGoalPicker));
      final button = tester.getRect(find.byType(AppButton));
      repo.holdLastGoal!.complete();
      await settle(tester);
      expect(tester.getRect(find.byType(RunGoalPicker)), picker);
      expect(tester.getRect(find.byType(AppButton)), button);
    });

    for (final dark in [false, true]) {
      testWidgets('360×640 글자 1.3배 ${dark ? '다크' : '라이트'} 에서 넘침 없이 그려진다', (
        tester,
      ) async {
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
                FakeRepo((0, 0))..lastGoalM = 12000,
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
        expect(tester.takeException(), isNull);
        expect(find.text('12km'), findsOneWidget);
        expect(find.text('시작'), findsOneWidget);
      });

      testWidgets(
        '시간 목표도 360×640 글자 1.3배 ${dark ? '다크' : '라이트'} 에서 넘침 없이 그려진다',
        (tester) async {
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
                  FakeRepo((0, 0))
                    ..lastRunGoal = const TimeGoal(Duration(minutes: 45)),
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
          expect(tester.takeException(), isNull);
          expect(find.text('45분'), findsOneWidget);
          expect(find.text('시작'), findsOneWidget);
        },
      );
    }
  });
}
