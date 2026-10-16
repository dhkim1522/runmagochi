import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
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
  final _stopKey = GlobalKey<_HoldToStopButtonState>();

  Future<void> _end() async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      await ref.read(runControllerProvider.notifier).end();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // 실패 원인은 lastError 배너로 보인다.
      _stopKey.currentState?.reset();
      if (mounted) setState(() => _ending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(runControllerProvider);
    final controller = ref.read(runControllerProvider.notifier);
    final snap = view.snapshot;
    // ended 는 러닝 저장이 실패해 종료만 다시 할 수 있는 상태다.
    final ended = snap.state == RunState.ended;
    final paused = snap.state == RunState.paused || ended;
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(paused ? '일시정지' : '러닝 중'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (view.lastError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      view.lastError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                if (!paused)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat('평균 페이스', formatPace(snap.avgPaceSecPerKm)),
                      _Stat('현재 페이스', formatPace(snap.currentPaceSecPerKm)),
                      _Stat('시간', formatDuration(snap.movingTime)),
                    ],
                  ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formatKm(snap.distanceM),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Text('km'),
                        if (paused) ...[
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _Stat('평균 페이스', formatPace(snap.avgPaceSecPerKm)),
                              _Stat('시간', formatDuration(snap.movingTime)),
                              _Stat(
                                '칼로리',
                                '${estimateCalories(snap.distanceM).round()} kcal',
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (paused) ...[
                  if (!ended) ...[
                    FilledButton(
                      onPressed: _ending ? null : controller.resume,
                      child: const Text('재개'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  _HoldToStopButton(
                    key: _stopKey,
                    enabled: !_ending,
                    onComplete: _end,
                  ),
                ] else
                  FilledButton(
                    onPressed: controller.pause,
                    child: const Text('일시정지'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/// 1.5초 동안 누르고 있어야 [onComplete] 가 불리는 종료 버튼.
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
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '길게 눌러 종료',
      child: Listener(
        onPointerDown: (_) {
          if (widget.enabled) _progress.forward(from: 0);
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _progress,
                builder: (context, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: _progress.value,
                    backgroundColor: scheme.errorContainer,
                    color: scheme.error,
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('종료'),
            ),
          ],
        ),
      ),
    );
  }
}
