import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/growth_summary.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/providers.dart';
import '../app/run_editor.dart';
import '../data/run_repository.dart';
import '../domain/run_summary.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'route_painter.dart';
import 'split_pace_chart.dart';
import 'trim_sheet.dart';

final runDetailProvider = FutureProvider.autoDispose.family<RunDetail?, String>(
  (ref, id) => ref.read(runRepositoryProvider).getRun(id),
);

class SummaryScreen extends ConsumerStatefulWidget {
  /// 러닝 종료 직후.
  const SummaryScreen.fromSummary(
    RunSummary this.summary, {
    this.gain,
    this.goalM,
    super.key,
  }) : runId = null;

  /// 기록 목록에서 연 상세. 성장 영역은 없다.
  const SummaryScreen.forRun(String this.runId, {super.key})
    : summary = null,
      gain = null,
      goalM = null;

  final RunSummary? summary;
  final String? runId;

  /// 이번 러닝으로 받은 성장. 없으면 성장 영역을 그리지 않는다.
  final GrowthGain? gain;

  /// 이번 러닝의 오늘 목표(m). 목표 없는 예전 러닝은 null.
  final double? goalM;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  /// 잘라내기로 바뀐 요약과 성장. 바뀌기 전에는 위젯 값이다.
  late RunSummary? _summary = widget.summary;
  late GrowthGain? _gain = widget.gain;
  bool _busy = false;

  Future<void> _openTrim() async {
    final end = await showTrimSheet(context, _summary!);
    if (end == null || !mounted) return;
    await _trim(end);
  }

  Future<void> _trim(DateTime end) async {
    setState(() => _busy = true);
    final shown = _gain;
    final RunSummary trimmed;
    final GrowthGain? gain;
    try {
      (trimmed, gain) = await ref
          .read(runEditorProvider)
          .trimLastRun(end, shown: shown);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('잘라내지 못했어요')));
      return;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _summary = trimmed;
      // 경험치 계산이 실패하면 이전 값을 그대로 두고 다시 시도하게 한다.
      if (gain != null) _gain = gain;
    });
    if (shown != null && gain == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('경험치를 다시 계산하지 못했어요'),
          action: SnackBarAction(
            label: '다시 시도',
            onPressed: () {
              if (mounted) _trim(end);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final runId = widget.runId;
    final Widget body;
    if (s != null) {
      final g = _gain;
      final growthState = g == null
          ? null
          : ref.watch(growthStateProvider).value;
      final growth = g == null
          ? null
          : GrowthSummary(
              kind: growthState?.kind,
              gain: g,
              distanceM: s.distanceM,
              excludedM: excludedFastDistanceM(s.splits),
              goalM: widget.goalM,
              // 잘라낸 뒤의 거리·구간으로 다시 판정한다.
              achieved:
                  widget.goalM != null &&
                  goalAchieved(
                    distanceM: s.distanceM,
                    splits: s.splits,
                    goalM: widget.goalM!,
                  ),
            );
      body = _SummaryBody(
        growth: growth,
        // 성장 반영에 실패해도 목표 결과는 보여 준다.
        goal: g == null
            ? _goalResult(widget.goalM, s.distanceM, s.splits)
            : null,
        name: s.name,
        startedAt: s.startedAt,
        distanceM: s.distanceM,
        movingTime: s.movingTime,
        avgPaceSecPerKm: s.avgPaceSecPerKm,
        calories: s.calories,
        route: [for (final p in s.points) (p.latitude, p.longitude)],
        splits: s.splits,
      );
    } else {
      body = ref
          .watch(runDetailProvider(runId!))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _Notice('기록을 찾을 수 없어요'),
            data: (d) => d == null
                ? const _Notice('기록을 찾을 수 없어요')
                : _SummaryBody(
                    goal: _detailGoal(d),
                    footer: _DeleteRunButton(d.run),
                    name: d.run.name,
                    startedAt: d.run.startedAt,
                    distanceM: d.run.distanceM,
                    movingTime: d.run.movingTime,
                    avgPaceSecPerKm: d.run.avgPaceSecPerKm,
                    calories: d.calories,
                    route: d.route,
                    splits: d.splits,
                  ),
          );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s4),
              child: ScreenTitle('러닝 요약'),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s2, Gap.s5, Gap.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (s != null) ...[
                ClayButton(
                  label: '끝부분 잘라내기',
                  background: AppColors.of(context).surface,
                  foreground: AppColors.of(context).ink,
                  lip: AppColors.of(context).line,
                  onPressed: _busy ? null : _openTrim,
                ),
                const SizedBox(height: Gap.s3),
              ],
              ClayButton(
                label: '확인',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 기록에서 연 상세의 "기록 삭제". 확인 뒤 지우고(받은 경험치는 그대로) 목록으로 돌아간다.
class _DeleteRunButton extends ConsumerStatefulWidget {
  const _DeleteRunButton(this.run);
  final RunListItem run;

  @override
  ConsumerState<_DeleteRunButton> createState() => _DeleteRunButtonState();
}

class _DeleteRunButtonState extends ConsumerState<_DeleteRunButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이 러닝을 지울까요?'),
        content: const Text('기록에서 지워요. 받은 경험치는 그대로예요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: c.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    final run = widget.run;
    try {
      await ref.read(runRepositoryProvider).deleteRun(run.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지우지 못했어요')));
      return;
    }
    if (!mounted) return;
    ref.invalidate(runListProvider);
    ref.invalidate(weeklyTotalProvider);
    ref.invalidate(growthStateProvider);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Center(
      child: TextButton(
        style: TextButton.styleFrom(foregroundColor: c.danger),
        onPressed: _busy ? null : _delete,
        child: const Text('기록 삭제'),
      ),
    );
  }
}

/// 기록에서 연 상세의 목표 결과. 목표 없는 예전 러닝은 줄이 없다.
Widget? _detailGoal(RunDetail d) =>
    _goalResult(d.run.goalM, d.run.distanceM, d.splits);

/// 저장된 거리·구간으로 다시 판정한 목표 결과 줄. 목표가 없으면 null.
Widget? _goalResult(double? goalM, double distanceM, List<Split> splits) {
  if (goalM == null) return null;
  final achieved = goalAchieved(
    distanceM: distanceM,
    splits: splits,
    goalM: goalM,
  );
  return GoalResult(
    goalM: goalM,
    distanceM: distanceM,
    excludedM: excludedFastDistanceM(splits),
    achieved: achieved,
    bonusXp: achieved ? goalBonusXp(goalM) : 0,
  );
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    this.growth,
    this.goal,
    this.footer,
    required this.name,
    required this.startedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    required this.calories,
    required this.route,
    required this.splits,
  });

  final Widget? growth;

  /// 기록에서 연 상세의 목표 결과 줄.
  final Widget? goal;

  /// 목록 맨 아래에 붙는 동작(기록에서 연 상세의 기록 삭제).
  final Widget? footer;
  final String name;
  final DateTime startedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
  final double calories;
  final List<(double, double)> route;
  final List<Split> splits;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.s5, 0, Gap.s5, Gap.s4),
      children: [
        if (growth != null) ...[growth!, const SizedBox(height: Gap.s5)],
        if (goal != null) ...[goal!, const SizedBox(height: Gap.s5)],
        Text(
          formatRunDate(startedAt),
          style: t.caption.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: 2),
        Text(name, style: t.titleS),
        const SizedBox(height: Gap.s5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(formatKm(distanceM), style: t.numberL),
              ),
            ),
            const SizedBox(width: Gap.s2),
            Text('km', style: t.titleS.copyWith(color: c.primaryDeep)),
          ],
        ),
        const SizedBox(height: Gap.s5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatCard(
                label: '평균 페이스',
                value: formatPace(avgPaceSecPerKm),
              ),
            ),
            const SizedBox(width: Gap.s3),
            Expanded(
              child: StatCard(label: '시간', value: formatDuration(movingTime)),
            ),
            const SizedBox(width: Gap.s3),
            Expanded(
              child: StatCard(label: '칼로리', value: '${calories.round()}'),
            ),
          ],
        ),
        const SizedBox(height: Gap.s5),
        ClayCard(
          child: SizedBox(
            height: 220,
            child: route.isEmpty
                ? Center(
                    child: Text(
                      '경로가 없어요',
                      style: t.body.copyWith(color: c.inkMuted),
                    ),
                  )
                : CustomPaint(
                    size: Size.infinite,
                    painter: RoutePainter(
                      route,
                      color: c.primary,
                      startColor: c.accent,
                      endColor: c.ink,
                    ),
                  ),
          ),
        ),
        if (splits.isNotEmpty) ...[
          const SizedBox(height: Gap.s5),
          Text('구간', style: t.heading),
          const SizedBox(height: Gap.s2),
          if (splits.length > 1) ...[
            SplitPaceChart(splits: splits, avgPaceSecPerKm: avgPaceSecPerKm),
            const SizedBox(height: Gap.s4),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s1),
            child: Row(
              children: [
                Expanded(
                  child: Text('km', style: t.label.copyWith(color: c.inkMuted)),
                ),
                Text('페이스', style: t.label.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          const SizedBox(height: Gap.s2),
          ClayCard(
            radius: Radii.md,
            child: Column(
              children: [
                for (final (i, sp) in splits.indexed)
                  Column(
                    children: [
                      if (i > 0)
                        Divider(
                          height: 2,
                          thickness: 2,
                          indent: 0,
                          color: c.surfaceSoft,
                        ),
                      Padding(
                        key: const ValueKey('split-row'),
                        padding: const EdgeInsets.symmetric(
                          vertical: Gap.s3,
                          horizontal: Gap.s4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _splitLabel(splits, i),
                                style: t.body,
                              ),
                            ),
                            Text(formatPace(sp.paceSecPerKm), style: t.heading),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: Gap.s5), footer!],
      ],
    );
  }
}

/// 온전한 1km 구간은 번호, 마지막 짧은 구간은 누적 거리(km)로 부른다.
String _splitLabel(List<Split> splits, int i) {
  final sp = splits[i];
  if (sp.distanceM >= 1000) return '${sp.index}';
  final cumulative = splits
      .take(i + 1)
      .fold<double>(0, (a, e) => a + e.distanceM);
  return formatKm(cumulative).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(message, style: AppText.of(context).body));
}
