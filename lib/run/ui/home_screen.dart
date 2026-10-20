import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../settings/ui/settings_screen.dart';
import '../app/permission_gate.dart';
import '../app/providers.dart';
import '../domain/run_summary.dart';
import 'in_run_screen.dart';
import 'permission_screen.dart';
import 'run_goal_picker.dart';
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

  /// 사용자가 고른 오늘 목표(m). null 이면 최근 러닝의 목표를 따른다.
  double? _goalM;

  double get _shownGoalM =>
      _goalM ?? ref.read(lastRunGoalProvider).value ?? 3000;

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
    if (!mounted) return;
    if (!restored) {
      // 복원한 러닝이 이미 자동 종료 조건을 넘어 끝났으면 요약을 연다.
      final view = ref.read(runControllerProvider);
      final summary = view.lastSummary;
      if (view.autoEnded && summary != null) await _openSummary(summary);
      return;
    }
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
      _refreshAfterRun();
    }
  }

  /// 러닝이 끝나 홈으로 돌아오면 성장과 최근 목표를 다시 읽는다.
  void _refreshAfterRun() {
    ref.invalidate(growthStateProvider);
    ref.invalidate(lastRunGoalProvider);
    setState(() => _goalM = null);
  }

  Future<void> _openInRun() async {
    final before = ref.read(runControllerProvider).lastSummary;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InRunScreen()));
    if (!mounted) return;
    _refreshAfterRun();
    final after = ref.read(runControllerProvider).lastSummary;
    if (after == null || identical(after, before)) return;
    await _openSummary(after);
  }

  /// 성장을 반영하고 [summary] 의 요약 화면을 연다.
  Future<void> _openSummary(RunSummary summary) async {
    // invalidate 보다 먼저 sync 해야 이번 러닝의 gain 을 이쪽이 받는다
    // (provider 도 sync 하는데, 먼저 돌면 gain 이 그쪽에서 소모된다).
    GrowthGain? gain;
    try {
      gain = await ref.read(growthServiceProvider).sync();
    } catch (_) {
      gain = null; // 성장 영역만 빼고 요약은 연다.
    }
    if (!mounted) return;
    // 컨트롤러는 끝나면 목표를 비우므로 저장된 러닝에서 읽는다.
    double? goalM;
    final runId = ref.read(runControllerProvider).lastRunId;
    if (runId != null) {
      try {
        goalM =
            (await ref.read(runRepositoryProvider).getRun(runId))?.run.goalM;
      } catch (_) {
        goalM = null; // 목표 줄만 뺀다.
      }
    }
    if (!mounted) return;
    ref.invalidate(growthStateProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SummaryScreen.fromSummary(summary, gain: gain, goalM: goalM),
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
        await ref
            .read(runControllerProvider.notifier)
            .start(goalM: _shownGoalM);
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

  Future<void> _openSettings() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final GrowthState? g = ref.watch(growthStateProvider).value;
    final goalM = _goalM ?? ref.watch(lastRunGoalProvider).value ?? 3000;
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
                RunGoalPicker(
                  goalM: goalM,
                  onChanged: (v) => setState(() => _goalM = v),
                ),
                const SizedBox(height: Gap.s2),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClayCard(
                        key: const ValueKey('home-stage'),
                        radius: Radii.xl,
                        color: c.surfaceSoft,
                        lipColor: c.line,
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 종류를 읽기 전에는 같은 크기의 빈자리만 둔다.
                                if (g == null)
                                  const AvatarSlot(scale: 4)
                                else
                                  AvatarView(
                                    kind: g.kind,
                                    stage: g.stage,
                                    mood: g.mood,
                                    action: AvatarAction.idle,
                                    scale: 4,
                                  ),
                                const SizedBox(height: Gap.s3),
                                Text(
                                  g == null
                                      ? '-'
                                      : '${g.name} Lv.${g.level.level}',
                                  style: t.title,
                                ),
                                const SizedBox(height: Gap.s3),
                                SizedBox(
                                  width: 220,
                                  child: ClayBar(
                                    value: g == null
                                        ? 0
                                        : g.level.xpIntoLevel /
                                              g.level.xpForNext,
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
                      // 설정은 무대 오른쪽 위 톱니로 연다. 겹쳐 두어 홈 배치는 그대로다.
                      Positioned(
                        top: Gap.s2,
                        right: Gap.s2,
                        child: _SettingsButton(onPressed: _openSettings),
                      ),
                    ],
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
                child: Center(child: Text('$_countdown', style: t.numberL)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 홈 오른쪽 위 설정 버튼(48×48). 스크린 리더에는 "설정" 버튼으로 읽힌다.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '설정',
      excludeSemantics: true,
      onTap: onPressed,
      child: IconButton(
        key: const ValueKey('home-settings'),
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        icon: Icon(Icons.settings_outlined, color: AppColors.of(context).ink),
      ),
    );
  }
}
