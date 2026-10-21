import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../run/data/run_repository.dart';
import '../app/providers.dart';
import '../domain/badges.dart';
import '../domain/personal_records.dart';

/// 업적 화면: 개인 기록, 받은 배지, 다음 배지.
/// 배지 그림은 임시 아이콘이다(페이즈 6-1 에서 도트로 다시 그린다).
class AchievementScreen extends ConsumerWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
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
      padding: const EdgeInsets.only(bottom: Gap.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('개인 기록', style: t.heading),
          const SizedBox(height: Gap.s3),
          _RecordsCard(records),
          const SizedBox(height: Gap.s5),
          Text('배지 $count / ${badgeCatalog.length}', style: t.heading),
          const SizedBox(height: Gap.s3),
          _BadgeGrid(earnedIds),
          if (next != null) ...[
            const SizedBox(height: Gap.s5),
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
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: Gap.s3, horizontal: Gap.s4),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.s1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: t.body.copyWith(color: c.inkMuted),
                    ),
                  ),
                  const SizedBox(width: Gap.s2),
                  Text(value ?? '-', style: t.titleS),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

extension on Duration? {
  String? map(String Function(Duration) f) => this == null ? null : f(this!);
}

/// 배지 임시 아이콘.
IconData _iconFor(String id) => switch (id) {
  'first_run' => Icons.directions_run,
  'first_goal' => Icons.flag,
  'dist_5k' || 'dist_10k' || 'dist_half' => Icons.route,
  'total_50' || 'total_100' || 'total_300' => Icons.terrain,
  'goals_10' || 'goals_30' => Icons.emoji_events,
  'streak_3' => Icons.local_fire_department,
  'dawn' => Icons.wb_twilight,
  _ => Icons.star,
};

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon(this.id, {required this.earned, this.keyed = true});
  final String id;
  final bool earned;

  /// 목록 칸이 아닌 곳(다음 배지)에서는 목록 칸과 키가 겹치지 않게 false.
  final bool keyed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Opacity(
      // 못 받은 배지는 아바타 탭의 잠긴 단계처럼 흐리게.
      opacity: earned ? 1 : 0.45,
      child: Container(
        key: keyed
            ? ValueKey('badge-${earned ? 'earned' : 'locked'}-$id')
            : null,
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: earned ? c.primary : c.surfaceSoft,
          border: earned
              ? null
              : Border.all(color: c.line, width: Borders.thick),
        ),
        child: Icon(
          _iconFor(id),
          size: 28,
          color: earned ? c.onPrimary : c.inkMuted,
        ),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid(this.earnedIds);
  final Set<String> earnedIds;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        const columns = 3;
        const gap = Gap.s3;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: Gap.s4,
          children: [
            for (final b in badgeCatalog)
              SizedBox(
                width: w,
                child: Column(
                  children: [
                    _BadgeIcon(b.id, earned: earnedIds.contains(b.id)),
                    const SizedBox(height: Gap.s1),
                    Text(b.name, textAlign: TextAlign.center, style: t.caption),
                  ],
                ),
              ),
          ],
        );
      },
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
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: Gap.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _BadgeIcon(p.badge.id, earned: false, keyed: false),
              const SizedBox(width: Gap.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.badge.name, style: t.heading),
                    Text(
                      p.badge.condition,
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.s2),
              Text(
                '코인 +${p.badge.coins}',
                style: t.label.copyWith(color: c.accentDeep),
              ),
            ],
          ),
          const SizedBox(height: Gap.s3),
          if (binary)
            Text(
              '오전 6시 전에 시작해 보세요',
              style: t.caption.copyWith(color: c.inkMuted),
            )
          else ...[
            ClayBar(
              key: const ValueKey('next-badge-bar'),
              value: p.ratio,
              height: 14,
              fill: c.primary,
              track: c.surfaceSoft,
            ),
            const SizedBox(height: 6),
            Text(
              _progressText(p),
              style: t.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}
