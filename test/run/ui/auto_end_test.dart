import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/app/run_controller.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/home_screen.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';

import 'fakes.dart';

final _summary = RunSummary(
  startedAt: DateTime(2026, 10, 17, 7),
  endedAt: DateTime(2026, 10, 17, 7, 30),
  distanceM: 3000,
  movingTime: const Duration(minutes: 18),
  avgPaceSecPerKm: 360,
  calories: 200,
  name: '토요일 아침 러닝',
  splits: const [],
  points: const [],
);

/// 자동 종료를 흉내 내는 컨트롤러.
class _AutoEndController extends FakeController {
  _AutoEndController({this.autoEndOnRestore = false});

  final bool autoEndOnRestore;

  void autoEnd() {
    state = RunViewState(
      snapshot: snap(RunState.idle),
      lastSummary: _summary,
      autoEnded: true,
    );
  }

  @override
  Future<bool> restoreIfAny() async {
    calls.add('restore');
    if (autoEndOnRestore) autoEnd();
    return false;
  }
}

Future<FakeGrowthService> _pumpHome(
  WidgetTester tester,
  _AutoEndController controller,
) async {
  final growth = FakeGrowthService(growthState());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runControllerProvider.overrideWith(() => controller),
        permissionGateProvider.overrideWithValue(FakeGate(GateResult.ready)),
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        growthServiceProvider.overrideWithValue(growth),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
        home: const Scaffold(body: HomeScreen()),
      ),
    ),
  );
  await tester.pump();
  return growth;
}

/// 아바타 티커는 멈추지 않아 pumpAndSettle 이 끝나지 않는다. 고정 시간만 흘린다.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('러닝 중 자동 종료되면 러닝 화면을 닫고 요약으로 간다', (tester) async {
    final c = _AutoEndController();
    final growth = await _pumpHome(tester, c);
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(find.byType(InRunScreen), findsOneWidget);
    final syncsBefore = growth.syncs;

    c.autoEnd();
    await _settle(tester);

    expect(find.byType(InRunScreen), findsNothing);
    final screen = tester.widget<SummaryScreen>(find.byType(SummaryScreen));
    expect(screen.summary, same(_summary));
    expect(growth.syncs, greaterThan(syncsBefore));
    expect(c.calls, ['restore', 'start']);
  });

  testWidgets('복원한 러닝이 자동 종료되면 묻지 않고 요약을 연다', (tester) async {
    final c = _AutoEndController(autoEndOnRestore: true);
    await _pumpHome(tester, c);
    await _settle(tester);

    expect(find.text('기록 중이던 러닝이 있어요'), findsNothing);
    final screen = tester.widget<SummaryScreen>(find.byType(SummaryScreen));
    expect(screen.summary, same(_summary));
    expect(c.calls, ['restore']);
  });
}
