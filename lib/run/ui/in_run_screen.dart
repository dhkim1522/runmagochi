import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/providers.dart';
import '../domain/run_engine.dart';
import '../domain/run_summary.dart';

const Duration _stopHold = Duration(milliseconds: 1500);

/// 러닝 중과 일시정지를 한 화면에서 상태에 따라 바꿔 보여 준다.
class InRunScreen extends ConsumerStatefulWidget {
  const InRunScreen({super.key});

  @override
  ConsumerState<InRunScreen> createState() => _InRunScreenState();
}

class _InRunScreenState extends ConsumerState<InRunScreen> {
  bool _ending = false;

  /// 이미 pop 했다. 자동 종료와 직접 종료가 겹쳐도 한 번만 닫는다.
  bool _closed = false;
  final _stopKey = GlobalKey<_HoldToStopButtonState>();

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await ref.read(runControllerProvider.notifier).end();
      _close();
    } catch (_) {
      // 실패 원인은 lastError 배너로 보인다.
      _stopKey.currentState?.reset();
      if (mounted) setState(() => _ending = false);
    }
  }

  /// 러닝 화면을 한 번만 닫는다. 홈이 lastSummary 로 요약을 연다.
  void _close() {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 종료를 잊어 자동으로 끝나면 직접 끝냈을 때처럼 닫는다. 사용자가 끝내는
    // 중이면(_ending) 그 길이 닫는다.
    ref.listen(runControllerProvider, (prev, next) {
      if (next.autoEnded && prev?.autoEnded != true && !_ending) _close();
      // 목표를 처음 채운 순간에만 한 번 울린다. 복원처럼 이미 달성한 채 열면 울리지 않는다.
      if (next.goalReached && prev?.goalReached == false) {
        HapticFeedback.mediumImpact();
      }
    });
    final view = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);
    final snap = view.snapshot;
    // ended 는 러닝 저장이 실패해 종료만 다시 할 수 있는 상태다.
    final ended = snap.state == RunState.ended;
    final paused = snap.state == RunState.paused || ended;
    final c = AppColors.of(context);
    final t = AppText.of(context);
    // 종류를 읽기 전(또는 실패)에는 같은 크기의 빈자리만 둔다.
    final growth = ref.watch(growthStateProvider).value;

    final avatarStage = _AvatarStage(
      child: growth == null
          ? const AvatarSlot(scale: 3)
          : AvatarView(
              kind: growth.kind,
              stage: growth.stage,
              mood: AvatarMood.normal,
              action: actionFor(
                paused: paused,
                currentPaceSecPerKm: snap.currentPaceSecPerKm,
              ),
              scale: 3,
            ),
    );

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(paused ? '일시정지' : '러닝 중'),
                if (view.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.s2),
                    child: Text(
                      view.lastError!,
                      style: t.body.copyWith(color: c.danger),
                    ),
                  ),
                const SizedBox(height: Gap.s4),
                if (!paused) ...[
                  _StatRow([
                    StatCard(
                      label: '평균 페이스',
                      value: formatPace(snap.avgPaceSecPerKm),
                    ),
                    StatCard(
                      label: '현재 페이스',
                      value: formatPace(snap.currentPaceSecPerKm),
                    ),
                    StatCard(
                      label: '시간',
                      value: formatDuration(snap.movingTime),
                    ),
                  ]),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(formatKm(snap.distanceM), style: t.distanceXl),
                            Text(
                              'km',
                              style: t.title.copyWith(color: c.primaryDeep),
                            ),
                            if (view.goalM != null) ...[
                              const SizedBox(height: Gap.s3),
                              _GoalRow(
                                goalM: view.goalM!,
                                distanceM: snap.distanceM,
                                reached: view.goalReached,
                              ),
                            ],
                            const SizedBox(height: Gap.s6),
                            avatarStage,
                          ],
                        ),
                      ),
                    ),
                  ),
                  ClayButton.accent(
                    context,
                    label: '일시정지',
                    onPressed: controller.pause,
                  ),
                ] else ...[
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(formatKm(snap.distanceM), style: t.numberL),
                          Text(
                            'km',
                            style: t.titleS.copyWith(color: c.primaryDeep),
                          ),
                          if (view.goalM != null) ...[
                            const SizedBox(height: Gap.s2),
                            _GoalRow(
                              goalM: view.goalM!,
                              distanceM: snap.distanceM,
                              reached: view.goalReached,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.s5),
                  _StatRow([
                    StatCard(
                      label: '평균 페이스',
                      value: formatPace(snap.avgPaceSecPerKm),
                    ),
                    StatCard(
                      label: '시간',
                      value: formatDuration(snap.movingTime),
                    ),
                    StatCard(
                      label: '칼로리',
                      value:
                          '${estimateCalories(snap.distanceM, weightKg: view.weightKg).round()}',
                    ),
                  ]),
                  Expanded(child: Center(child: avatarStage)),
                  if (!ended) ...[
                    ClayButton.accent(
                      context,
                      label: '재개',
                      onPressed: _ending ? null : controller.resume,
                    ),
                    const SizedBox(height: Gap.s2),
                  ],
                  _HoldToStopButton(
                    key: _stopKey,
                    enabled: !_ending,
                    onComplete: _end,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 거리 아래의 오늘 목표 진행. 달성하면 "목표 달성!" 을 success 색으로 보인다.
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goalM,
    required this.distanceM,
    required this.reached,
  });

  final double goalM;
  final double distanceM;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return SizedBox(
      width: 200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            reached ? '목표 달성!' : '목표 ${formatTargetKm(goalM)}km',
            style: t.caption.copyWith(color: reached ? c.success : c.inkMuted),
          ),
          const SizedBox(height: Gap.s1),
          ClayBar(
            value: reached ? 1 : distanceM / goalM,
            height: 10,
            fill: c.primary,
            track: c.surfaceSoft,
          ),
        ],
      ),
    );
  }
}

/// 160×120 아바타 무대(surface-soft, radius-xl).
class _AvatarStage extends StatelessWidget {
  const _AvatarStage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceSoft,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: child,
    );
  }
}

/// 지표 카드 3개를 같은 폭으로 늘어놓는다.
class _StatRow extends StatelessWidget {
  const _StatRow(this.cards);

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: Gap.s3),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

/// 1.5초 동안 누르고 있어야 [onComplete] 가 불리는 종료 버튼.
/// 흰 카드형 알약이고, 누르는 동안 왼쪽부터 surface-soft 로 차오른다.
class _HoldToStopButton extends StatefulWidget {
  const _HoldToStopButton({
    super.key,
    required this.enabled,
    required this.onComplete,
  });

  final bool enabled;
  final VoidCallback onComplete;

  @override
  State<_HoldToStopButton> createState() => _HoldToStopButtonState();
}

class _HoldToStopButtonState extends State<_HoldToStopButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress =
      AnimationController(vsync: this, duration: _stopHold)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) widget.onComplete();
        });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  /// 종료가 실패했을 때 진행 막대를 비운다.
  void reset() => _progress.reset();

  void _release() {
    if (_progress.status != AnimationStatus.completed) _progress.reset();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: '길게 눌러 종료',
      excludeSemantics: true,
      // 스크린 리더 사용자는 1.5초 누르기 대신 길게 누르기 동작으로 종료한다.
      onLongPress: widget.enabled ? widget.onComplete : null,
      child: Listener(
        onPointerDown: (_) {
          if (widget.enabled) _progress.forward(from: 0);
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: ClayCard(
          radius: Radii.pill,
          child: SizedBox(
            height: ClayButton.height - 2 * Borders.thick,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.pill),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          key: const Key('hold-fill'),
                          widthFactor: _progress.value,
                          heightFactor: 1,
                          child: ColoredBox(color: c.surfaceSoft),
                        ),
                      ),
                    ),
                  ),
                  Text('길게 눌러 종료', style: AppText.of(context).titleS),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
