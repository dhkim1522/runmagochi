import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/weekly_goal_bar.dart';
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
    try {
      await ref.read(growthServiceProvider).setWeeklyTarget(targetM);
    } catch (_) {
      _toast('목표를 바꾸지 못했어요');
    }
    if (!mounted) return;
    ref.invalidate(growthStateProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final GrowthState? g = ref.watch(growthStateProvider).value;
    final nextLevelKm = g == null
        ? null
        : (g.level.xpForNext - g.level.xpIntoLevel) / 10;
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
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
                  Text(
                    '이번 주 -',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AvatarView(
                        stage: g?.stage ?? 1,
                        mood: g?.mood ?? AvatarMood.normal,
                        action: AvatarAction.idle,
                        scale: 8,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        g == null ? '-' : '${g.name} Lv.${g.level.level}',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: g == null
                              ? 0
                              : g.level.xpIntoLevel / g.level.xpForNext,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nextLevelKm == null
                            ? '-'
                            : '다음 레벨까지 ${nextLevelKm.toStringAsFixed(1)}km',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _starting ? null : _onStart,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('시작'),
                  ),
                ),
              ],
            ),
          ),
          if (_countdown != null)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
