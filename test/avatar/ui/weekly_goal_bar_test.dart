import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/ui/weekly_goal_bar.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';

Future<List<double>> _pump(
  WidgetTester tester, {
  double targetM = 10000,
  double distanceM = 6200,
  int streak = 0,
}) async {
  final changed = <double>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: appLightTheme(),
      home: Scaffold(
        body: WeeklyGoalBar(
          targetM: targetM,
          distanceM: distanceM,
          streakWeeks: streak,
          onChangeTarget: changed.add,
        ),
      ),
    ),
  );
  return changed;
}

FilledButton _save(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '저장'));

void main() {
  dialogTests();
  testWidgets('목표와 달성 거리, 진행 막대가 보인다', (tester) async {
    await _pump(tester);
    expect(find.text('이번 주 목표 10km'), findsOneWidget);
    expect(find.text('6.20km 달성'), findsOneWidget);
    final bar = tester.widget<ClayBar>(find.byType(ClayBar));
    expect(bar.value, closeTo(0.62, 1e-9));
  });

  testWidgets('목표가 소수면 끝의 0 없이 보이고 막대는 1을 넘지 않는다', (tester) async {
    await _pump(tester, targetM: 12500, distanceM: 20000);
    expect(find.text('이번 주 목표 12.5km'), findsOneWidget);
    final bar = tester.widget<ClayBar>(find.byType(ClayBar));
    expect(bar.value, 1.0);
  });

  testWidgets('연속 달성은 0이면 숨기고 1 이상이면 보인다', (tester) async {
    await _pump(tester);
    expect(find.textContaining('주 연속 달성'), findsNothing);
    await _pump(tester, streak: 3);
    expect(find.text('3주 연속 달성'), findsOneWidget);
  });

  testWidgets('탭하면 수정 창이 열리고 15 저장은 15000m 로 알린다', (tester) async {
    final changed = await _pump(tester);
    await tester.tap(find.text('이번 주 목표 10km'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(changed, [15000]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('소수 입력도 저장된다', (tester) async {
    final changed = await _pump(tester);
    await tester.tap(find.text('이번 주 목표 10km'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '12.5');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(changed, [12500]);
  });

  testWidgets('빈 값, 0, 3 미만, 200 초과면 저장 버튼이 꺼진다 (3~200km)', (tester) async {
    final changed = await _pump(tester);
    await tester.tap(find.text('이번 주 목표 10km'));
    await tester.pumpAndSettle();
    for (final bad in ['', '0', '1', '2', '2.9', '201', 'abc']) {
      await tester.enterText(find.byType(TextField), bad);
      await tester.pump();
      expect(_save(tester).onPressed, isNull, reason: '"$bad"');
    }
    for (final ok in ['3', '200']) {
      await tester.enterText(find.byType(TextField), ok);
      await tester.pump();
      expect(_save(tester).onPressed, isNotNull, reason: '"$ok"');
    }
    expect(changed, isEmpty);
  });

  testWidgets('취소하면 알리지 않는다', (tester) async {
    final changed = await _pump(tester);
    await tester.tap(find.text('이번 주 목표 10km'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(changed, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });
}

void dialogTests() {
  testWidgets('showWeeklyTargetDialog 는 지금 목표로 열리고 저장한 값을 미터로 돌려준다', (
    tester,
  ) async {
    double? result = -1;
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showWeeklyTargetDialog(context, 12500),
            child: const Text('열기'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.text('12.5'), findsOneWidget);
    expect(find.text('3~200'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '3');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(result, 3000);

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
