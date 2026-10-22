import 'dart:io';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/app/providers.dart';
import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/growth_summary.dart';
import '../../shop/app/providers.dart';
import '../../shop/data/shop_repository.dart' show Equipped;
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/providers.dart';
import '../app/run_editor.dart';
import '../app/share_service.dart';
import '../data/run_repository.dart';
import '../domain/route_pace.dart';
import '../domain/run_goal.dart';
import '../domain/run_summary.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'route_painter.dart';
import 'share_card.dart';
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
    this.goal,
    super.key,
  }) : runId = null;

  /// 기록 목록에서 연 상세. 성장 영역은 없다.
  const SummaryScreen.forRun(String this.runId, {super.key})
    : summary = null,
      gain = null,
      goal = null;

  final RunSummary? summary;
  final String? runId;

  /// 이번 러닝으로 받은 성장. 없으면 성장 영역을 그리지 않는다.
  final GrowthGain? gain;

  /// 이번 러닝의 오늘 목표. 목표 없는 예전 러닝은 null.
  final RunGoal? goal;

  @override
  ConsumerState<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends ConsumerState<SummaryScreen> {
  /// 잘라내기로 바뀐 요약과 성장. 바뀌기 전에는 위젯 값이다.
  late RunSummary? _summary = widget.summary;
  late GrowthGain? _gain = widget.gain;
  bool _busy = false;

  /// 공유 카드를 만들고 공유 창을 여는 중. 끝날 때까지 버튼을 막는다.
  bool _sharing = false;

  Future<void> _share(_ShareInput input) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final growth = await ref.read(growthStateProvider.future);
      Equipped? equipped;
      try {
        equipped = await ref.read(equippedProvider.future);
      } catch (_) {
        // 장착 정보를 못 읽으면 맨몸으로 그린다.
      }
      final kind = growth.kind;
      final gain = _gain;
      final card = ShareCard(
        kind: kind,
        stage: growth.stage,
        mood: growth.mood,
        hatItemId: equipped?.hatItemId,
        accessoryItemId: equipped?.accessoryItemId,
        startedAt: input.startedAt,
        distanceM: input.distanceM,
        movingTime: input.movingTime,
        avgPaceSecPerKm: input.avgPaceSecPerKm,
        route: input.route,
        splits: input.splits,
        goalLine: input.goalLine,
        levelUpLine: gain != null && gain.leveledUp
            ? '레벨 ${gain.levelAfter} 달성!'
            : null,
      );
      if (!mounted) return;
      final png = await renderShareCard(
        context,
        card,
        sheets: ShareCard.sheetPaths(
          kind: kind,
          stage: growth.stage,
          mood: growth.mood,
          hatItemId: equipped?.hatItemId,
          accessoryItemId: equipped?.accessoryItemId,
        ),
      );
      final dir = await ref.read(shareTempDirProvider)();
      final file = File(
        '${dir.path}/runmagochi_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      await ref.read(sharerProvider).shareImage(file.path);
    } catch (e) {
      debugPrint('share failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유하지 못했어요')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

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
    _ShareInput? share;
    if (s != null) {
      final route = [for (final p in s.points) (p.latitude, p.longitude)];
      share = _ShareInput.of(
        s.startedAt,
        s.distanceM,
        s.movingTime,
        s.avgPaceSecPerKm,
        route,
        s.splits,
        widget.goal,
      );
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
              goal: widget.goal,
              movingTime: s.movingTime,
              // 잘라낸 뒤의 거리·구간으로 다시 판정한다.
              achieved:
                  widget.goal != null &&
                  goalAchieved(
                    distanceM: s.distanceM,
                    splits: s.splits,
                    movingTime: s.movingTime,
                    goal: widget.goal!,
                  ),
            );
      body = _SummaryBody(
        growth: growth,
        // 성장 반영에 실패해도 목표 결과는 보여 준다.
        goal: g == null
            ? _goalResult(widget.goal, s.distanceM, s.splits, s.movingTime)
            : null,
        name: s.name,
        startedAt: s.startedAt,
        distanceM: s.distanceM,
        movingTime: s.movingTime,
        avgPaceSecPerKm: s.avgPaceSecPerKm,
        calories: s.calories,
        route: route,
        splits: s.splits,
      );
    } else {
      body = ref
          .watch(runDetailProvider(runId!))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const _Notice('기록을 찾을 수 없어요'),
            data: (d) {
              if (d == null) return const _Notice('기록을 찾을 수 없어요');
              share = _ShareInput.of(
                d.run.startedAt,
                d.run.distanceM,
                d.run.movingTime,
                d.run.avgPaceSecPerKm,
                d.route,
                d.splits,
                d.run.goal,
              );
              return _SummaryBody(
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
              );
            },
          );
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.s5,
                Gap.s5,
                Gap.s5,
                Gap.s3,
              ),
              child: Row(
                children: [
                  const Expanded(child: ScreenTitle('러닝 요약')),
                  const SizedBox(width: Gap.s3),
                  Builder(
                    builder: (context) {
                      final input = share;
                      return _ShareButton(
                        key: const ValueKey('share-button'),
                        onPressed: input == null || _sharing
                            ? null
                            : () => _share(input),
                      );
                    },
                  ),
                ],
              ),
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
                // 보조 행동이라 확인보다 작은 흰 알약(관문 2 비평).
                AppButton.secondary(
                  label: '끝부분 잘라내기',
                  small: true,
                  onPressed: _busy ? null : _openTrim,
                ),
                const SizedBox(height: Gap.s3),
              ],
              AppButton(
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

/// 공유 카드에 넣을 값. 저장된 거리·구간으로 목표를 다시 판정해 문구를 만든다.
class _ShareInput {
  _ShareInput(
    this.startedAt,
    this.distanceM,
    this.movingTime,
    this.avgPaceSecPerKm,
    this.route,
    this.splits,
    this.goalLine,
  );

  factory _ShareInput.of(
    DateTime startedAt,
    double distanceM,
    Duration movingTime,
    double? avgPaceSecPerKm,
    List<(double, double)> route,
    List<Split> splits,
    RunGoal? goal,
  ) {
    String? line;
    if (goal != null) {
      final achieved = goalAchieved(
        distanceM: distanceM,
        splits: splits,
        movingTime: movingTime,
        goal: goal,
      );
      line = achieved ? '목표 ${goal.label} 달성' : '목표 ${goal.label}에 도전했어요';
    }
    return _ShareInput(
      startedAt,
      distanceM,
      movingTime,
      avgPaceSecPerKm,
      route,
      splits,
      line,
    );
  }

  final DateTime startedAt;
  final double distanceM;
  final Duration movingTime;
  final double? avgPaceSecPerKm;
  final List<(double, double)> route;
  final List<Split> splits;
  final String? goalLine;
}

/// 머리줄 공유 버튼: 높이 48 흰 알약(surface), 공유 아이콘 + `공유`.
/// 공유 카드를 만드는 동안은 [onPressed] 가 null 이라 흐리고 눌리지 않는다.
class _ShareButton extends StatelessWidget {
  const _ShareButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '공유',
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Pressable(
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 18, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share, size: 20, color: c.ink),
                    const SizedBox(width: 6),
                    Text('공유', style: t.bodyStrong),
                  ],
                ),
              ),
            ),
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
    ref.invalidate(achievementRunsProvider);
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
    _goalResult(d.run.goal, d.run.distanceM, d.splits, d.run.movingTime);

/// 저장된 거리·구간으로 다시 판정한 목표 결과 줄. 목표가 없으면 null.
Widget? _goalResult(
  RunGoal? goal,
  double distanceM,
  List<Split> splits,
  Duration movingTime,
) {
  if (goal == null) return null;
  final achieved = goalAchieved(
    distanceM: distanceM,
    splits: splits,
    movingTime: movingTime,
    goal: goal,
  );
  return GoalResult(
    goal: goal,
    distanceM: distanceM,
    movingTime: movingTime,
    excludedM: excludedFastDistanceM(splits),
    achieved: achieved,
    bonusXp: achieved ? goalBonusXp(goal) : 0,
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
    final segments = routePaceSegments(route, splits);
    // 시안 c: 섹션 사이 28, 카드 사이 12, 카드 안 20.
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s5, Gap.s5),
      children: [
        if (growth != null) ...[growth!, const SizedBox(height: Gap.s7)],
        if (goal != null) ...[
          AppCard(padding: const EdgeInsets.all(Gap.s5), child: goal!),
          const SizedBox(height: Gap.s7),
        ],
        Text(
          formatRunDate(startedAt),
          style: t.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: Gap.s1),
        Text(name, style: t.title),
        const SizedBox(height: Gap.s1),
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
            Text('km', style: t.titleS.copyWith(color: c.inkMuted)),
          ],
        ),
        const SizedBox(height: Gap.s3),
        StatsCard(
          cells: [
            StatCard.cell(label: '평균 페이스', value: formatPace(avgPaceSecPerKm)),
            StatCard.cell(label: '시간', value: formatDuration(movingTime)),
            StatCard.cell(label: '칼로리', value: '${calories.round()}'),
          ],
        ),
        const SizedBox(height: Gap.s3),
        AppCard(
          key: const ValueKey('route-card'),
          padding: const EdgeInsets.all(Gap.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 3 / 2,
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
                          segments: segments,
                          colors: RoutePaceColors.of(c),
                          startColor: c.primary,
                          startEdge: c.primaryEdge,
                          endColor: c.ink,
                          endRing: c.surface,
                        ),
                      ),
              ),
              if (RoutePaceLegend.shows(segments)) ...[
                const SizedBox(height: Gap.s3),
                RoutePaceLegend(
                  key: const ValueKey('route-legend'),
                  segments: segments,
                ),
              ],
            ],
          ),
        ),
        if (splits.isNotEmpty) ...[
          const SizedBox(height: Gap.s3),
          AppCard(
            padding: const EdgeInsets.all(Gap.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('구간', style: t.heading),
                const SizedBox(height: Gap.s3),
                if (splits.length > 1) ...[
                  SplitPaceChart(
                    splits: splits,
                    avgPaceSecPerKm: avgPaceSecPerKm,
                  ),
                  const SizedBox(height: Gap.s2),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'km',
                          style: t.label.copyWith(color: c.inkMuted),
                        ),
                      ),
                      Text('페이스', style: t.label.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                for (final (i, sp) in splits.indexed)
                  // 형제 줄은 key 가 겹치면 안 되어 번호로 한 겹 감싼다.
                  KeyedSubtree(
                    key: ValueKey('split-$i'),
                    child: Padding(
                      key: const ValueKey('split-row'),
                      padding: const EdgeInsets.symmetric(vertical: Gap.s2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              splitLabel(splits, i),
                              style: t.bodyStrong,
                            ),
                          ),
                          Text(
                            formatPace(sp.paceSecPerKm),
                            style: t.bodyStrong.copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (footer != null) ...[const SizedBox(height: Gap.s7), footer!],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: Gap.s5),
    child: EmptyState.error(message: message),
  );
}
