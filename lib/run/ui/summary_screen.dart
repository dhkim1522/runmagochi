import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../app/providers.dart';
import '../data/run_repository.dart';
import '../domain/run_summary.dart';
import 'route_painter.dart';

final runDetailProvider = FutureProvider.autoDispose.family<RunDetail?, String>(
  (ref, id) => ref.read(runRepositoryProvider).getRun(id),
);

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// `10월 17일 (토) 오후 5:51`
String formatRunDate(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final ampm = l.hour < 12 ? '오전' : '오후';
  return '${l.month}월 ${l.day}일 (${_weekdays[l.weekday - 1]}) '
      "$ampm $h:${l.minute.toString().padLeft(2, '0')}";
}

class SummaryScreen extends ConsumerWidget {
  /// 러닝 종료 직후.
  const SummaryScreen.fromSummary(RunSummary this.summary, {super.key})
    : runId = null;

  /// 기록 목록에서 연 상세.
  const SummaryScreen.forRun(String this.runId, {super.key}) : summary = null;

  final RunSummary? summary;
  final String? runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = summary;
    final Widget body;
    if (s != null) {
      body = _SummaryBody(
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
            error: (_, _) => const Center(child: Text('기록을 찾을 수 없어요')),
            data: (d) => d == null
                ? const Center(child: Text('기록을 찾을 수 없어요'))
                : _SummaryBody(
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
      appBar: AppBar(title: const Text('러닝 요약')),
      body: SafeArea(child: body),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('확인'),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.name,
    required this.startedAt,
    required this.distanceM,
    required this.movingTime,
    required this.avgPaceSecPerKm,
    required this.calories,
    required this.route,
    required this.splits,
  });

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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(formatRunDate(startedAt), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(name, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(
          formatKm(distanceM),
          style: theme.textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('킬로미터', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 24),
        Row(
          children: [
            _Stat(formatPace(avgPaceSecPerKm), '평균 페이스'),
            _Stat(formatDuration(movingTime), '시간'),
            _Stat(calories.round().toString(), '칼로리'),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 220,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: route.isEmpty
                ? const Center(child: Text('경로가 없어요'))
                : CustomPaint(
                    size: Size.infinite,
                    painter: RoutePainter(
                      route,
                      color: theme.colorScheme.primary,
                    ),
                  ),
          ),
        ),
        if (splits.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('구간', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text('km', style: theme.textTheme.labelMedium)),
              Text('페이스', style: theme.textTheme.labelMedium),
            ],
          ),
          for (final sp in splits)
            Padding(
              key: const ValueKey('split-row'),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text('${sp.index}')),
                  Text(formatPace(sp.paceSecPerKm)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
