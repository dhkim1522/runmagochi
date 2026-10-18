import 'package:flutter/material.dart';

/// 디자인 값(색·글자·간격·모서리)의 유일한 출처. 기준: docs/design/tokens.json
/// 화면 코드는 `Color(0x…)`·`Colors.xxx` 대신 아래 토큰만 읽는다.
///
/// 사용법
/// - 색: `AppColors.of(context)`
/// - 글자: `AppText.of(context).distanceXl` (색은 ink, 바꾸려면 copyWith(color:))
/// - 간격·모서리·테두리: `Gap.s4`, `Radii.lg`, `Borders.thick`

/// 간격 토큰. `sN` 은 tokens.json 의 `space-N`.
class Gap {
  Gap._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
}

/// 모서리 토큰.
class Radii {
  Radii._();
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

/// 테두리·립 두께.
class Borders {
  Borders._();

  /// 카드·무대 테두리(line 색).
  static const double thick = 3;

  /// 버튼·카드 아래 입체 립 두께.
  static const double lip = 6;

  /// 누른 상태의 립 두께.
  static const double lipPressed = 2;
}

/// Material ColorScheme 슬롯이 없는 토큰까지 모두 담은 색 확장.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.cream,
    required this.surface,
    required this.surfaceSoft,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkMuted,
    required this.primary,
    required this.onPrimary,
    required this.primaryDeep,
    required this.accent,
    required this.onAccent,
    required this.accentDeep,
    required this.success,
    required this.danger,
  });

  final Color cream;
  final Color surface;
  final Color surfaceSoft;
  final Color line;
  final Color lineStrong;
  final Color ink;
  final Color inkMuted;
  final Color primary;
  final Color onPrimary;
  final Color primaryDeep;
  final Color accent;
  final Color onAccent;
  final Color accentDeep;
  final Color success;
  final Color danger;

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>()!;

  static const light = AppColors(
    cream: Color(0xFFFFF7ED),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFFFEDD5),
    line: Color(0xFFFED7AA),
    lineStrong: Color(0xFFFDBA74),
    ink: Color(0xFF431407),
    inkMuted: Color(0xFF9A3412),
    primary: Color(0xFFF97316),
    onPrimary: Color(0xFF1C0A00),
    primaryDeep: Color(0xFFC2410C),
    accent: Color(0xFF2563EB),
    onAccent: Color(0xFFFFFFFF),
    accentDeep: Color(0xFF1E40AF),
    success: Color(0xFF15803D),
    danger: Color(0xFFB91C1C),
  );

  static const dark = AppColors(
    cream: Color(0xFF1C1410),
    surface: Color(0xFF2A1F18),
    surfaceSoft: Color(0xFF3A2A1F),
    line: Color(0xFF5A3B24),
    lineStrong: Color(0xFF120C08),
    ink: Color(0xFFFFEDD5),
    inkMuted: Color(0xFFFDBA74),
    primary: Color(0xFFFB923C),
    onPrimary: Color(0xFF1C0A00),
    primaryDeep: Color(0xFFEA580C),
    accent: Color(0xFF60A5FA),
    onAccent: Color(0xFF0B1220),
    accentDeep: Color(0xFF3B82F6),
    success: Color(0xFF4ADE80),
    danger: Color(0xFFF87171),
  );

  @override
  AppColors copyWith({
    Color? cream,
    Color? surface,
    Color? surfaceSoft,
    Color? line,
    Color? lineStrong,
    Color? ink,
    Color? inkMuted,
    Color? primary,
    Color? onPrimary,
    Color? primaryDeep,
    Color? accent,
    Color? onAccent,
    Color? accentDeep,
    Color? success,
    Color? danger,
  }) {
    return AppColors(
      cream: cream ?? this.cream,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      line: line ?? this.line,
      lineStrong: lineStrong ?? this.lineStrong,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDeep: primaryDeep ?? this.primaryDeep,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentDeep: accentDeep ?? this.accentDeep,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      cream: l(cream, other.cream),
      surface: l(surface, other.surface),
      surfaceSoft: l(surfaceSoft, other.surfaceSoft),
      line: l(line, other.line),
      lineStrong: l(lineStrong, other.lineStrong),
      ink: l(ink, other.ink),
      inkMuted: l(inkMuted, other.inkMuted),
      primary: l(primary, other.primary),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryDeep: l(primaryDeep, other.primaryDeep),
      accent: l(accent, other.accent),
      onAccent: l(onAccent, other.onAccent),
      accentDeep: l(accentDeep, other.accentDeep),
      success: l(success, other.success),
      danger: l(danger, other.danger),
    );
  }
}

const _display = 'Jua';
const _bodyFont = 'NotoSansKR';

TextStyle _s(
  String family,
  double size,
  double height,
  FontWeight w,
  Color c,
) => TextStyle(
  fontFamily: family,
  fontSize: size,
  height: height / size,
  fontWeight: w,
  // 가변 글꼴(NotoSansKR)은 fontWeight 만으로 wght 축이 보장되지 않아 함께 지정한다.
  fontVariations: family == _bodyFont
      ? [FontVariation('wght', w.value.toDouble())]
      : null,
  color: c,
);

/// 글자 스타일 토큰(tokens.json 의 type). 색은 테마의 ink.
/// 화면에서는 `AppText.of(context).stat` 처럼 쓴다.
@immutable
class AppText extends ThemeExtension<AppText> {
  const AppText({
    required this.distanceXl,
    required this.numberL,
    required this.title,
    required this.stat,
    required this.button,
    required this.heading,
    required this.body,
    required this.bodyStrong,
    required this.label,
    required this.caption,
  });

  /// [ink] 색으로 모든 스타일을 만든다.
  factory AppText.withColor(Color ink) => AppText(
    distanceXl: _s(_display, 120, 120, FontWeight.w400, ink),
    numberL: _s(_display, 64, 68, FontWeight.w400, ink),
    title: _s(_display, 28, 34, FontWeight.w400, ink),
    stat: _s(_display, 26, 30, FontWeight.w400, ink),
    button: _s(_display, 24, 28, FontWeight.w400, ink),
    heading: _s(_display, 18, 24, FontWeight.w400, ink),
    body: _s(_bodyFont, 16, 24, FontWeight.w400, ink),
    bodyStrong: _s(_bodyFont, 16, 24, FontWeight.w700, ink),
    label: _s(_bodyFont, 14, 20, FontWeight.w700, ink),
    caption: _s(_bodyFont, 13, 18, FontWeight.w500, ink),
  );

  final TextStyle distanceXl;
  final TextStyle numberL;
  final TextStyle title;
  final TextStyle stat;
  final TextStyle button;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;

  static AppText of(BuildContext context) =>
      Theme.of(context).extension<AppText>()!;

  @override
  AppText copyWith({
    TextStyle? distanceXl,
    TextStyle? numberL,
    TextStyle? title,
    TextStyle? stat,
    TextStyle? button,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? bodyStrong,
    TextStyle? label,
    TextStyle? caption,
  }) {
    return AppText(
      distanceXl: distanceXl ?? this.distanceXl,
      numberL: numberL ?? this.numberL,
      title: title ?? this.title,
      stat: stat ?? this.stat,
      button: button ?? this.button,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      bodyStrong: bodyStrong ?? this.bodyStrong,
      label: label ?? this.label,
      caption: caption ?? this.caption,
    );
  }

  @override
  AppText lerp(ThemeExtension<AppText>? other, double t) {
    if (other is! AppText) return this;
    TextStyle l(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppText(
      distanceXl: l(distanceXl, other.distanceXl),
      numberL: l(numberL, other.numberL),
      title: l(title, other.title),
      stat: l(stat, other.stat),
      button: l(button, other.button),
      heading: l(heading, other.heading),
      body: l(body, other.body),
      bodyStrong: l(bodyStrong, other.bodyStrong),
      label: l(label, other.label),
      caption: l(caption, other.caption),
    );
  }
}

ThemeData appLightTheme() => _build(AppColors.light, Brightness.light);

ThemeData appDarkTheme() => _build(AppColors.dark, Brightness.dark);

/// Material 매핑
/// - scaffold 배경 = cream, 카드·다이얼로그 = surface
/// - primary/onPrimary = primary/on-primary, secondary/onSecondary = accent/on-accent
/// - onSurface = ink, onSurfaceVariant = ink-muted
/// - onError = surface(라이트)·cream(다크): danger 위 글자, 대비 4.5 이상(테스트)
/// - surfaceContainerHighest = surface-soft, outline = line, error = danger
/// 나머지 토큰(lineStrong, primaryDeep, accentDeep, success)은 [AppColors] 로 읽는다.
ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.danger,
    onError: brightness == Brightness.light ? c.surface : c.cream,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    surfaceContainerHighest: c.surfaceSoft,
    outline: c.line,
    outlineVariant: c.line,
  );
  final text = AppText.withColor(c.ink);
  // 글자 버튼은 primary-deep (양 테마 모두 surface 위 대비 4.5 이상, 테스트로 보장).
  final textButtonColor = c.primaryDeep;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.cream,
    fontFamily: _bodyFont,
    textTheme: TextTheme(
      displayLarge: text.distanceXl,
      displayMedium: text.numberL,
      headlineMedium: text.title,
      headlineSmall: text.stat,
      titleLarge: text.button,
      titleMedium: text.heading,
      bodyLarge: text.body,
      bodyMedium: text.body,
      bodySmall: text.caption,
      labelLarge: text.label,
      labelMedium: text.label,
      labelSmall: text.caption,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      titleTextStyle: text.title,
      contentTextStyle: text.body,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textButtonColor,
        textStyle: text.label,
      ),
    ),
    extensions: [c, text],
  );
}
