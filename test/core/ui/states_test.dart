import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/app/providers.dart';
import 'package:runmagochi/achievement/ui/achievement_screen.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/core/korean.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/data/run_repository.dart';
import 'package:runmagochi/run/domain/run_engine.dart';
import 'package:runmagochi/run/ui/history_screen.dart';
import 'package:runmagochi/run/ui/in_run_screen.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';
import 'package:runmagochi/shop/ui/coin_history_screen.dart';

import '../../run/ui/fakes.dart';

// 작업 15: 빈 상태·오류 표시가 화면마다 같은 컴포넌트(EmptyState·NoticeCard)를 쓴다.

class _FailingRepo extends FakeRepo {
  _FailingRepo() : super((0, 0));

  @override
  Future<List<RunListItem>> listRuns() async => throw StateError('읽기 실패');
}

class _FailingShop extends FakeShop {
  _FailingShop() : super(const [], 0);

  @override
  Future<List<CoinEntry>> coinHistory() async => throw StateError('읽기 실패');
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  bool dark = false,
  double scale = 1,
  Size size = const Size(360, 640),
  FakeRepo? repo,
  FakeShop? shop,
  FakeController? controller,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(repo ?? FakeRepo((0, 0))),
        runControllerProvider.overrideWith(
          () => controller ?? FakeController(),
        ),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 17)),
        growthServiceProvider.overrideWithValue(
          FakeGrowthService(growthState()),
        ),
        shopRepositoryProvider.overrideWithValue(shop ?? FakeShop()),
        ...overrides,
      ],
      child: MaterialApp(
        theme: dark ? appDarkTheme() : appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// [message] 가 [EmptyState.error] 카드(inkMuted 느낌표) 안에 있다.
void _expectErrorState(WidgetTester tester, String message, AppColors c) {
  final state = find.ancestor(
    of: find.text(message),
    matching: find.byType(EmptyState),
  );
  expect(state, findsOneWidget, reason: message);
  final icon = tester.widget<Icon>(
    find.descendant(of: state, matching: find.byType(Icon)),
  );
  expect(icon.icon, Icons.error_outline_rounded);
  expect(icon.color, c.inkMuted);
}

void main() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;

    testWidgets('기록 목록을 읽지 못하면 오류 카드 ($name)', (tester) async {
      await _pump(
        tester,
        const Scaffold(body: HistoryScreen()),
        dark: dark,
        scale: 1.3,
        repo: _FailingRepo(),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(find.text('기록을 불러오지 못했어요'), 200);
      _expectErrorState(tester, '기록을 불러오지 못했어요', c);
    });

    testWidgets('코인 내역을 읽지 못하면 오류 카드 ($name)', (tester) async {
      await _pump(
        tester,
        const CoinHistoryScreen(),
        dark: dark,
        scale: 1.3,
        shop: _FailingShop(),
      );
      expect(tester.takeException(), isNull);
      _expectErrorState(tester, '내역을 불러오지 못했어요', c);
    });

    testWidgets('업적을 읽지 못하면 오류 카드 ($name)', (tester) async {
      await _pump(
        tester,
        const AchievementScreen(),
        dark: dark,
        overrides: [
          achievementRunsProvider.overrideWith(
            (ref) async => throw StateError('읽기 실패'),
          ),
          earnedBadgesProvider.overrideWith((ref) async => const []),
        ],
      );
      expect(tester.takeException(), isNull);
      _expectErrorState(tester, '업적을 불러오지 못했어요', c);
    });

    testWidgets('없는 기록 상세는 오류 카드 ($name)', (tester) async {
      await _pump(tester, const SummaryScreen.forRun('none'), dark: dark);
      expect(tester.takeException(), isNull);
      _expectErrorState(tester, '기록을 찾을 수 없어요', c);
    });

    testWidgets('위치 신호 오류는 NoticeCard, 360×640 글자 1.3배에서 넘치지 않는다 ($name)', (
      tester,
    ) async {
      await _pump(
        tester,
        const InRunScreen(),
        dark: dark,
        scale: 1.3,
        controller: FakeController(
          initial: snap(RunState.recording, distanceM: 2910, avg: 362),
          error: '위치 신호를 받지 못하고 있어요',
          initialGoalM: 5000,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.ancestor(
          of: find.text(keepAll('위치 신호를 받지 못하고 있어요')),
          matching: find.byType(NoticeCard),
        ),
        findsOneWidget,
      );
    });
  }
}
