import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/weekly_goal_bar.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/permission_gate.dart';
import '../app/providers.dart';
import 'in_run_screen.dart';
import 'permission_screen.dart';
import 'summary_screen.dart';

final weeklyTotalProvider = FutureProvider.autoDispose<(double, int)>(
  (ref) =>
      ref.read(runRepositoryProvider).weeklyTotal(ref.read(clockProvider)()),
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _countdown;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final controller = ref.read(runControllerProvider.notifier);
    final bool restored;
    try {
      restored = await controller.restoreIfAny();
    } catch (_) {
      return;
    }
    if (!restored || !mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('기록 중이던 러닝이 있어요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('종료하고 저장'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이어서 기록'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      await _openInRun();
    } else {
      try {
        await controller.end();
      } catch (_) {
        _toast('저장하지 못했어요');
      }
      if (!mounted) return;
      ref.invalidate(growthStateProvider);
    }
  }

  Future<void> _openInRun() async {
    final before = ref.read(runControllerProvider).lastSummary;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InRunScreen()));
    if (!mounted) return;
    final after = ref.read(runControllerProvider).lastSummary;
    if (after == null || identical(after, before)) {
      ref.invalidate(growthStateProvider);
      return;
    }
    // invalidate 보다 먼저 sync 해야 이번 러닝의 gain 을 이쪽이 받는다
    // (provider 도 sync 하는데, 먼저 돌면 gain 이 그쪽에서 소모된다).
    GrowthGain? gain;
    try {
      gain = await ref.read(growthServiceProvider).sync();
    } catch (_) {
      gain = null; // 성장 영역만 빼고 요약은 연다.
    }
    if (!mounted) return;
    ref.invalidate(growthStateProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SummaryScreen.fromSummary(after, gain: gain),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onStart() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      if (!await _ensurePermission() || !mounted) return;
      for (var n = 3; n >= 1; n--) {
        setState(() => _countdown = n);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
      try {
        await ref.read(runControllerProvider.notifier).start();
      } catch (_) {
        _toast('러닝을 시작하지 못했어요');
        return;
      }
      if (mounted) await _openInRun();
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _countdown = null;
        });
      }
    }
  }

  Future<bool> _ensurePermission() async {
    GateResult result;
    try {
      result = await ref.read(permissionGateProvider).check();
    } catch (_) {
      result = GateResult.needsLocation;
    }
    if (result == GateResult.ready) return true;
    if (!mounted) return false;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            PermissionScreen(onReady: () => Navigator.of(context).pop(true)),
      ),
    );
    return ok == true;
  }

  Future<void> _changeTarget(double targetM) async {
    GrowthGain? gain;
    try {
      gain = await ref.read(growthServiceProvider).setWeeklyTarget(targetM);
    } catch (_) {
      _toast('목표를 바꾸지 못했어요');
    }
    if (!mounted) return;
    ref.invalidate(growthStateProvider);
    final g = gain;
    if (g == null) return;
    // 목표 보너스 말고도 아직 반영하지 않은 러닝 경험치로 레벨이 오를 수 있다.
    if (g.leveledUp) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('레벨 업!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Lv.${g.levelBefore} 에서 Lv.${g.levelAfter} 로'),
              if (g.stageUp) const Text('새 외형 단계!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } else if (g.goalBonusXp > 0) {
      _toast('이번 주 목표 달성 · 경험치 +${g.goalBonusXp}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final GrowthState? g = ref.watch(growthStateProvider).value;
    final nextLevelKm = g == null
        ? null
        : (g.level.xpForNext - g.level.xpIntoLevel) / 10;
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (g != null)
                  WeeklyGoalBar(
                    targetM: g.weekTargetM,
                    distanceM: g.weekDistanceM,
                    streakWeeks: g.streakWeeks,
                    onChangeTarget: _changeTarget,
                  )
                else
                  ClayCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: Gap.s4,
                      horizontal: Gap.s5,
                    ),
                    child: Text(
                      '이번 주 -',
                      textAlign: TextAlign.center,
                      style: t.heading,
                    ),
                  ),
                const SizedBox(height: Gap.s4),
                Expanded(
                  child: ClayCard(
                    radius: Radii.xl,
                    color: c.surfaceSoft,
                    lipColor: c.line,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AvatarView(
                              stage: g?.stage ?? 1,
                              mood: g?.mood ?? AvatarMood.normal,
                              action: AvatarAction.idle,
                              scale: 4,
                            ),
                            const SizedBox(height: Gap.s3),
                            Text(
                              g == null ? '-' : '${g.name} Lv.${g.level.level}',
                              style: t.title,
                            ),
                            const SizedBox(height: Gap.s3),
                            SizedBox(
                              width: 220,
                              child: ClayBar(
                                value: g == null
                                    ? 0
                                    : g.level.xpIntoLevel / g.level.xpForNext,
                                height: 10,
                                fill: c.accent,
                                track: c.surface,
                              ),
                            ),
                            const SizedBox(height: Gap.s3),
                            Text(
                              nextLevelKm == null
                                  ? '-'
                                  : '다음 레벨까지 ${nextLevelKm.toStringAsFixed(1)}km',
                              style: t.label.copyWith(
                                color: c.inkMuted,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Gap.s4),
                ClayButton(label: '시작', onPressed: _starting ? null : _onStart),
                const SizedBox(height: Gap.s2),
              ],
            ),
          ),
          if (_countdown != null)
            Positioned.fill(
              child: ColoredBox(
                color: c.cream,
                child: Center(child: Text('$_countdown', style: t.distanceXl)),
              ),
            ),
        ],
      ),
    );
  }
}
