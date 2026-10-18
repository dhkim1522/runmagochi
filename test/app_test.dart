import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/app.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/run/app/providers.dart';

import 'run/ui/fakes.dart';

void main() {
  testWidgets('하단 탭 3개가 보인다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState(weekDistanceM: 0)),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    expect(find.text('러닝'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('아바타'), findsOneWidget);
    expect(find.text('0.00km 달성'), findsOneWidget);
  });

  testWidgets('탭을 누르면 화면이 바뀌고 선택 상태가 시맨틱에 드러난다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState(weekDistanceM: 0)),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    expect(
      tester.getSemantics(find.bySemanticsLabel('러닝')),
      matchesSemantics(
        label: '러닝',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasEnabledState: false,
      ),
    );
    final box = tester.getSize(
      find
          .ancestor(of: find.text('기록'), matching: find.byType(ConstrainedBox))
          .first,
    );
    expect(box.height, greaterThanOrEqualTo(48));
    await tester.tap(find.text('기록'));
    await tester.pump();
    expect(find.text('최근 러닝'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('탭에 키보드 포커스가 가고 포커스 표시가 보이며 Enter·Space 로 바뀐다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runControllerProvider.overrideWith(FakeController.new),
          runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
          growthServiceProvider.overrideWithValue(
            FakeGrowthService(growthState(weekDistanceM: 0)),
          ),
        ],
        child: const RunmagochiApp(),
      ),
    );
    await tester.pump();
    final ring = find.byKey(const ValueKey('tab-focus-ring'));
    expect(ring, findsNothing);

    // 탭 3개가 순서대로 포커스를 받는다.
    Future<void> tab() async {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }

    var found = false;
    for (var i = 0; i < 40 && !found; i++) {
      await tab();
      found = ring.evaluate().isNotEmpty;
    }
    expect(found, isTrue, reason: '탭 키로 하단 탭에 포커스가 간다');
    expect(ring, findsOneWidget);

    // 포커스가 러닝 탭에 있다면 다음(기록)으로 옮겨 Enter.
    await tab();
    expect(
      find.descendant(of: ring, matching: find.text('기록')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('최근 러닝'), findsOneWidget);

    await tab();
    expect(
      find.descendant(of: ring, matching: find.text('아바타')),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('최근 러닝'), findsNothing);
  });
}
