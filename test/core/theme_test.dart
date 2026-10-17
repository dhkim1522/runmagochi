import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';

// docs/design/tokens.json 의 값을 그대로 옮긴 기대값.
const _light = {
  'cream': 0xFFFFF7ED,
  'surface': 0xFFFFFFFF,
  'surfaceSoft': 0xFFFFEDD5,
  'line': 0xFFFED7AA,
  'lineStrong': 0xFFFDBA74,
  'ink': 0xFF431407,
  'inkMuted': 0xFF9A3412,
  'primary': 0xFFF97316,
  'onPrimary': 0xFF1C0A00,
  'primaryDeep': 0xFFC2410C,
  'accent': 0xFF2563EB,
  'onAccent': 0xFFFFFFFF,
  'accentDeep': 0xFF1E40AF,
  'success': 0xFF15803D,
  'danger': 0xFFB91C1C,
};
const _dark = {
  'cream': 0xFF1C1410,
  'surface': 0xFF2A1F18,
  'surfaceSoft': 0xFF3A2A1F,
  'line': 0xFF5A3B24,
  'lineStrong': 0xFF120C08,
  'ink': 0xFFFFEDD5,
  'inkMuted': 0xFFFDBA74,
  'primary': 0xFFFB923C,
  'onPrimary': 0xFF1C0A00,
  'primaryDeep': 0xFFEA580C,
  'accent': 0xFF60A5FA,
  'onAccent': 0xFF0B1220,
  'accentDeep': 0xFF3B82F6,
  'success': 0xFF4ADE80,
  'danger': 0xFFF87171,
};

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Map<String, Color> _colors(AppColors c) => {
  'cream': c.cream,
  'surface': c.surface,
  'surfaceSoft': c.surfaceSoft,
  'line': c.line,
  'lineStrong': c.lineStrong,
  'ink': c.ink,
  'inkMuted': c.inkMuted,
  'primary': c.primary,
  'onPrimary': c.onPrimary,
  'primaryDeep': c.primaryDeep,
  'accent': c.accent,
  'onAccent': c.onAccent,
  'accentDeep': c.accentDeep,
  'success': c.success,
  'danger': c.danger,
};

void main() {
  _fontAndErrorTests();
  final themes = {
    'light': (appLightTheme(), _light),
    'dark': (appDarkTheme(), _dark),
  };

  for (final e in themes.entries) {
    final (theme, expected) = e.value;
    group('${e.key} 테마', () {
      test('AppColors 확장이 있고 토큰 HEX 가 tokens.json 과 같다', () {
        final c = theme.extension<AppColors>();
        expect(c, isNotNull);
        final actual = _colors(c!);
        for (final k in expected.keys) {
          expect(actual[k], Color(expected[k]!), reason: k);
        }
      });

      test('ColorScheme 매핑', () {
        final s = theme.colorScheme;
        expect(s.primary, Color(expected['primary']!));
        expect(s.onPrimary, Color(expected['onPrimary']!));
        expect(s.secondary, Color(expected['accent']!));
        expect(s.onSecondary, Color(expected['onAccent']!));
        expect(s.surface, Color(expected['surface']!));
        expect(s.onSurface, Color(expected['ink']!));
        expect(s.surfaceContainerHighest, Color(expected['surfaceSoft']!));
        expect(s.outline, Color(expected['line']!));
        expect(s.error, Color(expected['danger']!));
        expect(theme.scaffoldBackgroundColor, Color(expected['cream']!));
        expect(
          theme.brightness,
          e.key == 'dark' ? Brightness.dark : Brightness.light,
        );
      });

      test('글꼴 family 는 번들 글꼴 이름', () {
        expect(theme.textTheme.bodyMedium!.fontFamily, 'NotoSansKR');
        final t = theme.extension<AppText>()!;
        expect(t.distanceXl.fontFamily, 'Jua');
        expect(t.body.fontFamily, 'NotoSansKR');
        expect(t.distanceXl.fontSize, 120);
        expect(t.numberL.fontSize, 64);
        expect(t.title.fontSize, 28);
        expect(t.stat.fontSize, 26);
        expect(t.button.fontSize, 24);
        expect(t.heading.fontSize, 18);
        expect(t.body.fontSize, 16);
        expect(t.bodyStrong.fontWeight, FontWeight.w700);
        expect(t.label.fontSize, 14);
        expect(t.caption.fontSize, 13);
        expect(t.caption.fontWeight, FontWeight.w500);
      });

      test('ink·inkMuted 가 cream·surface 위에서 대비 4.5 이상', () {
        final c = theme.extension<AppColors>()!;
        for (final bg in [c.cream, c.surface]) {
          expect(_contrast(c.ink, bg), greaterThanOrEqualTo(4.5));
          expect(_contrast(c.inkMuted, bg), greaterThanOrEqualTo(4.5));
        }
        expect(
          _contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5),
        );
      });
    });
  }

  test('AppColors copyWith·lerp', () {
    final a = appLightTheme().extension<AppColors>()!;
    final b = appDarkTheme().extension<AppColors>()!;
    expect(
      a.copyWith(cream: const Color(0xFF000000)).cream,
      const Color(0xFF000000),
    );
    expect(a.lerp(b, 0).ink, a.ink);
    expect(a.lerp(b, 1).cream, b.cream);
  });

  test('Gap·Radii 값', () {
    expect(
      [Gap.s1, Gap.s2, Gap.s3, Gap.s4, Gap.s5, Gap.s6, Gap.s8],
      [4, 8, 12, 16, 20, 24, 32],
    );
    expect(
      [Radii.sm, Radii.md, Radii.lg, Radii.xl, Radii.pill],
      [12, 20, 24, 32, 999],
    );
    expect(Borders.thick, 3);
    expect(Borders.lip, 6);
  });
}

void _fontAndErrorTests() {
  for (final t in [appLightTheme(), appDarkTheme()]) {
    final tx = t.extension<AppText>()!;
    test('본문 스타일은 fontWeight 와 같은 wght FontVariation 을 가진다', () {
      for (final s in [tx.body, tx.bodyStrong, tx.label, tx.caption]) {
        expect(s.fontVariations, [
          FontVariation('wght', s.fontWeight!.value.toDouble()),
        ]);
      }
    });
    test('onError 가 error 위에서 대비 4.5 이상', () {
      expect(
        _contrast(t.colorScheme.onError, t.colorScheme.error),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}
