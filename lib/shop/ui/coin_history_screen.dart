import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../run/app/providers.dart';
import '../app/providers.dart';
import '../data/shop_repository.dart';
import '../domain/catalog.dart';

/// 내역 한 줄: 코인 행과 사유 문구.
typedef _Row = ({CoinEntry entry, String label});

final _coinRowsProvider = FutureProvider.autoDispose<List<_Row>>((ref) async {
  final entries = await ref.watch(coinHistoryProvider.future);
  final runs = ref.read(runRepositoryProvider);
  final rows = <_Row>[];
  for (final e in entries) {
    // 지운 러닝은 읽히지 않는다. 그 줄은 숫자 없이 남긴다.
    final detail = e.runId == null ? null : await runs.getRun(e.runId!);
    final run = detail?.run;
    final label = switch (e.reason) {
      'distance' => run == null ? '러닝' : '러닝 ${formatKm(run.distanceM)}km',
      'runGoal' =>
        run?.goalM == null ? '목표 달성' : '목표 ${formatTargetKm(run!.goalM!)}km 달성',
      _ => switch (e.itemId == null ? null : itemById(e.itemId!)) {
        final item? => '${item.name} 구매',
        null => '아이템 구매',
      },
    };
    rows.add((entry: e, label: label));
  }
  return rows;
});

class CoinHistoryScreen extends ConsumerWidget {
  const CoinHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final rows = ref.watch(_coinRowsProvider);
    void back() => Navigator.of(context).maybePop();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s5, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Semantics(
                    container: true,
                    button: true,
                    label: '뒤로',
                    excludeSemantics: true,
                    onTap: back,
                    child: IconButton(
                      onPressed: back,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: Icon(Icons.chevron_left, size: 32, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: Gap.s1),
                  const Flexible(child: ScreenTitle('코인 내역')),
                ],
              ),
              const SizedBox(height: Gap.s3),
              Expanded(
                child: rows.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) =>
                      Center(child: Text('내역을 불러오지 못했어요', style: t.body)),
                  data: (list) => list.isEmpty
                      ? Center(child: Text('달리면 코인이 쌓여요', style: t.body))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: Gap.s3 - Borders.lip,
                            ),
                            child: _CoinTile(list[i]),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoinTile extends StatelessWidget {
  const _CoinTile(this.row);
  final _Row row;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final amount = row.entry.amount;
    final sign = amount < 0 ? '−' : '+';
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Gap.s4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRunDate(row.entry.at),
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
                Text(row.label, style: t.body),
              ],
            ),
          ),
          const SizedBox(width: Gap.s2),
          Text(
            '$sign${formatThousands(amount.abs())}',
            style: t.titleS.copyWith(color: amount < 0 ? c.ink : c.success),
          ),
        ],
      ),
    );
  }
}
