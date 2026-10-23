import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../domain/run_goal.dart';

/// 바로 고르는 목표 거리(km).
const List<int> _presetKm = [3, 5, 10];

/// 휠로 고르는 목표 거리 범위(km, 1km 단위).
const int minGoalKm = 3;
const int maxGoalKm = 42;

/// 바로 고르는 목표 시간(분).
const List<int> _presetMinutes = [20, 30, 60];

/// 휠로 고르는 목표 시간 범위(분)와 단위.
const int minGoalMinutes = 15;
const int maxGoalMinutes = 180;
const int goalMinutesStep = 5;

/// 종류를 바꿀 때 처음 골라지는 목표.
const RunGoal _defaultDistanceGoal = DistanceGoal(3000);
const RunGoal _defaultTimeGoal = TimeGoal(Duration(minutes: 30));

/// [goal] 과 같은 종류의 휠 칸. 거리 3~42km 1km 단위, 시간 15~180분 5분 단위.
/// [goal] 이 칸에 없으면(예전에 직접 입력한 47분 등) 순서에 맞게 끼워 넣어,
/// 시트를 열고 그대로 확인해도 목표가 바뀌지 않는다.
List<RunGoal> goalWheelValues(RunGoal goal) {
  final List<RunGoal> grid = switch (goal) {
    DistanceGoal() => [
      for (var km = minGoalKm; km <= maxGoalKm; km++) DistanceGoal(km * 1000.0),
    ],
    TimeGoal() => [
      for (var m = minGoalMinutes; m <= maxGoalMinutes; m += goalMinutesStep)
        TimeGoal(Duration(minutes: m)),
    ],
  };
  if (grid.contains(goal)) return grid;
  double size(RunGoal g) => switch (g) {
    DistanceGoal(:final meters) => meters,
    TimeGoal(:final time) => time.inSeconds.toDouble(),
  };
  final at = grid.indexWhere((g) => size(g) > size(goal));
  return grid..insert(at < 0 ? grid.length : at, goal);
}

/// 홈의 "오늘 목표" 한 줄 카드: `오늘 목표` · `5km` · `›`. 누르면 [showRunGoalSheet] 로
/// 고른다. 지난 목표가 골라져 있어 고르지 않으면 시작 버튼 한 번으로 달린다.
class RunGoalPicker extends StatelessWidget {
  const RunGoalPicker({super.key, required this.goal, required this.onChanged});

  final RunGoal goal;
  final ValueChanged<RunGoal> onChanged;

  /// 줄 높이(누를 수 있는 것 48 이상).
  static const double rowHeight = 48;

  Future<void> _open(BuildContext context) async {
    final picked = await showRunGoalSheet(context, goal);
    if (picked != null && picked != goal) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Semantics(
      button: true,
      label: '오늘 목표 ${goal.label}',
      hint: '눌러서 바꾸기',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: Pressable(
        onTap: () => _open(context),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s3, Gap.s4, Gap.s3),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: rowHeight),
            child: Row(
              children: [
                Text('오늘 목표', style: t.bodyStrong.copyWith(color: c.inkMuted)),
                const SizedBox(width: Gap.s3),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        goal.label,
                        maxLines: 1,
                        style: t.titleS.copyWith(color: c.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: Gap.s1),
                Icon(Icons.chevron_right_rounded, color: c.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 오늘 목표 시트를 연다. 확인하면 고른 목표, 닫으면 null.
Future<RunGoal?> showRunGoalSheet(BuildContext context, RunGoal goal) {
  return showModalBottomSheet<RunGoal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: Motion.sheet(context),
    backgroundColor: AppColors.of(context).background,
    builder: (_) => RunGoalSheet(initial: goal),
  );
}

/// 오늘 목표 시트: 거리·시간 분할 → 자주 쓰는 값 칩 3개 → 휠(전체 범위) → `확인`.
/// 칩을 누르면 휠이 그 값으로 돈다(애니메이션 줄이기면 바로 선다).
class RunGoalSheet extends StatefulWidget {
  const RunGoalSheet({super.key, required this.initial});

  final RunGoal initial;

  @override
  State<RunGoalSheet> createState() => _RunGoalSheetState();
}

class _RunGoalSheetState extends State<RunGoalSheet> {
  late RunGoal _goal = widget.initial;
  late List<RunGoal> _values = goalWheelValues(_goal);
  late FixedExtentScrollController _wheel = FixedExtentScrollController(
    initialItem: _values.indexOf(_goal),
  );

  /// 칩을 눌러 휠이 도는 동안은 지나가는 칸으로 목표를 바꾸지 않는다.
  bool _spinning = false;

  /// 회전 차례. 칩을 연달아 누르거나 종류를 바꾸면 늘어, 앞선 회전이 끝나도
  /// 뒤 회전의 [_spinning] 을 끄지 않는다.
  int _spin = 0;

  bool get _isTime => _goal is TimeGoal;

  @override
  void dispose() {
    _wheel.dispose();
    super.dispose();
  }

  void _switchKind(RunGoal goal) {
    final old = _wheel;
    _spin++;
    _spinning = false;
    setState(() {
      _goal = goal;
      _values = goalWheelValues(goal);
      _wheel = FixedExtentScrollController(initialItem: _values.indexOf(goal));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  Future<void> _pickPreset(RunGoal goal) async {
    setState(() => _goal = goal);
    final index = _values.indexOf(goal);
    // 앞선 돌림이 아직 돌고 있으면 그것이 끝나며 값을 덮지 않게 먼저 번호를 올린다.
    final spin = ++_spin;
    if (!_wheel.hasClients || _wheel.selectedItem == index) {
      _spinning = false;
      return;
    }
    final duration = Motion.of(context, Motion.enter);
    if (duration == Duration.zero) {
      _spinning = false;
      _wheel.jumpToItem(index);
      return;
    }
    _spinning = true;
    await _wheel.animateToItem(
      index,
      duration: duration,
      curve: Motion.standard,
    );
    if (spin != _spin) return; // 뒤 회전이 이어받았다.
    _spinning = false;
    // 도는 중에 사용자가 휠을 잡았으면 멈춘 칸을 따른다.
    if (mounted && _wheel.hasClients) {
      setState(() => _goal = _values[_wheel.selectedItem]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s5, Gap.s5, Gap.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('오늘 목표', style: t.titleS)),
          const SizedBox(height: Gap.s4),
          ChipRow(
            children: [
              AppChip(
                label: '거리',
                semanticLabel: '목표 종류 거리',
                selected: !_isTime,
                onTap: () {
                  if (_isTime) _switchKind(_defaultDistanceGoal);
                },
              ),
              AppChip(
                label: '시간',
                semanticLabel: '목표 종류 시간',
                selected: _isTime,
                onTap: () {
                  if (!_isTime) _switchKind(_defaultTimeGoal);
                },
              ),
            ],
          ),
          const SizedBox(height: Gap.s3),
          ChipRow(
            children: [
              for (final g in [
                if (_isTime)
                  for (final m in _presetMinutes) TimeGoal(Duration(minutes: m))
                else
                  for (final km in _presetKm) DistanceGoal(km * 1000.0),
              ])
                AppChip(
                  label: g.label,
                  semanticLabel: '목표 ${g.label}',
                  selected: _goal == g,
                  onTap: () => _pickPreset(g),
                ),
            ],
          ),
          const SizedBox(height: Gap.s4),
          _GoalWheel(
            key: ValueKey(_isTime),
            controller: _wheel,
            values: _values,
            selected: _goal,
            onChanged: (i) {
              if (_spinning) return;
              setState(() => _goal = _values[i]);
            },
          ),
          const SizedBox(height: Gap.s5),
          AppButton(
            label: '확인',
            onPressed: () => Navigator.of(context).pop(_goal),
          ),
        ],
      ),
    );
  }
}

/// 목표 값 휠. 가운데 칸은 조용한 알약(surfaceSoft, 경계 없음)이고 고른 값은 굵은 ink 다.
/// 연두는 고른 분할과 확인 버튼에만 쓴다(관문 3 판정).
class _GoalWheel extends StatelessWidget {
  const _GoalWheel({
    super.key,
    required this.controller,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final List<RunGoal> values;
  final RunGoal selected;
  final ValueChanged<int> onChanged;

  /// 휠에 보이는 칸 수.
  static const int _visibleRows = 5;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final style = t.titleS;
    // 글자를 키워도 칸 안에 들어가게 칸 높이를 글자 줄 높이에 맞춘다(48 이상).
    final extent = math.max(
      AppChip.height,
      MediaQuery.textScalerOf(context).scale(style.fontSize! * style.height!) +
          Gap.s3,
    );
    final index = values.indexOf(selected);
    final hasLess = index > 0;
    final hasMore = index < values.length - 1;

    // 스크린 리더의 늘리기·줄이기로 한 칸씩 돌린다.
    void step(int by) {
      if (!controller.hasClients) return;
      final to = index + by;
      final duration = Motion.of(context, Motion.quick);
      if (duration == Duration.zero) {
        controller.jumpToItem(to);
      } else {
        controller.animateToItem(
          to,
          duration: duration,
          curve: Motion.standard,
        );
      }
    }

    return Semantics(
      container: true,
      label: '목표 값',
      value: selected.label,
      increasedValue: hasMore ? values[index + 1].label : null,
      decreasedValue: hasLess ? values[index - 1].label : null,
      onIncrease: hasMore ? () => step(1) : null,
      onDecrease: hasLess ? () => step(-1) : null,
      excludeSemantics: true,
      child: SizedBox(
        height: extent * _visibleRows,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: extent,
              decoration: BoxDecoration(
                color: c.surfaceSoft,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
            CupertinoPicker(
              scrollController: controller,
              itemExtent: extent,
              selectionOverlay: null,
              diameterRatio: 1.6,
              squeeze: 1,
              onSelectedItemChanged: onChanged,
              children: [
                for (final v in values)
                  Center(
                    child: Text(
                      v.label,
                      maxLines: 1,
                      style: v == selected
                          ? style.copyWith(
                              color: c.ink,
                              fontWeight: FontWeight.w700,
                            )
                          : style.copyWith(color: c.inkMuted),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
