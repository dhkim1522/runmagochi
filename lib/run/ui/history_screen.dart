import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../../avatar/app/providers.dart';
import '../../shop/app/providers.dart';
import '../../shop/data/shop_repository.dart' show Equipped;
import '../app/providers.dart';
import '../app/share_service.dart';
import '../data/run_repository.dart';
import '../domain/run_stats.dart';
import 'home_screen.dart';
import 'recap_card.dart';
import 'share_card.dart';
import 'stats_chart.dart';
import 'summary_screen.dart';

final runListProvider = FutureProvider.autoDispose<List<RunListItem>>(
  (ref) => ref.read(runRepositoryProvider).listRuns(),
);

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  StatsPeriod _period = StatsPeriod.week;

  /// 이번 기간에서 몇 기간 전인지 (0 = 이번, 1 = 직전). 미래는 없다.
  int _back = 0;

  DateTime _anchor(DateTime now) {
    final n = now.toLocal();
    return switch (_period) {
      StatsPeriod.week => DateTime(n.year, n.month, n.day - 7 * _back),
      StatsPeriod.month => DateTime(n.year, n.month - _back),
      StatsPeriod.year => DateTime(n.year - _back),
      StatsPeriod.all => n,
    };
  }

  String _title(RunStats s) {
    final a = s.start;
    return switch (_period) {
      StatsPeriod.week =>
        '${a.year}년 ${a.month}월 ${a.day}일 ~ '
            '${DateTime(a.year, a.month, a.day + 6).month}월 '
            '${DateTime(a.year, a.month, a.day + 6).day}일',
      StatsPeriod.month => '${a.year}년 ${a.month}월',
      StatsPeriod.year => '${a.year}년',
      StatsPeriod.all => '전체',
    };
  }

  /// 결산 카드를 만드는 중. 끝날 때까지 버튼을 막는다.
  bool _sharing = false;

  /// 결산 카드 제목. 주·월만, 러닝이 있는 기간만 공유한다. 없으면 null.
  String? _recapLabel(RunStats stats) {
    if (stats.count == 0) return null;
    final now = _back == 0;
    return switch (_period) {
      StatsPeriod.week => now ? '이번 주 결산' : '이 주 결산',
      StatsPeriod.month => now ? '이번 달 결산' : '이 달 결산',
      _ => null,
    };
  }

  Future<void> _shareRecap(RunStats stats, String heading) async {
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
      if (!mounted) return;
      final card = RecapCard(
        title: _title(stats),
        heading: heading,
        stats: stats,
        kind: growth.kind,
        stage: growth.stage,
        mood: growth.mood,
        name: growth.name,
        level: growth.level.level,
        hatItemId: equipped?.hatItemId,
        accessoryItemId: equipped?.accessoryItemId,
      );
      final png = await renderShareCard(
        context,
        card,
        sheets: ShareCard.sheetPaths(
          kind: growth.kind,
          stage: growth.stage,
          mood: growth.mood,
          hatItemId: equipped?.hatItemId,
          accessoryItemId: equipped?.accessoryItemId,
        ),
      );
      final dir = await ref.read(shareTempDirProvider)();
      final file = File(
        '${dir.path}/runmagochi_recap_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(png, flush: true);
      await ref.read(sharerProvider).shareImage(file.path);
    } catch (e) {
      debugPrint('recap share failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('공유하지 못했어요')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 러닝이 끝나 요약이 새로 생기면 목록과 통계를 다시 읽는다.
    ref.listen(runControllerProvider.select((v) => v.lastSummary), (
      prev,
      next,
    ) {
      if (next == null || identical(prev, next)) return;
      ref.invalidate(runListProvider);
      ref.invalidate(weeklyTotalProvider);
    });
    final runs = ref.watch(runListProvider);
    final now = ref.watch(clockProvider)();
    final t = AppText.of(context);
    final list = runs.value;
    final stats = statsFor(list ?? const [], _period, _anchor(now));
    final c = AppColors.of(context);
    // 시안 c 짜임새: 좌우 20, 카드 사이 12, 섹션 사이 28.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s5, Gap.s5, 0),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 주·월 결산 공유는 요약 화면의 공유처럼 제목 오른쪽에 둔다.
                  Row(
                    children: [
                      const Expanded(child: ScreenTitle('기록')),
                      if (list != null)
                        if (_recapLabel(stats) case final heading?)
                          AppButton.secondary(
                            key: const ValueKey('recap-share'),
                            label: '결산 공유',
                            small: true,
                            onPressed: _sharing
                                ? null
                                : () => _shareRecap(stats, heading),
                          ),
                    ],
                  ),
                  const SizedBox(height: Gap.s4),
                  _PeriodTabs(
                    selected: _period,
                    onSelect: (p) => setState(() {
                      _period = p;
                      _back = 0;
                    }),
                  ),
                  const SizedBox(height: Gap.s3),
                  _StatsCard(
                    stats: stats,
                    period: _period,
                    title: _title(stats),
                    loaded: list != null,
                    canGoNext: _back > 0,
                    onPrev: () => setState(() => _back++),
                    onNext: () => setState(() => _back--),
                  ),
                  const SizedBox(height: Gap.s7),
                  Text('최근 러닝', style: t.heading),
                  const SizedBox(height: Gap.s3),
                ],
              ),
            ),
            ...runs.when(
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: Gap.s5),
                    child: EmptyState.error(message: '기록을 불러오지 못했어요'),
                  ),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Gap.s5),
                          child: EmptyState(
                            icon: TabIcon(
                              glyph: TabGlyph.history,
                              color: c.inkMuted,
                              size: EmptyState.iconSize,
                            ),
                            message: '아직 기록이 없어요',
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: Gap.s3),
                          child: _RunTile(list[i]),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: Gap.s2)),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

const _tabLabels = {
  StatsPeriod.week: '주',
  StatsPeriod.month: '월',
  StatsPeriod.year: '년',
  StatsPeriod.all: '전체',
};

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelect});
  final StatsPeriod selected;
  final ValueChanged<StatsPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    return ChipRow(
      children: [
        for (final p in StatsPeriod.values)
          AppChip(
            label: _tabLabels[p]!,
            selected: p == selected,
            onTap: () => onSelect(p),
          ),
      ],
    );
  }
}

/// 기간 이동 줄: 양 끝 48 동그라미 화살표, 가운데 기간 문구(label, ink). 문구는 줄바꿈·
/// 말줄임 없이 한 줄이고 13 아래로 줄지 않는다: 화살표 사이에서 13 아래로 줄어야 하면
/// (좁은 화면·큰 글자) 문구를 화살표 줄 위 한 줄로 올린다.
class _PeriodNav extends StatelessWidget {
  const _PeriodNav({
    required this.title,
    required this.arrows,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final String title;

  /// 전체 기간은 화살표가 없다.
  final bool arrows;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  /// 가장 작은 글자 크기(caption).
  static const double _minFont = 13;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = AppText.of(context).label.copyWith(color: c.ink);
    final scaler = MediaQuery.textScalerOf(context);
    Widget text() => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(title, maxLines: 1, style: style),
    );
    final prev = _ArrowButton(
      key: const Key('stats-prev'),
      icon: Icons.chevron_left,
      label: '이전 기간',
      onTap: onPrev,
    );
    final next = _ArrowButton(
      key: const Key('stats-next'),
      icon: Icons.chevron_right,
      label: '다음 기간',
      onTap: canGoNext ? onNext : null,
    );
    return LayoutBuilder(
      builder: (context, box) {
        final painter = TextPainter(
          text: TextSpan(text: title, style: style),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final natural = painter.width;
        final font = scaler.scale(style.fontSize!);
        painter.dispose();
        // 화살표 사이에 들어가면 그려질 글자 크기.
        final between = arrows
            ? box.maxWidth - 2 * _ArrowButton.size - 2 * Gap.s2
            : box.maxWidth - 2 * Gap.s2;
        final shown = font * math.min(1, between / natural);
        if (!arrows || shown >= _minFont) {
          return Row(
            children: [
              if (arrows) prev,
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s2),
                  child: Center(child: text()),
                ),
              ),
              if (arrows) next,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: text()),
            const SizedBox(height: Gap.s2),
            Row(children: [prev, const Spacer(), next]),
          ],
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.stats,
    required this.period,
    required this.title,
    required this.loaded,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final RunStats stats;
  final StatsPeriod period;
  final String title;
  final bool loaded;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final km = loaded ? formatKm(stats.distanceM) : '-';
    final count = loaded ? '러닝 ${stats.count}회' : '러닝 -회';
    // 러닝이 없으면 페이스 자리표(-'--") 대신 "-" 하나.
    final pace = loaded && stats.count > 0
        ? formatPace(stats.avgPaceSecPerKm)
        : '-';
    final time = loaded ? formatDuration(stats.movingTime) : '-';
    final (name, unit) = switch (period) {
      StatsPeriod.week => ('요일별', ''),
      StatsPeriod.month => ('일별', '일'),
      StatsPeriod.year => ('월별', '월'),
      StatsPeriod.all => ('연도별', '년'),
    };
    final small = t.label.copyWith(color: c.inkMuted);
    return AppCard(
      padding: const EdgeInsets.all(Gap.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PeriodNav(
            title: title,
            arrows: period != StatsPeriod.all,
            canGoNext: canGoNext,
            onPrev: onPrev,
            onNext: onNext,
          ),
          const SizedBox(height: Gap.s3),
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
              Text('km', style: t.titleS.copyWith(color: c.inkMuted)),
            ],
          ),
          const SizedBox(height: Gap.s1),
          Wrap(
            spacing: Gap.s4,
            runSpacing: Gap.s1,
            children: [
              Text(count, style: small),
              Text("평균 페이스 $pace", style: small),
              Text('시간 $time', style: small),
            ],
          ),
          const SizedBox(height: Gap.s5),
          StatsChart(bars: stats.bars, name: name, unit: unit),
        ],
      ),
    );
  }
}

/// 기간 이동 화살표: 48 동그라미(surfaceSoft, 흰 카드 위). 못 가면 흐리고 안 눌린다.
class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  static const double size = 48;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, color: c.ink),
            ),
          ),
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
        child: AppCard(
          radius: Radii.md,
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s3, Gap.s4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$date · ${run.name}',
                      style: t.label.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: Gap.s1),
                    Text(
                      stats,
                      style: t.heading.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.s2),
              Icon(Icons.chevron_right, color: c.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
