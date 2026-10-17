import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/providers.dart';
import '../data/run_repository.dart';
import 'home_screen.dart';
import 'summary_screen.dart';

final runListProvider = FutureProvider.autoDispose<List<RunListItem>>(
  (ref) => ref.read(runRepositoryProvider).listRuns(),
);

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 러닝이 끝나 요약이 새로 생기면 목록과 주간 합계를 다시 읽는다.
    ref.listen(runControllerProvider.select((v) => v.lastSummary), (
      prev,
      next,
    ) {
      if (next == null || identical(prev, next)) return;
      ref.invalidate(runListProvider);
      ref.invalidate(weeklyTotalProvider);
    });
    final weekly = ref.watch(weeklyTotalProvider);
    final runs = ref.watch(runListProvider);
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final (km, count) = weekly.when(
      data: (w) => (formatKm(w.$1), '러닝 ${w.$2}회'),
      loading: () => ('-', ''),
      error: (_, _) => ('-', ''),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenTitle('기록'),
            const SizedBox(height: Gap.s4),
            ClayCard(
              padding: const EdgeInsets.symmetric(
                vertical: Gap.s4,
                horizontal: Gap.s5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이번 주', style: t.label.copyWith(color: c.inkMuted)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(km, style: t.numberL),
                        ),
                      ),
                      const SizedBox(width: Gap.s2),
                      Text(
                        'km',
                        style: t.heading.copyWith(
                          fontSize: 22,
                          color: c.primaryDeep,
                        ),
                      ),
                    ],
                  ),
                  if (count.isNotEmpty)
                    Text(
                      count,
                      style: t.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: c.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.s4),
            Text('최근 러닝', style: t.heading),
            const SizedBox(height: Gap.s3),
            Expanded(
              child: runs.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) =>
                    Center(child: Text('기록을 불러오지 못했어요', style: t.body)),
                data: (list) => list.isEmpty
                    ? Center(child: Text('아직 기록이 없어요', style: t.body))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: Gap.s3 - Borders.lip,
                          ),
                          child: _RunTile(list[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile(this.run);
  final RunListItem run;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final stats =
        '${formatKm(run.distanceM)}km · ${formatPace(run.avgPaceSecPerKm)} · '
        '${formatDuration(run.movingTime)}';
    final date =
        '${run.startedAt.toLocal().month.toString().padLeft(2, '0')}/'
        '${run.startedAt.toLocal().day.toString().padLeft(2, '0')}';
    void open() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SummaryScreen.forRun(run.id)),
    );
    return Semantics(
      button: true,
      label: '$date · ${run.name}, $stats',
      excludeSemantics: true,
      onTap: open,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open,
        child: ClayCard(
          radius: Radii.md,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Gap.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$date · ${run.name}',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
              const SizedBox(height: Gap.s1),
              Text(
                stats,
                style: t.heading.copyWith(fontSize: 20, height: 26 / 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
