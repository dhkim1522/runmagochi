import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';

const _cardPadding = EdgeInsets.symmetric(vertical: Gap.s4, horizontal: Gap.s5);

/// 이번 주 목표와 진행 막대. 탭하면 목표(km)를 바꾸는 창이 열린다.
class WeeklyGoalBar extends StatefulWidget {
  const WeeklyGoalBar({
    super.key,
    required this.targetM,
    required this.distanceM,
    required this.streakWeeks,
    required this.onChangeTarget,
  });

  final double targetM;
  final double distanceM;
  final int streakWeeks;

  /// 새 목표를 미터로 알린다.
  final ValueChanged<double> onChangeTarget;

  /// 10 → `10`, 12.5 → `12.5`.
  static String targetLabel(double meters) => formatTargetKm(meters);

  @override
  State<WeeklyGoalBar> createState() => _WeeklyGoalBarState();
}

class _WeeklyGoalBarState extends State<WeeklyGoalBar> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  Future<void> _edit() async {
    final km = await showDialog<double>(
      context: context,
      builder: (_) =>
          _TargetDialog(initial: WeeklyGoalBar.targetLabel(widget.targetM)),
    );
    if (km != null) widget.onChangeTarget(km * 1000);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final target = '이번 주 목표 ${WeeklyGoalBar.targetLabel(widget.targetM)}km';
    final done = '${formatKm(widget.distanceM)}km 달성';
    final progress = widget.targetM <= 0
        ? 0.0
        : (widget.distanceM / widget.targetM).clamp(0.0, 1.0).toDouble();
    return Semantics(
      button: true,
      label: '$target, $done',
      excludeSemantics: true,
      onTap: _edit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: _edit,
        child: ClayPress(
          pressed: _pressed,
          builder: (context, lip) => ClayCard(
            lipHeight: lip,
            reserveLip: false,
            padding: _cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(child: Text(target, style: t.heading)),
                    const SizedBox(width: Gap.s2),
                    Text(done, style: t.label.copyWith(color: c.primaryDeep)),
                  ],
                ),
                const SizedBox(height: 10),
                ClayBar(
                  value: progress,
                  height: 14,
                  fill: c.primary,
                  track: c.surfaceSoft,
                ),
                if (widget.streakWeeks > 0) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${widget.streakWeeks}주 연속 달성',
                    style: t.caption.copyWith(color: c.inkMuted),
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

/// 성장 상태를 읽는 동안 [WeeklyGoalBar] 와 같은 구조·높이로 자리를 잡는 껍데기.
/// 탭할 수 없고, 읽고 나서 카드가 커지거나 줄어 화면이 밀리지 않게 한다.
class WeeklyGoalSkeleton extends StatelessWidget {
  const WeeklyGoalSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return ExcludeSemantics(
      child: ClayCard(
        padding: _cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('이번 주 목표 -', style: t.heading),
            const SizedBox(height: 10),
            ClayBar(
              value: 0,
              height: 14,
              fill: c.primary,
              track: c.surfaceSoft,
            ),
          ],
        ),
      ),
    );
  }
}

class _TargetDialog extends StatefulWidget {
  const _TargetDialog({required this.initial});
  final String initial;

  @override
  State<_TargetDialog> createState() => _TargetDialogState();
}

class _TargetDialogState extends State<_TargetDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 1~200 km 이면 값, 아니면 null.
  double? get _km {
    final v = double.tryParse(_controller.text.trim());
    if (v == null || !v.isFinite || v < 1 || v > 200) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('이번 주 목표'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          suffixText: 'km',
          helperText: '1~200',
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _km == null ? null : () => Navigator.of(context).pop(_km),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
