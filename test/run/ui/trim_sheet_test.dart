import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';
import 'package:runmagochi/core/format.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/app/run_editor.dart';
import 'package:runmagochi/run/domain/location_sample.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/domain/run_trim.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';

import 'fakes.dart';

/// 10초마다 한 점, 6점(약 11m 간격). 끝은 마지막 점 30초 뒤.
RunSummary _summary() {
  final start = DateTime(2026, 10, 16, 17, 51);
  final points = [
    for (var i = 0; i < 6; i++)
      LocationSample(
        time: start.add(Duration(seconds: i * 10)),
        latitude: 37.5 + i * 0.0001,
        longitude: 127.0,
        accuracy: 5,
        speed: 3,
      ),
  ];
  return RunSummary(
    startedAt: start,
    endedAt: start.add(const Duration(seconds: 80)),
    distanceM: 55,
    movingTime: const Duration(seconds: 80),
    avgPaceSecPerKm: 400,
    calories: 5,
    name: '테스트 러닝',
    splits: const [],
    points: points,
    segments: [points],
  );
}

class _FakeEditor extends RunEditor {
  _FakeEditor(super.ref, this.log, {this.fail = false, this.nullGain = 0});
  final List<(DateTime, GrowthGain?)> log;
  final bool fail;
  int nullGain;
  RunSummary current = _summary();

  @override
  Future<(RunSummary, GrowthGain?)> trimLastRun(
    DateTime newEnd, {
    GrowthGain? shown,
  }) async {
    log.add((newEnd, shown));
    if (fail) throw StateError('save');
    current = trimRunEnd(current, newEnd);
    if (nullGain > 0) {
      nullGain--;
      return (current, null);
    }
    return (
      current,
      shown == null
          ? null
          : const GrowthGain(
              distanceXp: 8,
              goalBonusXp: 0,
              levelBefore: 1,
              levelAfter: 1,
              stageBefore: 1,
              stageAfter: 1,
            ),
    );
  }
}

const _gain = GrowthGain(
  distanceXp: 7,
  goalBonusXp: 0,
  levelBefore: 1,
  levelAfter: 1,
  stageBefore: 1,
  stageAfter: 1,
);

Future<List<(DateTime, GrowthGain?)>> _pump(
  WidgetTester tester,
  Widget screen, {
  bool fail = false,
  int nullGain = 0,
  double scale = 1,
  Size size = const Size(800, 2400),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = <(DateTime, GrowthGain?)>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        growthServiceProvider.overrideWithValue(
          FakeGrowthService(growthState()),
        ),
        runEditorProvider.overrideWith(
          (ref) => _FakeEditor(ref, log, fail: fail, nullGain: nullGain),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return log;
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('끝부분 잘라내기'));
  await tester.pumpAndSettle();
}

Future<void> _pullToStart(WidgetTester tester) async {
  await tester.drag(find.byType(Slider), const Offset(-2000, 0));
  await tester.pumpAndSettle();
}

String _preview(RunSummary s) =>
    '거리 ${formatKm(s.distanceM)}km · 시간 ${formatDuration(s.movingTime)}';

void main() {
  testWidgets('버튼은 종료 직후 요약에만 있다', (tester) async {
    await _pump(tester, SummaryScreen.fromSummary(_summary()));
    expect(find.text('끝부분 잘라내기'), findsOneWidget);
  });

  testWidgets('기록에서 연 상세에는 버튼이 없다', (tester) async {
    await _pump(tester, const SummaryScreen.forRun('none'));
    await tester.pumpAndSettle();
    expect(find.text('끝부분 잘라내기'), findsNothing);
  });

  testWidgets('슬라이더를 당기면 미리보기가 바뀐다', (tester) async {
    final s = _summary();
    await _pump(tester, SummaryScreen.fromSummary(s));
    await _openSheet(tester);
    expect(find.text('종료를 늦게 눌렀다면 끝 시각을 앞으로 당겨요.'), findsOneWidget);
    expect(find.text(_preview(s)), findsOneWidget);
    expect(find.text('끝 시각 17:52:20'), findsOneWidget);

    await _pullToStart(tester);
    final first = trimRunEnd(s, s.points.first.time);
    expect(find.text(_preview(first)), findsOneWidget);
    expect(find.text('끝 시각 17:51:00'), findsOneWidget);
    expect(find.text(_preview(s)), findsNothing);
  });

  for (final (name, theme, colors) in [
    ('라이트', appLightTheme(), AppColors.light),
    ('다크', appDarkTheme(), AppColors.dark),
  ]) {
    testWidgets('슬라이더 채움은 연두가 아니라 primaryDeep 이다 ($name)', (tester) async {
      await _pump(tester, SummaryScreen.fromSummary(_summary()), theme: theme);
      await _openSheet(tester);
      final s = SliderTheme.of(tester.element(find.byType(Slider)));
      expect(s.activeTrackColor, colors.primaryDeep);
      expect(s.thumbColor, colors.primaryDeep);
      expect(s.inactiveTrackColor, colors.surfaceSoft);
      expect(s.activeTrackColor, isNot(colors.primary));
    });
  }

  testWidgets('원래 끝에서는 잘라내기가 눌리지 않는다', (tester) async {
    final log = await _pump(tester, SummaryScreen.fromSummary(_summary()));
    await _openSheet(tester);
    await tester.tap(find.text('잘라내기'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text('종료를 늦게 눌렀다면 끝 시각을 앞으로 당겨요.'), findsOneWidget);
  });

  testWidgets('슬라이더는 끝 시각 라벨을 가진다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, SummaryScreen.fromSummary(_summary()));
    await _openSheet(tester);
    expect(find.bySemanticsLabel(RegExp('끝 시각')), findsWidgets);
    handle.dispose();
  });

  testWidgets('잘라내면 요약 거리·시간과 경험치가 바뀐다', (tester) async {
    final s = _summary();
    final log = await _pump(tester, SummaryScreen.fromSummary(s, gain: _gain));
    expect(find.text('경험치 +7'), findsOneWidget);
    await _openSheet(tester);
    await _pullToStart(tester);
    await tester.tap(find.text('잘라내기'));
    await tester.pumpAndSettle();
    expect(log, hasLength(1));
    expect(log.single.$1, s.points.first.time);
    expect(log.single.$2, _gain);
    final t = trimRunEnd(s, s.points.first.time);
    expect(find.text(formatKm(t.distanceM)), findsOneWidget);
    expect(find.text(formatDuration(t.movingTime)), findsWidgets);
    expect(find.text('경험치 +8'), findsOneWidget);
    expect(find.text('경험치 +7'), findsNothing);
    expect(find.text('종료를 늦게 눌렀다면 끝 시각을 앞으로 당겨요.'), findsNothing);
  });

  testWidgets('잘라내 목표 미달이 되면 보너스 줄이 사라지고 남은 거리가 보인다', (tester) async {
    await _pump(
      tester,
      SummaryScreen.fromSummary(
        _summary(),
        goal: const DistanceGoal(50),
        gain: const GrowthGain(
          distanceXp: 7,
          goalBonusXp: 25,
          levelBefore: 1,
          levelAfter: 1,
          stageBefore: 1,
          stageAfter: 1,
        ),
      ),
    );
    expect(find.textContaining('달성'), findsOneWidget);
    expect(find.text('보너스 +25'), findsOneWidget);
    await _openSheet(tester);
    await _pullToStart(tester);
    await tester.tap(find.text('잘라내기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('달성'), findsNothing);
    expect(find.textContaining('보너스'), findsNothing);
    expect(find.textContaining('남았어요'), findsOneWidget);
  });

  testWidgets('취소하면 그대로다', (tester) async {
    final s = _summary();
    final log = await _pump(tester, SummaryScreen.fromSummary(s, gain: _gain));
    await _openSheet(tester);
    await _pullToStart(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.text(formatKm(s.distanceM)), findsOneWidget);
    expect(find.text('경험치 +7'), findsOneWidget);
  });

  testWidgets('경험치 계산이 실패하면 안내가 뜨고 다시 시도할 수 있다', (tester) async {
    final s = _summary();
    final log = await _pump(
      tester,
      SummaryScreen.fromSummary(s, gain: _gain),
      nullGain: 1,
    );
    await _openSheet(tester);
    await _pullToStart(tester);
    await tester.tap(find.text('잘라내기'));
    await tester.pumpAndSettle();
    expect(find.text('경험치를 다시 계산하지 못했어요'), findsOneWidget);
    final t = trimRunEnd(s, s.points.first.time);
    expect(find.text(formatKm(t.distanceM)), findsOneWidget);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(log, hasLength(2));
    expect(log[1].$1, log[0].$1);
    expect(find.text('경험치 +8'), findsOneWidget);
  });

  testWidgets('저장이 실패하면 안내하고 요약은 그대로다', (tester) async {
    final s = _summary();
    await _pump(tester, SummaryScreen.fromSummary(s, gain: _gain), fail: true);
    await _openSheet(tester);
    await _pullToStart(tester);
    await tester.tap(find.text('잘라내기'));
    await tester.pumpAndSettle();
    expect(find.text('잘라내지 못했어요'), findsOneWidget);
    expect(find.text(formatKm(s.distanceM)), findsOneWidget);
    expect(find.text('경험치 +7'), findsOneWidget);
  });

  testWidgets('글자 1.3배에서 시트가 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      SummaryScreen.fromSummary(_summary()),
      scale: 1.3,
      size: const Size(360, 640),
    );
    await _openSheet(tester);
    expect(find.text('종료를 늦게 눌렀다면 끝 시각을 앞으로 당겨요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
