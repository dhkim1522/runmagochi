import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/growth_summary.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/providers.dart';
import '../data/run_repository.dart';
import '../domain/run_summary.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'route_painter.dart';

final runDetailProvider = FutureProvider.autoDispose.family<RunDetail?, String>(
  (ref, id) => ref.read(runRepositoryProvider).getRun(id),
);

class SummaryScreen extends ConsumerWidget {
  /// 러닝 종료 직후.
  const SummaryScreen.fromSummary(
    RunSummary this.summary, {
    this.gain,
    super.key,
  }) : runId = null;

  /// 기록 목록에서 연 상세. 성장 영역은 없다.
  const SummaryScreen.forRun(String this.runId, {super.key})
    : summary = null,
      gain = null;

  final RunSummary? summary;
  final String? runId;

  /// 이번 러닝으로 받은 성장. 없으면 성장 영역을 그리지 않는다.
  final GrowthGain? gain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final Widget body;
    if (s != null) {
      final g = gain;
      final growthState = g == null
          ? null
          : ref.watch(growthStateProvider).value;
      final weekTargetM = growthState?.weekTargetM;
      final growth = g == null
          ? null
          : GrowthSummary(
              kind: growthState?.kind,
              gain: g,
              distanceM: s.distanceM,
              weekTargetM: weekTargetM,
            );
      body = _SummaryBody(
        growth: growth,
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
          child: ClayButton(
            label: '확인',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}

/// 기록에서 연 상세의 "기록 삭제". 확인 뒤 지우고 경험치를 무른 다음 목록으로 돌아간다.
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
        content: const Text('기록과 이 러닝으로 받은 경험치가 함께 빠져요.'),
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
      // 이미 지운 러닝을 다시 지우는 것은 아무 일도 없으므로, 무르기에서 실패해도 다시 시도할 수 있다.
      await ref.read(runRepositoryProvider).deleteRun(run.id);
      await ref.read(growthServiceProvider).runRemoved(run.id, run.startedAt);
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

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    this.growth,
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
