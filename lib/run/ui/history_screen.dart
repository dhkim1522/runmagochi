import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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
    final header = weekly.when(
      data: (t) => '이번 주 ${formatKm(t.$1)} km · ${t.$2}회',
      loading: () => '이번 주 -',
      error: (_, _) => '이번 주 -',
    );
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              header,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: runs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('기록을 불러오지 못했어요')),
              data: (list) => list.isEmpty
                  ? const Center(child: Text('아직 기록이 없어요'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) => _RunTile(list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunTile extends StatelessWidget {
  const _RunTile(this.run);
  final RunListItem run;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(run.name),
      subtitle: Text(formatRunDate(run.startedAt)),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${formatKm(run.distanceM)} km'),
          Text(
            '${formatPace(run.avgPaceSecPerKm)} · ${formatDuration(run.movingTime)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => SummaryScreen.forRun(run.id)),
      ),
    );
  }
}
