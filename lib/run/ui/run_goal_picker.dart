import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../domain/run_goal.dart';

/// 바로 고르는 목표 거리(km).
const List<int> _presetKm = [3, 5, 10];

/// 직접 입력할 수 있는 목표 거리 범위(km).
const int minGoalKm = 3;
const int maxGoalKm = 42;

/// 바로 고르는 목표 시간(분).
const List<int> _presetMinutes = [20, 30, 60];

/// 직접 입력할 수 있는 목표 시간 범위(분).
const int minGoalMinutes = 15;
const int maxGoalMinutes = 180;

/// 종류를 바꿀 때 처음 골라지는 목표.
const RunGoal _defaultDistanceGoal = DistanceGoal(3000);
const RunGoal _defaultTimeGoal = TimeGoal(Duration(minutes: 30));

/// 홈의 "오늘 목표" 선택. 위쪽 칩 줄에서 거리·시간을 고르고, 아래 칩 줄에서 값을 고른다.
///
/// [goal] 은 지금 고른 목표. 바로 고르는 값이 아니면 "직접" 칩이 그 값을 보인다.
class RunGoalPicker extends StatelessWidget {
  const RunGoalPicker({super.key, required this.goal, required this.onChanged});

  final RunGoal goal;
  final ValueChanged<RunGoal> onChanged;

  bool get _isTime => goal is TimeGoal;

  /// 직접 입력 칩에 보일 값. 바로 고르는 값이면 null.
  int? get _customValue => switch (goal) {
    DistanceGoal(:final meters) =>
      _presetKm.any((km) => km * 1000 == meters)
          ? null
          : (meters / 1000).round(),
    TimeGoal(:final time) =>
      _presetMinutes.any((m) => m == time.inMinutes) ? null : time.inMinutes,
  };

  Future<void> _pickCustom(BuildContext context) async {
    final custom = _customValue;
    final initial = custom == null ? '' : '$custom';
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _isTime
          ? _GoalDialog(
              initial: initial,
              min: minGoalMinutes,
              max: maxGoalMinutes,
              unit: '분',
            )
          : _GoalDialog(
              initial: initial,
              min: minGoalKm,
              max: maxGoalKm,
              unit: 'km',
            ),
    );
    if (value == null) return;
    onChanged(
      _isTime
          ? TimeGoal(Duration(minutes: value))
          : DistanceGoal(value * 1000.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final custom = _customValue;
    final unit = _isTime ? '분' : 'km';
    return AppCard(
      radius: Radii.lg,
      padding: const EdgeInsets.fromLTRB(Gap.s3, Gap.s3, Gap.s3, Gap.s3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('오늘 목표', style: t.label.copyWith(color: c.inkMuted)),
          const SizedBox(height: Gap.s2),
          ChipRow(
            children: [
              AppChip(
                label: '거리',
                semanticLabel: '목표 종류 거리',
                selected: !_isTime,
                onTap: () {
                  if (_isTime) onChanged(_defaultDistanceGoal);
                },
              ),
              AppChip(
                label: '시간',
                semanticLabel: '목표 종류 시간',
                selected: _isTime,
                onTap: () {
                  if (!_isTime) onChanged(_defaultTimeGoal);
                },
              ),
            ],
          ),
          const SizedBox(height: Gap.s2),
          ChipRow(
            children: [
              if (_isTime)
                for (final m in _presetMinutes)
                  AppChip(
                    label: '$m분',
                    semanticLabel: '목표 $m분',
                    selected: goal == TimeGoal(Duration(minutes: m)),
                    onTap: () => onChanged(TimeGoal(Duration(minutes: m))),
                  )
              else
                for (final km in _presetKm)
                  AppChip(
                    label: '${km}km',
                    semanticLabel: '목표 ${km}km',
                    selected: goal == DistanceGoal(km * 1000.0),
                    onTap: () => onChanged(DistanceGoal(km * 1000.0)),
                  ),
              AppChip(
                label: custom == null ? '직접' : '$custom$unit',
                semanticLabel: custom == null
                    ? '목표 직접 입력'
                    : '목표 $custom$unit 직접 입력',
                selected: custom != null,
                onTap: () => _pickCustom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 직접 입력 창. [min]~[max] 사이 정수만 저장할 수 있다.
class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    required this.initial,
    required this.min,
    required this.max,
    required this.unit,
  });
  final String initial;
  final int min;
  final int max;
  final String unit;

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
  int? get _value {
    final v = int.tryParse(_controller.text.trim());
    if (v == null || v < widget.min || v > widget.max) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final rangeText =
        '${widget.min}~${widget.max}${widget.unit} 사이 정수로 입력해 주세요';
    return AlertDialog(
      title: const Text('오늘 목표'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          suffixText: widget.unit,
          helperText: _controller.text.isEmpty ? rangeText : null,
          errorText: value == null && _controller.text.isNotEmpty
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
          onPressed: value == null
              ? null
              : () => Navigator.of(context).pop(value),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
