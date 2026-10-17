import 'package:flutter/material.dart';

import '../../core/format.dart';

/// 이번 주 목표와 진행 막대. 탭하면 목표(km)를 바꾸는 창이 열린다.
class WeeklyGoalBar extends StatelessWidget {
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
  static String targetLabel(double meters) {
    final km = meters / 1000;
    if (km == km.roundToDouble()) return km.toInt().toString();
    return km
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  Future<void> _edit(BuildContext context) async {
    final km = await showDialog<double>(
      context: context,
      builder: (_) => _TargetDialog(initial: targetLabel(targetM)),
    );
    if (km != null) onChangeTarget(km * 1000);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = targetM <= 0
        ? 0.0
        : (distanceM / targetM).clamp(0.0, 1.0).toDouble();
    return InkWell(
      onTap: () => _edit(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '이번 주 목표 ${targetLabel(targetM)}km',
                  style: theme.textTheme.titleMedium,
                ),
                Text('${formatKm(distanceM)}km 달성'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress, minHeight: 8),
            if (streakWeeks > 0) ...[
              const SizedBox(height: 6),
              Text('$streakWeeks주 연속 달성', style: theme.textTheme.bodySmall),
            ],
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
