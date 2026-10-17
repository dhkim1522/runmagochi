import 'package:flutter/material.dart';

import '../theme.dart';

/// 말랑 클레이 카드: surface + 3px line 테두리 + 아래 6px 립.
/// 립은 그림자라 자리를 차지하지 않으므로 아래에 립 두께만큼 여백을 둔다.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.radius = Radii.lg,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
    this.lipColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Color? lipColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Borders.lip),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? c.surface,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: borderColor ?? c.line,
            width: Borders.thick,
          ),
          boxShadow: [
            BoxShadow(
              color: lipColor ?? c.lineStrong,
              offset: const Offset(0, Borders.lip),
            ),
          ],
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 지표 카드: 작은 라벨(caption, inkMuted) 위, 값(stat) 아래.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return ClayCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: Gap.s1),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: t.caption.copyWith(color: c.inkMuted)),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: t.stat),
          ),
        ],
      ),
    );
  }
}

/// 알약 진행 막대(트랙 + 채움). [value] 는 0~1.
class ClayBar extends StatelessWidget {
  const ClayBar({
    super.key,
    required this.value,
    required this.height,
    required this.fill,
    required this.track,
  });

  final double value;
  final double height;
  final Color fill;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: track,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 알약 버튼(높이 64, 아래 립). 누르면 립만큼 내려앉는다. [onPressed] 가 null 이면 비활성.
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.background,
    this.foreground,
    this.lip,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final Color? lip;

  /// 보조(일시정지·재개) 버튼: accent.
  factory ClayButton.accent(
    BuildContext context, {
    Key? key,
    required String label,
    required VoidCallback? onPressed,
  }) {
    final c = AppColors.of(context);
    return ClayButton(
      key: key,
      label: label,
      onPressed: onPressed,
      background: c.accent,
      foreground: c.onAccent,
      lip: c.accentDeep,
    );
  }

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = widget.onPressed != null;
    final lip = _pressed ? Borders.lipPressed : Borders.lip;
    final button = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.background ?? c.primary,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: [
          BoxShadow(color: widget.lip ?? c.primaryDeep, offset: Offset(0, lip)),
        ],
      ),
      child: Text(
        widget.label,
        style: AppText.of(
          context,
        ).button.copyWith(color: widget.foreground ?? c.onPrimary),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          // 립(그림자)이 차지하지 않는 높이를 항상 확보해 눌러도 레이아웃이 안 움직인다.
          child: Padding(
            padding: const EdgeInsets.only(bottom: Borders.lip),
            child: Transform.translate(
              offset: Offset(0, Borders.lip - lip),
              child: button,
            ),
          ),
        ),
      ),
    );
  }
}
