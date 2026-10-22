import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../../run/data/run_repository.dart';
import '../app/providers.dart';
import '../domain/badges.dart';
import '../domain/personal_records.dart';
import 'badge_image.dart';

/// 업적 화면: 개인 기록, 받은 배지, 다음 배지.
/// 배지 그림은 [BadgeImage](24×24 도트, 2배)다. 못 받은 배지는 회색·흐리게.
class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppText.of(context);
    final runs = ref.watch(achievementRunsProvider);
    final earned = ref.watch(earnedBadgesProvider);
    void back() => Navigator.of(context).maybePop();
    final runList = runs.value;
    final earnedList = earned.value;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s5, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleIconButton(
                    icon: Icons.chevron_left,
                    label: '뒤로',
                    onPressed: back,
                  ),
                  const SizedBox(width: Gap.s3),
                  const Flexible(child: ScreenTitle('업적')),
                ],
              ),
              const SizedBox(height: Gap.s3),
              Expanded(
                child: runList == null || earnedList == null
                    ? (runs.hasError || earned.hasError
                          ? Center(child: Text('업적을 불러오지 못했어요', style: t.body))
                          : const Center(child: CircularProgressIndicator()))
                    : _Body(
                        runs: runList,
                        earnedIds: {for (final e in earnedList) e.badgeId},
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.runs, required this.earnedIds});
  final List<RunDetail> runs;
  final Set<String> earnedIds;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final records = recordsFor(runs);
    final next = nextBadge(runs, already: earnedIds);
    final count = badgeCatalog.where((b) => earnedIds.contains(b.id)).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: Gap.s4, bottom: Gap.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('개인 기록', style: t.heading),
          const SizedBox(height: Gap.s3),
          _RecordsCard(records),
          const SizedBox(height: Gap.s7),
          Text('배지 $count / ${badgeCatalog.length}', style: t.heading),
          const SizedBox(height: Gap.s3),
          _BadgeGrid(earnedIds),
          if (next != null) ...[
            const SizedBox(height: Gap.s7),
            Text('다음 배지', style: t.heading),
            const SizedBox(height: Gap.s3),
            _NextBadgeCard(next),
          ],
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  const _RecordsCard(this.r);
  final PersonalRecords r;

  @override
  Widget build(BuildContext context) {
    final distance = r.longestDistanceM;
    final rows = [
      ('최장 거리', distance == null ? null : '${formatKm(distance)}km'),
      ('최장 시간', r.longestTime.map(formatDuration)),
      ('최고 1km', r.bestKm.map(formatDuration)),
      ('최고 5km', r.bestFiveKm.map(formatDuration)),
    ];
    final c = AppColors.of(context);
    final t = AppText.of(context);
    Widget cell((String, String?) row) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.$1, style: t.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: Gap.s1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(row.$2 ?? '-', style: t.stat),
        ),
      ],
    );
    // 흰 카드 하나에 2×2 칸(요약 지표 카드와 같은 값 글자).
    return AppCard(
      key: const ValueKey('records-card'),
      padding: const EdgeInsets.all(Gap.s5),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i += 2) ...[
            if (i > 0) const SizedBox(height: Gap.s5),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cell(rows[i])),
                const SizedBox(width: Gap.s3),
                Expanded(child: cell(rows[i + 1])),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

extension on Duration? {
  String? map(String Function(Duration) f) => this == null ? null : f(this!);
}

/// 배지 12개, 흰 카드 하나에 3열. 받은 것만 색, 이름도 받은 것은 ink·못 받은 것은 inkMuted.
class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid(this.earnedIds);
  final Set<String> earnedIds;

  /// 24px 그림의 3배.
  static const double badgeSize = 72;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return AppCard(
      key: const ValueKey('badge-card'),
      padding: const EdgeInsets.symmetric(vertical: Gap.s5, horizontal: Gap.s3),
      child: LayoutBuilder(
        builder: (context, box) {
          const columns = 3;
          const gap = Gap.s2;
          final w = (box.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: Gap.s5,
            children: [
              for (final b in badgeCatalog)
                SizedBox(
                  width: w,
                  child: Column(
                    children: [
                      BadgeImage(
                        b.id,
                        key: ValueKey(
                          'badge-${earnedIds.contains(b.id) ? 'earned' : 'locked'}-${b.id}',
                        ),
                        earned: earnedIds.contains(b.id),
                        size: badgeSize,
                      ),
                      const SizedBox(height: Gap.s1),
                      Text(
                        b.name,
                        textAlign: TextAlign.center,
                        style: t.caption.copyWith(
                          color: earnedIds.contains(b.id) ? c.ink : c.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// 진행 문구. 단위는 배지마다 다르다(미터·횟수·일수).
String _progressText(BadgeProgress p) {
  final id = p.badge.id;
  if (id.startsWith('dist_') || id.startsWith('total_')) {
    return '${formatKm(p.current)} / ${formatKm(p.target)}km';
  }
  final unit = id.startsWith('streak_') ? '일' : '회';
  return '${p.current.round()} / ${p.target.round()}$unit';
}

class _NextBadgeCard extends StatelessWidget {
  const _NextBadgeCard(this.p);
  final BadgeProgress p;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    // 새벽 러너는 있다/없다 둘뿐이라 진행 막대가 오해를 부른다.
    final binary = p.badge.id == 'dawn';
    return AppCard(
      key: const ValueKey('next-badge-card'),
      padding: const EdgeInsets.all(Gap.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              BadgeImage(p.badge.id, earned: false),
              const SizedBox(width: Gap.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.badge.name, style: t.heading),
                    Text(
                      p.badge.condition,
                      style: t.label.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.s2),
              const CoinIcon(size: 18),
              const SizedBox(width: Gap.s1),
              Text(
                '코인 +${p.badge.coins}',
                style: t.label.copyWith(
                  color: c.coin,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.s4),
          if (binary)
            Text('오전 6시 전에 시작해 보세요', style: t.label.copyWith(color: c.inkMuted))
          else ...[
            ProgressBar(key: const ValueKey('next-badge-bar'), value: p.ratio),
            const SizedBox(height: Gap.s2),
            Text(_progressText(p), style: t.label.copyWith(color: c.inkMuted)),
          ],
        ],
      ),
    );
  }
}
