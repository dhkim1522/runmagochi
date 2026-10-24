import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../achievement/app/providers.dart';
import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart' show spriteFramePx;
import '../../core/home_tab.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../../settings/ui/settings_screen.dart';
import '../../shop/app/providers.dart';
import '../../shop/ui/coin_chip.dart';
import '../app/permission_gate.dart';
import '../app/providers.dart';
import '../app/run_controller.dart' show shortRunMessage;
import '../domain/run_goal.dart';
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

  /// 사용자가 고른 오늘 목표. null 이면 최근 러닝의 목표를 따른다.
  RunGoal? _goal;

  /// 펫 말풍선에 잠깐 띄우는 안내(1km 미만 미저장). 없으면 다음 레벨까지 거리를 보인다.
  /// 화면 아래 알림은 시작 버튼을 가려서 무대 안에서 알린다.
  String? _notice;
  Timer? _noticeTimer;

  void _showNotice(String message) {
    if (!mounted) return;
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  @override
  void dispose() {
    _noticeTimer?.cancel();
    super.dispose();
  }

  RunGoal get _shownGoal =>
      _goal ?? ref.read(lastRunGoalProvider).value ?? const DistanceGoal(3000);

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
      if (view.discardedShortRun) {
        _showNotice(shortRunMessage);
      } else if (view.autoEnded && summary != null) {
        await _openSummary(summary);
      }
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
            child: const Text('종료하기'),
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
      if (ref.read(runControllerProvider).discardedShortRun) {
        _showNotice(shortRunMessage);
        _refreshAfterRun();
        return;
      }
      final goal = await _endedRunGoal();
      if (!mounted) return;
      _refreshAfterRun(goal: goal);
    }
  }

  /// 러닝이 끝나 홈으로 돌아오면 성장과 최근 목표를 다시 읽는다.
  /// [goal] 은 방금 끝난 러닝의 목표. 칩이 다시 읽기 전 값으로 잠깐 바뀌지 않게 먼저 둔다.
  void _refreshAfterRun({RunGoal? goal}) {
    ref.invalidate(growthStateProvider);
    ref.invalidate(lastRunGoalProvider);
    ref.invalidate(coinBalanceProvider);
    ref.invalidate(coinHistoryProvider);
    ref.invalidate(earnedBadgesProvider);
    ref.invalidate(achievementRunsProvider);
    setState(() => _goal = goal ?? _goal);
  }

  Future<void> _openInRun() async {
    final before = ref.read(runControllerProvider).lastSummary;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InRunScreen()));
    if (!mounted) return;
    if (ref.read(runControllerProvider).discardedShortRun) {
      _showNotice(shortRunMessage);
      _refreshAfterRun();
      return;
    }
    final after = ref.read(runControllerProvider).lastSummary;
    if (after == null || identical(after, before)) {
      _refreshAfterRun();
      return;
    }
    // 성장은 요약이 sync 한 뒤에 다시 읽는다(_openSummary).
    await _openSummary(after);
  }

  /// 방금 끝난 러닝의 목표. 컨트롤러는 끝나면 목표를 비우므로 저장된 러닝에서 읽는다.
  Future<RunGoal?> _endedRunGoal() async {
    final runId = ref.read(runControllerProvider).lastRunId;
    if (runId == null) return null;
    try {
      return (await ref.read(runRepositoryProvider).getRun(runId))?.run.goal;
    } catch (_) {
      return null;
    }
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
    final goal = await _endedRunGoal(); // 못 읽으면 목표 줄만 뺀다.
    if (!mounted) return;
    _refreshAfterRun(goal: goal);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SummaryScreen.fromSummary(summary, gain: gain, goal: goal),
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
    // 화면이 중간에 사라져도 탭바가 숨은 채로 남지 않게 미리 잡아 둔다.
    final countdown = ref.read(runCountdownProvider.notifier);
    try {
      if (!await _ensurePermission() || !mounted) return;
      countdown.set(true);
      for (var n = 3; n >= 1; n--) {
        setState(() => _countdown = n);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
      countdown.set(false);
      try {
        await ref.read(runControllerProvider.notifier).start(goal: _shownGoal);
      } catch (_) {
        _toast('러닝을 시작하지 못했어요');
        return;
      }
      if (mounted) await _openInRun();
    } finally {
      countdown.set(false);
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

  void _openShop() => ref.read(homeTabProvider.notifier).select(shopTabIndex);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final GrowthState? g = ref.watch(growthStateProvider).value;
    final equipped = ref.watch(equippedProvider).value;
    final goal =
        _goal ??
        ref.watch(lastRunGoalProvider).value ??
        const DistanceGoal(3000);
    final nextLevelKm = g == null
        ? null
        : (g.level.xpForNext - g.level.xpIntoLevel) / 10;
    return SafeArea(
      child: Stack(
        children: [
          // 높이가 넉넉하면 한 화면에 채우고(무대가 남는 높이를 받는다),
          // 모자라면(작은 화면·큰 글자) 무대는 가장 작은 높이만 두고 스크롤한다.
          CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.s5,
                    vertical: Gap.s4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CoinChip(onTap: _openShop),
                          _SettingsButton(onPressed: _openSettings),
                        ],
                      ),
                      const SizedBox(height: Gap.s4),
                      Expanded(
                        child: _HomeStage(
                          pet: (scale) => g == null
                              ? AvatarSlot(scale: scale)
                              : AvatarView(
                                  kind: g.kind,
                                  stage: g.stage,
                                  mood: g.mood,
                                  action: AvatarAction.idle,
                                  scale: scale,
                                  hatItemId: equipped?.hatItemId,
                                  accessoryItemId: equipped?.accessoryItemId,
                                ),
                          bubble:
                              _notice ??
                              (nextLevelKm == null
                                  ? null
                                  : '다음 레벨까지 ${nextLevelKm.toStringAsFixed(1)}km'),
                        ),
                      ),
                      const SizedBox(height: Gap.s4),
                      Text(
                        g == null ? '-' : '${g.name} Lv.${g.level.level}',
                        style: t.title,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Gap.s2),
                      ProgressBar(
                        value: g == null
                            ? 0
                            : g.level.xpIntoLevel / g.level.xpForNext,
                      ),
                      const SizedBox(height: Gap.s4),
                      RunGoalPicker(
                        goal: goal,
                        onChanged: (v) => setState(() => _goal = v),
                      ),
                      const SizedBox(height: Gap.s4),
                      AppButton(
                        label: '시작',
                        onPressed: _starting ? null : _onStart,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_countdown != null)
            Positioned.fill(
              child: ColoredBox(
                color: c.background,
                child: Center(child: Text('$_countdown', style: t.numberL)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 홈 사각 무대. 펫은 시안대로 8배이고, 무대가 낮으면 들어가는 가장 큰 정수 배율로
/// 줄인다(3배 아래로는 줄이지 않고 홈이 스크롤한다). 말풍선은 오른쪽 위에 두고, 펫 그림을
/// 가리지 않게(프레임 위 빈 줄 [spriteTopGapRows] 까지만 겹치게) 무대 높이를 잡는다.
class _HomeStage extends StatelessWidget {
  const _HomeStage({required this.pet, required this.bubble});

  /// 배율을 받아 펫(32 × 배율 정사각형)을 만든다.
  final Widget Function(int scale) pet;

  /// 말풍선 문구. null 이면(성장을 읽기 전) 말풍선을 두지 않는다.
  final String? bubble;

  static const int _maxScale = 8;
  static const int _minScale = 3;

  /// [scale] 배 펫과 말풍선이 겹치지 않고 들어가는 무대 높이.
  static double _needed(int scale, double bubbleHeight) {
    final pet =
        spriteFramePx * scale +
        Stage.groundHeight -
        Stage.footSink -
        spriteFootGapRows * scale;
    // 말풍선 아래 끝(위 여백 + 높이)이 펫 상자 위 빈 줄 아래로 내려오면 그만큼 더 높인다.
    final overlap = Gap.s4 + bubbleHeight - spriteTopGapRows * scale;
    return pet + math.max(0, overlap);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleHeight = SpeechBubble.heightFor(
      MediaQuery.textScalerOf(context),
    );
    // 홈 스크롤(SliverFillRemaining)은 이 가장 작은 높이로 쓸 높이를 잰다.
    return MinIntrinsicHeight(
      height: _needed(_minScale, bubbleHeight),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale =
              PetStage.largestScale(
                max: _maxScale,
                min: _minScale,
                fits: (s) => _needed(s, bubbleHeight) <= box.maxHeight,
              ) ??
              _minScale;
          return PetStage(
            key: const ValueKey('home-stage'),
            height: box.maxHeight,
            scale: scale,
            pet: pet(scale),
            bubble: bubble == null ? null : SpeechBubble(bubble!),
          );
        },
      ),
    );
  }
}

/// 홈 오른쪽 위 설정 버튼(흰 동그라미 48×48). 스크린 리더에는 "설정" 버튼으로 읽힌다.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: '설정',
      excludeSemantics: true,
      onTap: onPressed,
      child: Pressable(
        onTap: onPressed,
        child: Container(
          key: const ValueKey('home-settings'),
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
          child: Icon(Icons.settings_outlined, color: c.ink),
        ),
      ),
    );
  }
}
