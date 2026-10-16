import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';
import 'package:runmagochi/run/ui/permission_screen.dart';

import 'fakes.dart';

Future<void> pumpHome(
  WidgetTester tester,
  FakeController controller, {
  FakeGate? gate,
  FakeRepo? repo,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(() => controller),
        permissionGateProvider.overrideWithValue(
          gate ?? FakeGate(GateResult.ready),
        ),
        runRepositoryProvider.overrideWithValue(repo ?? FakeRepo((0, 0))),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: const MaterialApp(home: Scaffold(body: HomeScreen())),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('이번 주 합계와 아바타 자리가 보인다', (tester) async {
    await pumpHome(tester, FakeController(), repo: FakeRepo((12340, 3)));
    expect(find.text('이번 주 12.34 km · 3회'), findsOneWidget);
    expect(find.text('아바타는 다음 업데이트에서 만나요'), findsOneWidget);
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
    await tester.pumpAndSettle();
    expect(c.calls, ['restore', 'start']);
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('일시정지'), findsOneWidget);
  });

  testWidgets('권한이 준비되지 않으면 권한 화면이 열리고 준비되면 카운트다운이 이어진다', (tester) async {
    final gate = FakeGate(GateResult.needsLocation);
    final c = FakeController();
    await pumpHome(tester, c, gate: gate);
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionScreen), findsOneWidget);
    expect(c.calls, ['restore']);

    gate.result = GateResult.ready;
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PermissionScreen), findsNothing);
    expect(find.text('3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(c.calls, ['restore', 'start']);
  });

  testWidgets('권한 화면을 그냥 닫으면 시작하지 않는다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c, gate: FakeGate(GateResult.locationDeniedForever));
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    expect(find.byType(PermissionScreen), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 4));
    expect(c.calls, ['restore']);
  });

  testWidgets('복구할 러닝이 있으면 다이얼로그 표시, 이어서 기록은 일시정지 화면', (tester) async {
    final c = FakeController(restore: true);
    await pumpHome(tester, c);
    await tester.pumpAndSettle();
    expect(find.text('기록 중이던 러닝이 있어요'), findsOneWidget);
    await tester.tap(find.text('이어서 기록'));
    await tester.pumpAndSettle();
    expect(find.byType(InRunScreen), findsOneWidget);
    expect(find.text('재개'), findsOneWidget);
    expect(c.calls, ['restore']);
  });

  testWidgets('복구 다이얼로그에서 종료하고 저장은 end 후 홈에 남는다', (tester) async {
    final c = FakeController(restore: true);
    await pumpHome(tester, c);
    await tester.pumpAndSettle();
    await tester.tap(find.text('종료하고 저장'));
    await tester.pumpAndSettle();
    expect(c.calls, ['restore', 'end']);
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.text('기록 중이던 러닝이 있어요'), findsNothing);
    expect(find.text('시작'), findsOneWidget);
  });

  testWidgets('복구할 러닝이 없으면 다이얼로그가 없고 restoreIfAny 는 한 번만 불린다', (tester) async {
    final c = FakeController();
    await pumpHome(tester, c);
    await tester.pumpAndSettle();
    expect(find.text('기록 중이던 러닝이 있어요'), findsNothing);
    expect(c.calls, ['restore']);
  });

  testWidgets('러닝이 끝나 홈으로 돌아오면 주간 합계를 다시 읽는다', (tester) async {
    final repo = FakeRepo((1000, 1));
    final c = FakeController();
    await pumpHome(tester, c, repo: repo);
    expect(find.text('이번 주 1.00 km · 1회'), findsOneWidget);

    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일시정지'));
    await tester.pump();

    repo.total = (4230, 2);
    final g = await tester.startGesture(tester.getCenter(find.text('종료')));
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(find.byType(InRunScreen), findsNothing);
    expect(find.text('이번 주 4.23 km · 2회'), findsOneWidget);
    expect(c.calls, ['restore', 'start', 'pause', 'end']);
    expect(c.state.snapshot.state, RunState.idle);
  });
}
