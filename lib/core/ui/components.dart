import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../stage/park_scene.dart';
import '../stage/stage_scene.dart';
import '../theme.dart';
import 'stage_backdrop.dart';

export '../stage/park_scene.dart' show parkScene;
export '../stage/stage_scene.dart' show StageScene;
export 'stage_backdrop.dart' show StageBackdrop;

/// 공통 컴포넌트(연두 무드보드, 결정 0029). 규칙은 docs/design/design-system.md,
/// 값은 [AppColors]·[AppText]·`Gap`·`Radii`·`Borders`·`Stage`·`Motion` 토큰만 쓴다.
///
/// - 판: [AppCard], [StatCard], [StatsCard]
/// - 누를 것: [AppButton](주요·보조·어두운 판), [AppChip]·[ChipRow](선택 표시 하나)
/// - 진행: [ProgressBar]
/// - 코인: [CoinIcon]
/// - 동그라미 아이콘 버튼: [CircleIconButton](뒤로·설정)
/// - 빈 상태·불러오기 실패: [EmptyState], [EmptyState.error]
/// - 진짜 문제 알림(위치 신호 오류 등): [NoticeCard]
/// - 탭바: [AppTabBar], [TabIcon]
/// - 무대: [PetStage]([StageBackdrop], [StageScene]), [SpeechBubble]
/// - 다이얼로그: `AlertDialog` 를 그대로 쓴다. 판·버튼 모양은 테마(theme.dart)가 정한다.

/// [style] 의 굵기를 [w] 로 바꾼다. 가변 글꼴이라 wght 축도 함께 바꾼다.
TextStyle withWeight(TextStyle style, FontWeight w) => style.copyWith(
  fontWeight: w,
  fontVariations: [FontVariation('wght', w.value.toDouble())],
);

/// 테두리 없는 흰 판. 바탕과 톤 차이로 떨어진다(그림자·립 없음).
/// [borderColor] 를 주면 [Borders.edge] 경계선을 두른다(고른 카드 표시 등).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.radius = Radii.lg,
    this.padding = EdgeInsets.zero,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: Borders.edge),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 지표 카드: 작은 라벨(label, inkMuted) 위, 값(stat) 아래. 작은 카드 모서리.
/// [StatCard.cell] 은 판 없이 내용만 그린다([StatsCard] 한 카드 안의 칸).
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value})
    : _framed = true;

  const StatCard.cell({super.key, required this.label, required this.value})
    : _framed = false;

  final String label;
  final String value;
  final bool _framed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: t.label.copyWith(color: c.inkMuted)),
          ),
        ),
        const SizedBox(height: Gap.s1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: t.stat),
        ),
      ],
    );
    if (!_framed) return content;
    return AppCard(
      radius: Radii.md,
      padding: const EdgeInsets.symmetric(vertical: Gap.s3, horizontal: Gap.s1),
      child: content,
    );
  }
}

/// 흰 카드 하나에 지표 칸([StatCard.cell])을 같은 폭으로 늘어놓는다(시안 러닝 중 지표 3열).
class StatsCard extends StatelessWidget {
  const StatsCard({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.s5, horizontal: Gap.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (i, cell) in cells.indexed) ...[
            if (i > 0) const SizedBox(width: Gap.s1),
            Expanded(child: cell),
          ],
        ],
      ),
    );
  }
}

/// 높이 12 알약 진행 막대. 트랙 surfaceSoft, 채움 primaryDeep(연두로 채우지 않는다).
/// [value] 는 0~1 로 자른다. [semanticLabel] 을 주면 이름과 % 값을 읽힌다.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.semanticLabel});

  static const double height = 12;

  final double value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = value.clamp(0.0, 1.0).toDouble();
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: c.surfaceSoft,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primaryDeep,
                  borderRadius: BorderRadius.circular(Radii.pill),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (semanticLabel == null) return bar;
    return Semantics(
      label: semanticLabel,
      value: '${(v * 100).round()}%',
      child: bar,
    );
  }
}

/// 누름 반응: 누르는 동안 [pressedScale] 로 살짝 작아졌다가 놓으면 돌아온다([Motion.press]).
/// 짧게 톡 눌러도 눌린 모양이 [Motion.press] 동안은 남아 보인다(누르고 바로 떼면 한 프레임도
/// 그려지지 않아 반응이 안 보였다). 크기만 그림으로 바뀌고 레이아웃 자리는 그대로다.
/// [onTap] 이 null 이면 반응하지 않는다. 애니메이션 줄이기면 크기가 시간 없이 바뀐다.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.onTap, required this.child});

  static const double pressedScale = 0.97;

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  /// 눌린 모양을 최소한 남겨 두는 동안 돌아가는 타이머.
  Timer? _hold;

  /// 손을 뗐지만 [_hold] 가 끝나야 돌아온다.
  bool _released = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  void _down() {
    _hold?.cancel();
    _hold = null;
    _released = false;
    _set(true);
    // 애니메이션 줄이기면 붙잡지 않는다: 누른 동안만 눌린 모양, 놓으면 바로 돌아온다.
    if (Motion.reduced(context)) return;
    _hold = Timer(Motion.press, () {
      _hold = null;
      if (_released) _set(false);
    });
  }

  void _up() {
    if (_hold != null) {
      _released = true;
    } else {
      _set(false);
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _down() : null,
      onTapUp: enabled ? (_) => _up() : null,
      onTapCancel: enabled ? _up : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed && enabled ? Pressable.pressedScale : 1,
        duration: Motion.of(context, Motion.press),
        curve: Motion.standard,
        child: widget.child,
      ),
    );
  }
}

enum _ButtonKind { primary, secondary, panel }

/// 높이 60 알약 버튼. [onPressed] 가 null 이면 비활성(50%).
///
/// - 기본: 연두 주요 버튼(primary + primaryEdge 경계선, onPrimary 글자). 화면마다 하나.
/// - [AppButton.secondary]: 흰 보조 버튼(surface + lineStrong 경계선, ink 글자).
/// - [AppButton.panel]: 어두운 판(panel + onPanel 글자). 일시정지·재개.
/// - [small]: 높이 48, 글자 body-strong 17. 주요 버튼 옆 보조 행동(끝부분 잘라내기).
///
/// 글자가 길거나 커지면 줄을 바꾸지 않고 버튼 안에서 작아진다.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  }) : _kind = _ButtonKind.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  }) : _kind = _ButtonKind.secondary;

  const AppButton.panel({
    super.key,
    required this.label,
    required this.onPressed,
    this.small = false,
  }) : _kind = _ButtonKind.panel;

  /// 버튼 높이(최소). 글자가 아주 커지면 그만큼 커진다.
  static const double height = 60;

  /// [small] 버튼 높이(최소). 누를 수 있는 가장 작은 크기.
  static const double smallHeight = 48;

  final String label;
  final VoidCallback? onPressed;

  /// 작은 버튼(높이 [smallHeight], 글자 body-strong).
  final bool small;
  final _ButtonKind _kind;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final (background, foreground, edge) = switch (_kind) {
      _ButtonKind.primary => (c.primary, c.onPrimary, c.primaryEdge),
      _ButtonKind.secondary => (c.surface, c.ink, c.lineStrong),
      _ButtonKind.panel => (c.panel, c.onPanel, null),
    };
    final t = AppText.of(context);
    final enabled = onPressed != null;
    // 머리줄에서 제목과 한 노드로 합쳐지지 않게 따로 둔다.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Pressable(
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(Radii.pill),
              border: edge == null
                  ? null
                  : Border.all(color: edge, width: Borders.edge),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: small ? smallHeight : height,
                minWidth: 48,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: small ? Gap.s5 : Gap.s6,
                ),
                child: Center(
                  heightFactor: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: (small ? t.bodyStrong : t.button).copyWith(
                        color: foreground,
                      ),
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

/// 높이 48 알약 선택 칩. 분할 선택(거리·시간)도 같은 칩을 쓴다(선택 표시 하나).
///
/// - 선택 안 됨: surfaceSoft 면, ink 글자 17/700.
/// - 선택됨: primary 면 + primaryEdge 경계선, onPrimary 글자 17/800.
/// 경계선 자리는 늘 있어(안 고르면 면과 같은 색) 선택이 바뀌어도 크기가 같다.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  static const double height = 48;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 스크린 리더에 [label] 대신 읽힐 이름.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final fill = selected ? c.primary : c.surfaceSoft;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.quick),
          curve: Motion.standard,
          constraints: const BoxConstraints(minHeight: height, minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: Gap.s2),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(
              color: selected ? c.primaryEdge : fill,
              width: Borders.edge,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: selected
                  ? t.heading.copyWith(color: c.onPrimary)
                  : t.bodyStrong.copyWith(color: c.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// 같은 폭 칩 줄. 칩 사이 [Gap.s2].
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, chip) in children.indexed) ...[
          if (i > 0) const SizedBox(width: Gap.s2),
          Expanded(child: chip),
        ],
      ],
    );
  }
}

/// 앱 코인 그림: coin 동그라미 + primary 안쪽 고리 + onCoin 별. 화폐 기호(`$`)는 쓰지 않는다.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: CoinPainter(face: c.coin, ring: c.primary, star: c.onCoin),
      ),
    );
  }
}

/// [CoinIcon] 을 26 칸 격자에 그린다(지름 24 동그라미, 반지름 8 고리, 다섯 꼭짓점 별).
class CoinPainter extends CustomPainter {
  const CoinPainter({
    required this.face,
    required this.ring,
    required this.star,
  });

  final Color face;
  final Color ring;
  final Color star;

  static final Path _star = () {
    const points = [
      (13.0, 8.6),
      (14.4, 11.5),
      (17.6, 11.9),
      (15.3, 14.1),
      (15.9, 17.2),
      (13.0, 15.6),
      (10.1, 17.2),
      (10.7, 14.1),
      (8.4, 11.9),
      (11.6, 11.5),
    ];
    final p = Path()..moveTo(points.first.$1, points.first.$2);
    for (final (x, y) in points.skip(1)) {
      p.lineTo(x, y);
    }
    return p..close();
  }();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 26, size.height / 26);
    const center = Offset(13, 13);
    canvas.drawCircle(center, 12, Paint()..color = face);
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawPath(_star, Paint()..color = star);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CoinPainter old) =>
      old.face != face || old.ring != ring || old.star != star;
}

/// 탭 그림 종류: 러닝화, 기록 막대, 병아리 얼굴, 코인 주머니.
enum TabGlyph { run, history, avatar, shop }

/// [glyph] 의 선 그림(24 칸 격자). 눈은 [_tabGlyphDots] 로 따로 찍는다.
Path tabGlyphPath(TabGlyph glyph) => switch (glyph) {
  // 옆에서 본 러닝화: 발등이 솟은 몸통, 밑창 선, 끈 두 줄.
  TabGlyph.run =>
    Path()
      ..moveTo(3, 18.5)
      ..lineTo(3, 12.5)
      ..quadraticBezierTo(3, 11, 4.5, 11)
      ..lineTo(8, 11)
      ..lineTo(10, 8)
      ..lineTo(13, 10)
      ..lineTo(17, 12.5)
      ..lineTo(19.5, 13)
      ..quadraticBezierTo(21, 13.4, 21, 15)
      ..lineTo(21, 18.5)
      ..close()
      ..moveTo(3, 15.5)
      ..lineTo(21, 15.5)
      ..moveTo(10.5, 11.5)
      ..lineTo(12, 10.5)
      ..moveTo(12.5, 13)
      ..lineTo(14, 12),
  // 바닥선 위에 오르는 막대 셋.
  TabGlyph.history =>
    Path()
      ..moveTo(3.5, 20)
      ..lineTo(20.5, 20)
      ..moveTo(7, 20)
      ..lineTo(7, 14)
      ..moveTo(12, 20)
      ..lineTo(12, 9)
      ..moveTo(17, 20)
      ..lineTo(17, 5),
  // 병아리 얼굴: 둥근 머리, 정수리 새싹 털, 부리.
  TabGlyph.avatar =>
    Path()
      ..moveTo(5, 14)
      ..arcToPoint(const Offset(19, 14), radius: const Radius.circular(7))
      ..lineTo(19, 16)
      ..arcToPoint(const Offset(15, 20), radius: const Radius.circular(4))
      ..lineTo(9, 20)
      ..arcToPoint(const Offset(5, 16), radius: const Radius.circular(4))
      ..close()
      ..moveTo(12, 7)
      ..quadraticBezierTo(11, 4.5, 12.5, 3)
      ..moveTo(12, 7)
      ..quadraticBezierTo(13.5, 5, 15.5, 5.5)
      ..moveTo(10.8, 15.2)
      ..lineTo(13.2, 15.2)
      ..lineTo(12, 16.8)
      ..close(),
  // 코인 주머니: 묶은 입, 둥근 주머니, 가운데 코인.
  TabGlyph.shop =>
    Path()
      ..moveTo(9.5, 7.5)
      ..lineTo(8, 4)
      ..lineTo(16, 4)
      ..lineTo(14.5, 7.5)
      ..close()
      ..moveTo(9.5, 7.5)
      ..quadraticBezierTo(4.5, 11, 5, 16)
      ..quadraticBezierTo(5.5, 20.5, 12, 20.5)
      ..quadraticBezierTo(18.5, 20.5, 19, 16)
      ..quadraticBezierTo(19.5, 11, 14.5, 7.5)
      ..addOval(Rect.fromCircle(center: const Offset(12, 14.5), radius: 2.5)),
};

/// 그림 안 점(눈). 병아리 얼굴만 있다.
List<Offset> _tabGlyphDots(TabGlyph glyph) => switch (glyph) {
  TabGlyph.avatar => const [Offset(9.5, 12.5), Offset(14.5, 12.5)],
  _ => const [],
};

/// 앱 고유 탭 아이콘. 2px 둥근 선, 24 칸.
class TabIcon extends StatelessWidget {
  const TabIcon({
    super.key,
    required this.glyph,
    required this.color,
    this.size = 24,
  });

  final TabGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _TabGlyphPainter(glyph, color),
    ),
  );
}

class _TabGlyphPainter extends CustomPainter {
  const _TabGlyphPainter(this.glyph, this.color);

  final TabGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    canvas.drawPath(
      tabGlyphPath(glyph),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = color;
    for (final o in _tabGlyphDots(glyph)) {
      canvas.drawCircle(o, 1.25, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TabGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

/// 탭 하나: 그림 + 라벨.
class AppTab {
  const AppTab(this.glyph, this.label);

  final TabGlyph glyph;
  final String label;
}

/// 하단 탭바: surface 흰 띠, 선택 탭만 panel 알약(onPanel 그림·라벨 13/700),
/// 나머지는 inkMuted 13/600. 탭 칸 높이 56 이상, 키보드 포커스는 primaryDeep 윤곽.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.tabs,
    required this.index,
    required this.onSelected,
  });

  final List<AppTab> tabs;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ColoredBox(
      color: c.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s3, Gap.s2, Gap.s3, Gap.s3),
          child: Row(
            children: [
              for (final (i, tab) in tabs.indexed) ...[
                if (i > 0) const SizedBox(width: Gap.s1),
                Expanded(
                  child: _TabItem(
                    tab: tab,
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final selected = widget.selected;
    final color = selected ? c.onPanel : c.inkMuted;
    final style = withWeight(
      AppText.of(context).caption.copyWith(color: color),
      selected ? FontWeight.w700 : FontWeight.w600,
    );
    // 키보드 포커스는 Tab 으로 받고 Enter·Space 로 선택한다 (ActivateIntent).
    Widget content = AnimatedContainer(
      duration: Motion.of(context, Motion.quick),
      curve: Motion.standard,
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: Gap.s1),
      decoration: BoxDecoration(
        // 안 고른 탭은 투명한 같은 판이라 선택이 바뀔 때 색만 옅어진다.
        color: selected ? c.panel : c.panel.withAlpha(0),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TabIcon(glyph: widget.tab.glyph, color: color),
          const SizedBox(height: 2),
          // 글자가 커져도 한 줄로, 칸 폭 안에서 작아진다.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.tab.label, maxLines: 1, style: style),
          ),
        ],
      ),
    );
    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        key: const ValueKey('tab-focus-ring'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: c.primaryDeep, width: Borders.focus),
        ),
        child: content,
      );
    }
    return Semantics(
      button: true,
      selected: selected,
      label: widget.tab.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        // 누름 반응은 버튼·칩과 같다(작업 15).
        child: Pressable(onTap: widget.onTap, child: content),
      ),
    );
  }
}

/// 스프라이트 프레임(32px) 아래 빈 줄 수. 발끝이 y=29 라 그 아래 두 줄이 빈다
/// (docs/specs/sprite-spec.md 기준점). 기준점이 바뀌면 함께 고친다.
const int spriteFootGapRows = 2;

/// 스프라이트 프레임 한 변(sprite-spec 32×32). avatar 의 `spriteFramePx` 와 같은 값이다
/// (core 는 avatar 에 기대지 않아 따로 둔다. components_test 의 fitHeight 가 같은지 본다).
const int _spriteFramePx = 32;

/// 스프라이트 프레임 위쪽에서 늘 비는 줄 수. 가장 높은 그림(도토리 비니)도 y=5 부터라
/// 무대의 말풍선이 이만큼은 펫 상자와 겹쳐도 그림을 가리지 않는다(sprite_assets_test 확인).
const int spriteTopGapRows = 5;

/// 마스코트 뒤 사각 무대: [scene] 네 겹(하늘 → 먼 풍경 → 땅·길 → 앞 장식, 기본 공원 산책로)을
/// 한 점 투시로 깐다. 소실점은 펫 몸 뒤 지평선에 있다([StageBackdrop]). 폭 전체, 모서리를 자른다.
///
/// [pet] 은 `32 × [scale]` 정사각형 스프라이트. 발끝이 무대 아래에서
/// `[groundHeight] − [Stage.footSink]` 위에 서도록 무대가 놓는다(옛 땅 띠 윗선 아래 8px 자리,
/// 발밑에 도트 그림자). [moving] 이면 길이 소실점 쪽으로 흐른다(러닝 중에만, 애니메이션
/// 줄이기면 멈춤). [height] 를 주지 않으면 부모 높이를 따르고, 부모가 높이를 정하지 않으면
/// 펫이 들어갈 만큼만 커진다. [bubble] 은 오른쪽 위에 놓는다([SpeechBubble]).
class PetStage extends StatelessWidget {
  const PetStage({
    super.key,
    required this.pet,
    required this.scale,
    this.scene = parkScene,
    this.moving = false,
    this.groundHeight = Stage.groundHeight,
    this.radius = Stage.radius,
    this.height,
    this.bubble,
  });

  final Widget pet;

  /// 스프라이트 정수 배율.
  final int scale;

  /// 배경 네 겹. 상점 배경 아이템은 다른 [StageScene] 으로 바꾼다.
  final StageScene scene;

  /// 길이 흐르는가(러닝 중이고 일시정지가 아닐 때만 켠다).
  final bool moving;

  /// 발끝 기준 높이: 발끝이 무대 아래에서 이 값 − [Stage.footSink] 위에 선다.
  /// 8배 [Stage.groundHeight], 6배 [Stage.groundHeightCompact], 카드 안 [Stage.groundHeightMini].
  final double groundHeight;
  final double radius;
  final double? height;
  final Widget? bubble;

  /// [max] 부터 [min] 까지 내려가며 [fits] 가 참인 가장 큰 정수 배율. 없으면 null.
  /// 화면마다 무대 높이·폭으로 펫 배율을 고를 때 쓴다(홈·러닝 중·요약·공유 카드).
  static int? largestScale({
    required int max,
    required int min,
    required bool Function(int scale) fits,
  }) {
    for (var s = max; s >= min; s--) {
      if (fits(s)) return s;
    }
    return null;
  }

  /// 무대 아래에서 펫 상자 아래까지.
  double get petBottom => _petBottom(scale, groundHeight);

  static double _petBottom(int scale, double groundHeight) =>
      groundHeight - Stage.footSink - spriteFootGapRows * scale;

  /// 펫 상자 위끝이 무대 위끝에 닿는 무대 높이: 펫 상자(`32 × scale`) + [petBottom].
  /// 화면이 무대 높이를 펫에 맞춰 잡을 때 쓴다(여백은 더해서 쓴다).
  static double fitHeight({
    required int scale,
    double groundHeight = Stage.groundHeight,
  }) => _spriteFramePx * scale + _petBottom(scale, groundHeight);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: StageBackdrop(
                scene: scene,
                scale: scale,
                feetFromBottom: groundHeight - Stage.footSink,
                moving: moving,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: petBottom),
              child: pet,
            ),
            if (bubble != null)
              Positioned(
                top: Gap.s4,
                left: Gap.s4,
                right: Gap.s4,
                child: Align(alignment: Alignment.topRight, child: bubble),
              ),
          ],
        ),
      ),
    );
  }
}

/// 말풍선: bubble 판(모서리 md) + 아래 왼쪽 꼬리. 무대 위 캐릭터가 말하는 한 줄.
/// 글자는 bubble 위 ink 라 무대 색과 상관없이 읽힌다. 라이트는 흰 카드, 다크는 무대
/// 하늘보다 밝은 판이라 모양·꼬리가 하늘에 묻히지 않는다.
class SpeechBubble extends StatelessWidget {
  const SpeechBubble(this.text, {super.key});

  final String text;

  /// 꼬리 크기와 말풍선 왼쪽에서 꼬리까지.
  static const Size _tail = Size(16, 8);
  static const double _tailInset = 28;

  /// 판 위아래 여백.
  static const double _padV = 10;

  /// 글자 배율 [scaler] 에서 말풍선(판 + 꼬리)의 가장 큰 높이. 무대가 말풍선 자리를
  /// 잡을 때 쓴다. 글자는 label(14, 줄 높이 20) 한 줄이다.
  static double heightFor(TextScaler scaler) =>
      2 * _padV + scaler.scale(14) * 20 / 14 + _tail.height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.bubble,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.s4,
              vertical: _padV,
            ),
            // 한 줄로 두고, 무대 폭이 모자라면 줄을 바꾸지 않고 작아진다([heightFor] 를 넘지 않게).
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: withWeight(
                  t.label.copyWith(color: c.ink),
                  FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: _tailInset),
          child: CustomPaint(size: _tail, painter: _TailPainter(c.bubble)),
        ),
      ],
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2 + 1.5, size.height - 1.5)
      ..quadraticBezierTo(
        size.width / 2,
        size.height,
        size.width / 2 - 1.5,
        size.height - 1.5,
      )
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.color != color;
}

/// 흰 동그라미 아이콘 버튼(48×48, surface + ink 아이콘 24). 뒤로·설정처럼 머리줄의 작은 행동.
/// 스크린 리더에는 [label] 버튼으로 읽힌다. 누르면 살짝 작아졌다 돌아온다.
/// [onPressed] 가 null 이면 비활성(50%, 눌리지 않음).
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  static const double size = 48;

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null;
    // 머리줄에서 제목과 한 노드로 합쳐지지 않게 따로 둔다.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Pressable(
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
            child: SizedBox.square(
              dimension: size,
              child: Icon(icon, size: 24, color: c.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// 빈 상태: 흰 카드(radius-lg) 가운데 그림 하나와 안내 문구(body, inkMuted).
/// 그림은 앱 그림([TabIcon]·[CoinIcon] 등)을 넘긴다. 문구는 화면의 기존 문구 그대로.
/// [EmptyState.error] 는 불러오기 실패: 같은 카드에 느낌표 동그라미(inkMuted). 사용자가 고칠
/// 문제가 아니라 벌주지 않게 danger 를 쓰지 않는다. [action] 은 문구 아래(다시 시도 등).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required Widget this.icon,
    required this.message,
    this.action,
  });

  const EmptyState.error({super.key, required this.message, this.action})
    : icon = null;

  /// 그림 크기. [EmptyState.error] 의 느낌표가 이 크기다. [icon] 은 크기를 바꾸지 않고 그대로
  /// 놓으니, 넘기는 쪽이 이 값으로 그린다(예: `CoinIcon(size: EmptyState.iconSize)`).
  static const double iconSize = 40;

  final Widget? icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.s8, horizontal: Gap.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child:
                icon ??
                Icon(
                  Icons.error_outline_rounded,
                  size: iconSize,
                  color: c.inkMuted,
                ),
          ),
          const SizedBox(height: Gap.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.body.copyWith(color: c.inkMuted),
          ),
          if (action case final action?) ...[
            const SizedBox(height: Gap.s5),
            action,
          ],
        ],
      ),
    );
  }
}

/// 알림 줄: 흰 작은 카드(radius-md)에 danger 경계선·느낌표 그림·글자(body-strong).
/// 위치 신호 오류·저장 실패처럼 지금 러닝에 영향이 있는 진짜 문제에만 쓴다.
class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    return AppCard(
      radius: Radii.md,
      borderColor: c.danger,
      padding: const EdgeInsets.symmetric(vertical: Gap.s3, horizontal: Gap.s4),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.error_outline_rounded, size: 24, color: c.danger),
          ),
          const SizedBox(width: Gap.s3),
          Expanded(
            child: Text(message, style: t.bodyStrong.copyWith(color: c.danger)),
          ),
        ],
      ),
    );
  }
}

/// 자식 대신 [height] 를 고유 높이로 알린다. 자식([LayoutBuilder])은 고유 크기를 잴 수 없어서
/// 스크롤이 쓸 높이를 잴 때 무대의 가장 작은 높이를 대신 답한다. 실제 배치는 자식에 맡긴다.
/// 남은 높이를 채우는 무대(홈·첫 실행)가 쓴다.
class MinIntrinsicHeight extends SingleChildRenderObjectWidget {
  const MinIntrinsicHeight({super.key, required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMinIntrinsicHeight(height);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderMinIntrinsicHeight).height = height;
}

class _RenderMinIntrinsicHeight extends RenderProxyBox {
  _RenderMinIntrinsicHeight(this._height);

  double _height;
  set height(double v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
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
