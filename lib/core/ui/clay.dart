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
    this.lipHeight = Borders.lip,
    this.reserveLip = true,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final Color? lipColor;

  /// 립(그림자) 두께. 눌림 애니메이션에서만 줄인다(자리는 항상 Borders.lip).
  final double lipHeight;

  /// false 면 립 자리(아래 여백)를 만들지 않는다. 바깥([ClayPress])이 확보할 때.
  final bool reserveLip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: reserveLip ? Borders.lip : 0),
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
              offset: Offset(0, lipHeight),
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
    this.border,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;
  final Color? lip;

  /// 주면 [Borders.thick] 테두리를 그린다. 없으면 테두리 없음.
  final Color? border;

  /// 보조(이전 등) 버튼: 흰 클레이(surface + line 테두리 + line-strong 립, ink 글자).
  factory ClayButton.secondary(
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
      background: c.surface,
      foreground: c.ink,
      lip: c.lineStrong,
      border: c.line,
    );
  }

  /// 버튼 높이(립 제외).
  static const double height = 64;

  /// 보조(일시정지·재개) 버튼: 어두운 판(panel). 립도 같은 색이다(작업 11 에서 립을 뺀다).
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
      background: c.panel,
      foreground: c.onPanel,
      lip: c.panel,
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
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapUp: enabled ? (_) => _set(false) : null,
        onTapCancel: enabled ? () => _set(false) : null,
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: ClayPress(
            pressed: _pressed,
            builder: (context, lip) => Container(
              height: ClayButton.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.background ?? c.primary,
                borderRadius: BorderRadius.circular(Radii.pill),
                border: widget.border == null
                    ? null
                    : Border.all(color: widget.border!, width: Borders.thick),
                boxShadow: [
                  BoxShadow(
                    color: widget.lip ?? c.primaryDeep,
                    offset: Offset(0, lip),
                  ),
                ],
              ),
              // 글자가 길거나 커지면 줄이 바뀌지 않고 버튼 안에서 작아진다.
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.s4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    style: AppText.of(
                      context,
                    ).button.copyWith(color: widget.foreground ?? c.onPrimary),
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

/// 눌림 애니메이션. 립 두께 하나를 80ms 로 움직이고, 같은 값으로 몸통을 내려
/// 이동(Transform)과 립(그림자)이 함께 변한다. 립 자리는 항상 [Borders.lip] 만큼 확보해
/// 눌러도 레이아웃이 안 움직인다. [builder] 는 현재 립 두께를 받아 그림자에 쓴다.
class ClayPress extends StatelessWidget {
  const ClayPress({super.key, required this.pressed, required this.builder});

  final bool pressed;
  final Widget Function(BuildContext context, double lip) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: pressed ? Borders.lipPressed : Borders.lip),
      duration: const Duration(milliseconds: 80),
      builder: (context, lip, _) => Padding(
        padding: const EdgeInsets.only(bottom: Borders.lip),
        child: Transform.translate(
          offset: Offset(0, Borders.lip - lip),
          child: builder(context, lip),
        ),
      ),
    );
  }
}

/// 화면 제목(title 글자). 스크린 리더에는 헤더로 읽힌다.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: AppText.of(context).title),
    );
  }
}
