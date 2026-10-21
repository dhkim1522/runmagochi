import 'package:flutter/material.dart' hide Split;
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/split_pace_chart.dart';

Split _s(int i, int sec, [double m = 1000]) => Split(
  index: i,
  distanceM: m,
  duration: Duration(seconds: sec),
);

Future<void> _pump(
  WidgetTester tester,
  List<Split> splits, {
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? appDarkTheme() : appLightTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: SplitPaceChart(splits: splits, avgPaceSecPerKm: 390),
      ),
    ),
  );
}

SplitPacePainter? _painter(WidgetTester tester) {
  final f = find.descendant(
    of: find.byType(SplitPaceChart),
    matching: find.byType(CustomPaint),
  );
  if (f.evaluate().isEmpty) return null;
  return tester.widget<CustomPaint>(f.first).painter as SplitPacePainter;
}

void main() {
  testWidgets('막대 수 = 구간 수, 마지막 짧은 구간도 포함', (tester) async {
    await _pump(tester, [_s(1, 385), _s(2, 390), _s(3, 200, 500)]);
    expect(_painter(tester)!.splits, hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('구간 0·1개면 숨김', (tester) async {
    await _pump(tester, const []);
    expect(_painter(tester), isNull);
    await _pump(tester, [_s(1, 385)]);
    expect(_painter(tester), isNull);
  });

  testWidgets('360×640·글자 1.3배·다크 테마에서 오류 없음', (tester) async {
    await _pump(
      tester,
      [for (var i = 1; i <= 12; i++) _s(i, 360 + i * 5)],
      dark: true,
      scale: 1.3,
    );
    expect(_painter(tester)!.splits, hasLength(12));
    expect(tester.takeException(), isNull);
  });

  test('isFastSplit: 150초/km 미만의 온전한 구간만', () {
    expect(isFastSplit(_s(1, 140)), isTrue);
    expect(isFastSplit(_s(1, 300)), isFalse);
    expect(isFastSplit(_s(2, 50, 500)), isFalse);
  });
}
