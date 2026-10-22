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
  const bar = Color(0xFFF97316);
  const fast = Color(0xFF9A3412);
  PaceLayout layout(List<Split> sp, double? avg) => layoutPaceBars(
    splits: sp,
    avgPaceSecPerKm: avg,
    plotH: 100,
    barColor: bar,
    fastColor: fast,
  );

  test('이 러닝의 가장 느린 구간은 35%, 가장 빠른 구간은 100%, 사이는 속도에 비례', () {
    final l = layout([_s(1, 300), _s(2, 360), _s(3, 450)], 360);
    // 속도 1/360 은 1/450~1/300 사이 정확히 가운데: 35 + 65 × 0.5.
    expect(l.bars[0].height, closeTo(100, 1e-9));
    expect(l.bars[1].height, closeTo(67.5, 1e-9));
    expect(l.bars[2].height, closeTo(35, 1e-9));
  });

  test('6\'02"~6\'15" 처럼 비슷한 구간도 높이 차이가 눈에 띈다', () {
    final l = layout([_s(1, 375), _s(2, 369), _s(3, 362)], 368);
    expect(l.bars[0].height, closeTo(35, 1e-9));
    expect(l.bars[2].height, closeTo(100, 1e-9));
    // 1/369 는 1/375~1/362 의 (1/369-1/375)/(1/362-1/375) 지점.
    final t = (1 / 369 - 1 / 375) / (1 / 362 - 1 / 375);
    expect(l.bars[1].height, closeTo(35 + 65 * t, 1e-9));
  });

  test('평균선 y 는 같은 눈금으로 막대 사이에 놓인다', () {
    final l = layout([_s(1, 300), _s(2, 450)], 360);
    // 평균 360 → 높이 67.5 → y = 100 - 67.5.
    expect(l.avgLineY, closeTo(32.5, 1e-9));
    expect(l.avgLineY, greaterThan(100 - l.bars[0].height));
    expect(l.avgLineY, lessThan(100 - l.bars[1].height));
    expect(layout([_s(1, 300), _s(2, 450)], null).avgLineY, isNull);
    // 평균이 범위 밖이면 막대 범위 끝(0·35%)에 붙는다.
    expect(layout([_s(1, 300), _s(2, 450)], 200).avgLineY, closeTo(0, 1e-9));
    expect(layout([_s(1, 300), _s(2, 450)], 600).avgLineY, closeTo(65, 1e-9));
  });

  test('구간이 1개거나 모두 같으면(1초 미만 차이) 모두 꽉 찬 같은 높이', () {
    expect(layout([_s(1, 360)], 360).bars.single.height, 100);
    final same = layout([_s(1, 360), _s(2, 360), _s(3, 180, 500)], 360);
    expect(same.bars.map((b) => b.height), everyElement(100));
    expect(same.avgLineY, closeTo(0, 1e-9));
  });

  test('빠른 이동 구간은 범위에서 빼고 가장 긴 막대(100%)로 그린다', () {
    final l = layout([_s(1, 300), _s(2, 140), _s(3, 450)], 360);
    expect(l.bars[0].height, closeTo(100, 1e-9));
    expect(l.bars[1].height, closeTo(100, 1e-9));
    expect(l.bars[1].color, fast);
    expect(l.bars[2].height, closeTo(35, 1e-9));
  });

  test('마지막 짧은 구간은 알파 0.4, 빠른 구간은 inkMuted', () {
    final l = layout([_s(1, 300), _s(2, 140), _s(3, 150, 500)], 300);
    expect(l.bars[0].color, bar);
    expect(l.bars[1].color, fast);
    expect(l.bars[2].color.a, closeTo(0.4, 0.01));
    expect(l.bars[2].color.toARGB32() & 0xFFFFFF, bar.toARGB32() & 0xFFFFFF);
  });

  test('시간 0 구간은 최소 높이의 muted 막대로 그리고 다른 막대를 줄이지 않는다', () {
    final l = layout([_s(1, 300), _s(2, 0)], 300);
    expect(l.bars[1].height, 3);
    expect(l.bars[1].color, fast);
    expect(l.bars[0].height, 100);
  });

  test('라벨은 칸이 좁으면 건너뛴다', () {
    expect(paceLabelStep(100, 10), 1);
    expect(paceLabelStep(360 / 21, 20), greaterThan(1));
  });

  testWidgets('구간 21개, 글자 1.3배에서도 오류 없음', (tester) async {
    await _pump(tester, [for (var i = 1; i <= 21; i++) _s(i, 360)], scale: 1.3);
    expect(_painter(tester)!.splits, hasLength(21));
    expect(tester.takeException(), isNull);
  });

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

  for (final dark in [false, true]) {
    testWidgets(
      '막대는 primary-deep, 빠른 구간 ink-muted, 평균선 ink (${dark ? '다크' : '라이트'})',
      (tester) async {
        await _pump(tester, [_s(1, 385), _s(2, 390)], dark: dark);
        final c = dark ? AppColors.dark : AppColors.light;
        final p = _painter(tester)!;
        expect(p.barColor, c.primaryDeep);
        expect(p.fastColor, c.inkMuted);
        expect(p.lineColor, c.ink);
        expect(p.lineGapColor, c.surface);
      },
    );
  }

  test('splitLabel: 온전한 구간은 번호, 마지막 짧은 구간은 누적 거리', () {
    final sp = [_s(1, 360), _s(2, 360), _s(3, 90, 240)];
    expect([for (var i = 0; i < 3; i++) splitLabel(sp, i)], ['1', '2', '2.24']);
    expect(splitLabel([_s(1, 360), _s(2, 180, 500)], 1), '1.5');
  });

  test('막대 폭: 칸에서 사이 간격(최대 12, 칸의 30%)을 뺀다', () {
    expect(paceBarWidth(50), 38);
    expect(paceBarWidth(10), closeTo(7, 1e-9));
  });

  testWidgets('그래프 아래 라벨은 표와 같은 이름(마지막 짧은 구간은 누적 거리)', (tester) async {
    await _pump(tester, [_s(1, 360), _s(2, 360), _s(3, 90, 240)]);
    expect(_painter(tester)!.labels, ['1', '2', '2.24']);
  });
}
