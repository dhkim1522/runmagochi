import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';

/// 바로 고르는 목표 거리(km).
const List<int> _presetKm = [3, 5, 10];

/// 직접 입력할 수 있는 목표 범위(km).
const int minGoalKm = 3;
const int maxGoalKm = 42;

/// 홈의 "오늘 목표" 선택. 3·5·10km 알약 칩과 직접 입력 칩.
///
/// [goalM] 은 지금 고른 목표(m). 3·5·10km 가 아니면 "직접" 칩이 그 값을 보인다.
class RunGoalPicker extends StatelessWidget {
  const RunGoalPicker({
    super.key,
    required this.goalM,
    required this.onChanged,
  });

  final double goalM;
  final ValueChanged<double> onChanged;

  bool get _isPreset => _presetKm.any((km) => km * 1000 == goalM);

  Future<void> _pickCustom(BuildContext context) async {
    final km = await showDialog<int>(
      context: context,
      builder: (_) =>
          _GoalDialog(initial: _isPreset ? '' : formatTargetKm(goalM)),
    );
    if (km != null) onChanged(km * 1000.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return ClayCard(
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(Gap.s3, Gap.s3, Gap.s3, Gap.s3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('오늘 목표', style: t.label.copyWith(color: c.inkMuted)),
          const SizedBox(height: Gap.s2),
          Row(
            children: [
              for (final km in _presetKm) ...[
                Expanded(
                  child: _GoalChip(
                    label: '${km}km',
                    semanticLabel: '목표 ${km}km',
                    selected: km * 1000 == goalM,
                    onTap: () => onChanged(km * 1000.0),
                  ),
                ),
                const SizedBox(width: Gap.s2),
              ],
              Expanded(
                child: _GoalChip(
                  label: _isPreset ? '직접' : '${formatTargetKm(goalM)}km',
                  semanticLabel: _isPreset
                      ? '목표 직접 입력'
                      : '목표 ${formatTargetKm(goalM)}km 직접 입력',
                  selected: !_isPreset,
                  onTap: () => _pickCustom(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 높이 48 의 알약 칩. 선택하면 primary 바탕.
class _GoalChip extends StatelessWidget {
  const _GoalChip({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? c.primary : c.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? c.primaryDeep : c.line,
            width: Borders.thick,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s2),
                  child: Text(
                    label,
                    style: t.stat.copyWith(
                      fontSize: 18,
                      color: selected ? c.onPrimary : c.ink,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 직접 입력 창. 3~42 사이 정수만 저장할 수 있다.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.initial});
  final String initial;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 범위 안 정수면 그 값, 비었거나 밖이면 null(저장 불가).
  int? get _km {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < minGoalKm || v > maxGoalKm) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final km = _km;
    const rangeText = '$minGoalKm~${maxGoalKm}km 사이 정수로 입력해 주세요';
    return AlertDialog(
      title: const Text('오늘 목표'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          suffixText: 'km',
          helperText: _controller.text.isEmpty ? rangeText : null,
          errorText: km == null && _controller.text.isNotEmpty
              ? rangeText
              : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: km == null ? null : () => Navigator.of(context).pop(km),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
