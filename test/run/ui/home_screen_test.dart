import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/avatar/ui/avatar_view.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';
import 'package:runmagochi/run/ui/permission_screen.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';

import 'fakes.dart';

Future<void> pumpHome(
  WidgetTester tester,
  FakeController controller, {
  FakeGate? gate,
  FakeRepo? repo,
  FakeGrowthService? growth,
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
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
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
  testWidgets('아바타·레벨·주간 목표가 보인다', (tester) async {
    await pumpHome(
      tester,
      FakeController(),
      growth: FakeGrowthService(growthState(streakWeeks: 2)),
    );
    await tester.pump();
    expect(
      tester.widget<AvatarView>(find.byType(AvatarView)).action,
      AvatarAction.idle,
    );
    expect(find.text('이번 주 목표 10km'), findsOneWidget);
    expect(find.text('6.20km 달성'), findsOneWidget);
    expect(find.text('2주 연속 달성'), findsOneWidget);
    expect(find.text('러니 Lv.3'), findsOneWidget);
    // 150 - 58 = 92 → 9.2km
    expect(find.text('다음 레벨까지 9.2km'), findsOneWidget);
  });

  testWidgets('목표를 15km 로 바꾸면 setWeeklyTarget(15000) 이 불리고 다시 읽는다', (
    tester,
  ) async {
    final g = FakeGrowthService(growthState());
    await pumpHome(tester, FakeController(), growth: g);
    await tester.pump();
    final before = g.loads;
    await tester.tap(find.text('이번 주 목표 10km'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await settle(tester);
    expect(g.targets, [15000]);
    expect(g.loads, greaterThan(before));
  });

  Future<void> changeTarget(WidgetTester tester) async {
    await tester.tap(find.text('이번 주 목표 10km'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '5');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await settle(tester);
  }

  testWidgets('목표를 낮춰 보너스만 받으면 스낵바로 알린다', (tester) async {
    final g = FakeGrowthService(growthState())
      ..targetGain = const GrowthGain(
        distanceXp: 0,
        goalBonusXp: 50,
        levelBefore: 3,
        levelAfter: 3,
        stageBefore: 1,
        stageAfter: 1,
      );
    await pumpHome(tester, FakeController(), growth: g);
    await changeTarget(tester);
    expect(find.text('이번 주 목표 달성 · 경험치 +50'), findsOneWidget);
    expect(find.text('레벨 업!'), findsNothing);
  });

  testWidgets('목표를 낮춰 레벨이 오르면 레벨 업 다이얼로그', (tester) async {
    final g = FakeGrowthService(growthState())
      ..targetGain = const GrowthGain(
        distanceXp: 0,
        goalBonusXp: 50,
        levelBefore: 4,
        levelAfter: 5,
        stageBefore: 1,
        stageAfter: 2,
      );
    await pumpHome(tester, FakeController(), growth: g);
    await changeTarget(tester);
    expect(find.text('레벨 업!'), findsOneWidget);
    expect(find.text('Lv.4 에서 Lv.5 로'), findsOneWidget);
    expect(find.text('새 외형 단계!'), findsOneWidget);
    await tester.tap(find.text('확인'));
    await settle(tester);
    expect(find.text('레벨 업!'), findsNothing);
  });

  testWidgets('목표 보너스 없이 밀린 러닝 경험치로 레벨이 올라도 다이얼로그', (tester) async {
    final g = FakeGrowthService(growthState())
      ..targetGain = const GrowthGain(
        distanceXp: 30,
        goalBonusXp: 0,
        levelBefore: 1,
        levelAfter: 2,
        stageBefore: 1,
        stageAfter: 1,
      );
    await pumpHome(tester, FakeController(), growth: g);
    await changeTarget(tester);
    expect(find.text('레벨 업!'), findsOneWidget);
    expect(find.text('Lv.1 에서 Lv.2 로'), findsOneWidget);
    expect(find.text('새 외형 단계!'), findsNothing);
  });

  testWidgets('보상이 없으면 아무것도 띄우지 않는다', (tester) async {
    final g = FakeGrowthService(growthState());
    await pumpHome(tester, FakeController(), growth: g);
    await changeTarget(tester);
    expect(g.targets, [5000]);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('레벨 업!'), findsNothing);
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
    await pumpHome(tester, FakeController(), growth: g);
    await tester.pump();
    expect(find.text('러니 Lv.3'), findsOneWidget);

    g.holdLoad = Completer<void>();
    await tester.tap(find.text('이번 주 목표 10km'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await settle(tester);
    // load 가 아직 끝나지 않았다.
    expect(find.text('러니 Lv.3'), findsOneWidget);
    expect(find.text('이번 주 목표 10km'), findsOneWidget);
    expect(find.text('이번 주 -'), findsNothing);

    g.holdLoad!.complete();
    await settle(tester);
    expect(find.text('러니 Lv.3'), findsOneWidget);
  });

  testWidgets('복구 다이얼로그에서 종료하고 저장은 end 후 홈에 남는다', (tester) async {
    final g = FakeGrowthService(growthState(weekDistanceM: 1000));
    final c = FakeController(restore: true);
    await pumpHome(tester, c, growth: g);
    await settle(tester);
    expect(find.text('1.00km 달성'), findsOneWidget);
    final before = g.loads;
    g.state = growthState(weekDistanceM: 7000);
    await tester.tap(find.text('종료하고 저장'));
    await settle(tester);
    expect(c.calls, ['restore', 'end']);
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.text('7.00km 달성'), findsOneWidget);
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
    final growth = FakeGrowthService(growthState(weekDistanceM: 1000));
    final c = FakeController();
    await pumpHome(tester, c, growth: growth);
    expect(find.text('1.00km 달성'), findsOneWidget);

    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    await tester.tap(find.text('일시정지'));
    await tester.pump();

    growth.state = growthState(weekDistanceM: 4230);
    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
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
    expect(find.text('4.23km 달성'), findsOneWidget);
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
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '시작'),
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
    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
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
    await pumpHome(tester, c, growth: g);
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
    expect(find.text('이번 주 목표 10km 달성 · 경험치 +50'), findsOneWidget);
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
}
