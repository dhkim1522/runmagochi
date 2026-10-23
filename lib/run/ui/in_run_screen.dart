import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shop/app/providers.dart';
import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart' show spriteFramePx;
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/providers.dart';
import '../data/run_progress_notifier.dart'
    show signalLostNotice, vehicleNotice;
import '../domain/run_engine.dart';
import '../domain/run_goal.dart';
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
    final autoPaused = snap.state == RunState.autoPaused;
    // 자동 일시정지·탈것 의심·신호 끊김은 스스로 풀리고, 재개·일시정지를 고를 수 있다.
    final autoStopped = autoStoppedStates.contains(snap.state);
    final paused = snap.state == RunState.paused || autoStopped || ended;
    // 탈것 의심·신호 끊김은 펫이 말풍선으로 까닭을 알린다 (결정 0033).
    final bubble = switch (snap.state) {
      RunState.vehicle => vehicleNotice,
      RunState.signalLost => signalLostNotice,
      _ => null,
    };
    final c = AppColors.of(context);
    final t = AppText.of(context);
    // 종류를 읽기 전(또는 실패)에는 같은 크기의 빈자리만 둔다.
    final growth = ref.watch(growthStateProvider).value;
    final equipped = ref.watch(equippedProvider).value;

    // 무대 높이에 맞춰 펫 배율을 고른다. 종류를 읽기 전(또는 실패)에는 같은 크기의 빈자리만 둔다.
    final stage = _RunStage(
      bubble: bubble,
      pet: (scale) => growth == null
          ? AvatarSlot(scale: scale)
          : AvatarView(
              kind: growth.kind,
              stage: growth.stage,
              mood: AvatarMood.normal,
              action: actionFor(
                paused: paused,
                currentPaceSecPerKm: snap.currentPaceSecPerKm,
              ),
              scale: scale,
              hatItemId: equipped?.hatItemId,
              accessoryItemId: equipped?.accessoryItemId,
            ),
    );

    // 러닝 중·일시정지 모두 같은 체계: 제목 → 거리 → 목표 줄·막대 → 지표 카드 → 무대 → 버튼.
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenTitle(
                  autoPaused
                      ? '멈춰서 일시정지했어요'
                      : paused
                      ? '일시정지'
                      : '러닝 중',
                ),
                if (autoPaused)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.s1),
                    child: Text(
                      '움직이면 이어져요',
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
                if (view.lastError case final error?)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.s3),
                    child: NoticeCard(message: error),
                  ),
                const SizedBox(height: Gap.s5),
                _Distance(distanceM: snap.distanceM, large: !paused),
                if (view.goal case final goal?) ...[
                  const SizedBox(height: Gap.s5),
                  _GoalRow(
                    goal: goal,
                    distanceM: snap.distanceM,
                    movingTime: snap.movingTime,
                    reached: view.goalReached,
                  ),
                ],
                const SizedBox(height: Gap.s5),
                StatsCard(
                  cells: paused
                      ? [
                          StatCard.cell(
                            label: '평균 페이스',
                            value: formatPace(snap.avgPaceSecPerKm),
                          ),
                          StatCard.cell(
                            label: '시간',
                            value: formatDuration(snap.movingTime),
                          ),
                          StatCard.cell(
                            label: '칼로리',
                            value:
                                '${estimateCalories(snap.distanceM, weightKg: view.weightKg).round()}',
                          ),
                        ]
                      : [
                          StatCard.cell(
                            label: '평균 페이스',
                            value: formatPace(snap.avgPaceSecPerKm),
                          ),
                          StatCard.cell(
                            label: '현재 페이스',
                            value: formatPace(snap.currentPaceSecPerKm),
                          ),
                          StatCard.cell(
                            label: '시간',
                            value: formatDuration(snap.movingTime),
                          ),
                        ],
                ),
                const SizedBox(height: Gap.s5),
                Expanded(child: stage),
                const SizedBox(height: Gap.s5),
                if (!paused)
                  AppButton.panel(label: '일시정지', onPressed: controller.pause)
                else ...[
                  if (autoStopped) ...[
                    // 오래 쉴 때는 사용자 일시정지로 바꿔 5분 자동 종료를 피한다.
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.panel(
                            label: '재개',
                            onPressed: _ending ? null : controller.resume,
                          ),
                        ),
                        const SizedBox(width: Gap.s3),
                        Expanded(
                          child: AppButton.secondary(
                            label: '일시정지',
                            onPressed: _ending ? null : controller.pause,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.s2),
                  ] else if (!ended) ...[
                    AppButton.panel(
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

/// 거리 숫자(화면에서 가장 큰 글자) + 오른쪽 `km`(title, inkMuted) 를 같은 기준선에
/// 가운데로 놓는다. 러닝 중은 distance-xl 128, 일시정지는 number-l 64 로 줄여
/// 무대·재개·종료 버튼 자리를 남긴다. 화면 폭이 모자라면(긴 거리·큰 글자) 함께 줄인다.
class _Distance extends StatelessWidget {
  const _Distance({required this.distanceM, required this.large});

  final double distanceM;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(formatKm(distanceM), style: large ? t.distanceXl : t.numberL),
          const SizedBox(width: Gap.s2),
          Text(
            'km',
            style: t.title.copyWith(
              color: c.inkMuted,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ],
      ),
    );
  }
}

/// 거리 아래의 오늘 목표 줄(왼쪽 정렬) + 전체 폭 진행 막대.
/// 달성하면 "목표 달성!" 을 success 색으로 보인다.
class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.goal,
    required this.distanceM,
    required this.movingTime,
    required this.reached,
  });

  final RunGoal goal;
  final double distanceM;
  final Duration movingTime;
  final bool reached;

  /// 진행 막대 값. 거리 목표는 거리, 시간 목표는 움직인 시간 기준이다.
  double get _progress => switch (goal) {
    DistanceGoal(:final meters) => distanceM / meters,
    TimeGoal(:final time) => movingTime.inMilliseconds / time.inMilliseconds,
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          reached ? '목표 달성!' : '목표 ${goal.label}',
          style: t.label.copyWith(color: reached ? c.success : c.inkMuted),
        ),
        const SizedBox(height: Gap.s2),
        ProgressBar(value: reached ? 1 : _progress),
      ],
    );
  }
}

/// 러닝 중 사각 무대(폭 전체, 땅 띠 [Stage.groundHeightCompact]). 펫은 시안대로 6배이고,
/// 무대가 낮으면(작은 화면·큰 글자) 들어가는 가장 큰 정수 배율로 줄인다.
/// 1배도 안 들어가면(아주 작은 화면 + 큰 글자) 빈 무대 띠 대신 무대를 비워 둔다.
/// [bubble] 이 있으면 오른쪽 위 말풍선이 펫 그림을 가리지 않게(프레임 위 빈 줄
/// [spriteTopGapRows] 까지만 겹치게) 배율을 고른다.
class _RunStage extends StatelessWidget {
  const _RunStage({required this.pet, this.bubble});

  /// 배율을 받아 펫(32 × 배율 정사각형)을 만든다.
  final Widget Function(int scale) pet;

  /// 말풍선 문구. null 이면 말풍선을 두지 않는다.
  final String? bubble;

  static const int _maxScale = 6;
  static const int _minScale = 1;

  /// [scale] 배 펫이 땅 위에 서는 데 필요한 무대 높이. 말풍선 높이 [bubbleHeight]
  /// 가 있으면 말풍선 아래 끝이 펫 상자 위 빈 줄 아래로 내려오는 만큼 더한다.
  static double _needed(int scale, double? bubbleHeight) {
    final pet =
        spriteFramePx * scale +
        Stage.groundHeightCompact -
        Stage.footSink -
        spriteFootGapRows * scale;
    if (bubbleHeight == null) return pet;
    final overlap = Gap.s4 + bubbleHeight - spriteTopGapRows * scale;
    return pet + math.max(0, overlap);
  }

  @override
  Widget build(BuildContext context) {
    final text = bubble;
    final bubbleHeight = text == null
        ? null
        : SpeechBubble.heightFor(MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (context, box) {
        int? largest(double? bubbleHeight) => PetStage.largestScale(
          max: _maxScale,
          min: _minScale,
          fits: (s) => _needed(s, bubbleHeight) <= box.maxHeight,
        );
        // 말풍선 자리까지 안 들어가면 펫을 조금 가리더라도 말풍선을 남긴다.
        final scale = largest(bubbleHeight) ?? largest(null);
        if (scale == null) return const SizedBox.shrink();
        return PetStage(
          height: box.maxHeight,
          scale: scale,
          groundHeight: Stage.groundHeightCompact,
          pet: pet(scale),
          bubble: text == null ? null : SpeechBubble(text),
        );
      },
    );
  }
}

/// 1.5초 동안 누르고 있어야 [onComplete] 가 불리는 종료 버튼.
/// 흰 보조 버튼 모양(surface + line-strong 경계선) 알약이고,
/// 누르는 동안 경계선 안쪽이 왼쪽부터 surface-soft 로 차오른다.
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
        child: AppCard(
          radius: Radii.pill,
          borderColor: c.lineStrong,
          // 차오르는 면이 경계선을 덮지 않게 선 두께만큼 안쪽에 그린다.
          padding: const EdgeInsets.all(Borders.edge),
          child: SizedBox(
            height: AppButton.height - 2 * Borders.edge,
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
