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

/// 자동 종료 저장이 실패한 뒤 사용자가 다시 끝내면 end 안에서 autoEnded 가 된다.
class _AutoEndOnEndController extends FakeController {
  @override
  Future<RunSummary> end() async {
    calls.add('end');
    autoEndState();
    return _summary;
  }

  void autoEndState() {
    state = RunViewState(
      snapshot: snap(RunState.idle),
      lastSummary: _summary,
      autoEnded: true,
    );
  }
}

/// 1km 미만이라 저장하지 않고 지운 상태를 흉내 내는 컨트롤러.
class _DiscardController extends FakeController {
  _DiscardController({super.restore, this.discardOnRestore = false});

  final bool discardOnRestore;

  void discard({bool auto = false}) {
    state = RunViewState(
      snapshot: snap(RunState.idle),
      autoEnded: auto,
      discardedShortRun: true,
    );
  }

  @override
  Future<RunSummary> end() async {
    calls.add('end');
    discard();
    return _summary;
  }

  @override
  Future<bool> restoreIfAny() async {
    if (discardOnRestore) {
      calls.add('restore');
      discard(auto: true);
      return false;
    }
    return super.restoreIfAny();
  }
}

class _PopCounter extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

Future<FakeGrowthService> _pumpHome(
  WidgetTester tester,
  FakeController controller, {
  NavigatorObserver? observer,
}) async {
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
        navigatorObservers: [?observer],
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

  testWidgets('직접 끝내는 중에 autoEnded 가 되어도 러닝 화면은 한 번만 닫힌다', (tester) async {
    final c = _AutoEndOnEndController();
    final pops = _PopCounter();
    await _pumpHome(tester, c, observer: pops);
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    await tester.tap(find.text('일시정지'));
    await tester.pump();

    final g = await tester.startGesture(
      tester.getCenter(find.text('길게 눌러 종료')),
    );
    await tester.pump(); // 첫 프레임에서 타이머가 시작된다.
    await tester.pump(const Duration(milliseconds: 1501));
    await tester.pump();
    await g.up();
    await _settle(tester);

    expect(pops.pops, 1);
    expect(find.byType(InRunScreen), findsNothing);
    final screen = tester.widget<SummaryScreen>(find.byType(SummaryScreen));
    expect(screen.summary, same(_summary));
    expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
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

  testWidgets('러닝 중 1km 미만으로 자동 종료되면 러닝 화면을 닫고 요약 없이 안내만 보인다', (tester) async {
    final c = _DiscardController();
    await _pumpHome(tester, c);
    await tester.tap(find.text('시작'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await _settle(tester);
    expect(find.byType(InRunScreen), findsOneWidget);

    c.discard(auto: true);
    await _settle(tester);

    expect(find.byType(InRunScreen), findsNothing);
    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('1km 미만은 기록하지 않아요'), findsOneWidget);
  });

  testWidgets('복원 때 바로 1km 미만으로 끝나면 요약 대신 안내를 보인다', (tester) async {
    final c = _DiscardController(discardOnRestore: true);
    await _pumpHome(tester, c);
    await _settle(tester);

    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('1km 미만은 기록하지 않아요'), findsOneWidget);
  });

  testWidgets('복구 다이얼로그의 종료하기가 1km 미만이면 안내를 보인다', (tester) async {
    final c = _DiscardController(restore: true);
    await _pumpHome(tester, c);
    await _settle(tester);
    await tester.tap(find.text('종료하기'));
    await _settle(tester);

    expect(c.calls, ['restore', 'end']);
    expect(find.byType(SummaryScreen), findsNothing);
    expect(find.text('1km 미만은 기록하지 않아요'), findsOneWidget);
  });
}
