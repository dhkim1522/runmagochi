import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';

// 연두 무드보드(결정 0029) 값. 라이트는 design/mockups/phase-6/direction-c.md 그대로,
// 다크는 작업 10 에서 새로 정했다. docs/design/tokens.json 과 같아야 한다(아래 테스트).
const _light = {
  'background': 0xFFF3F5EE,
  'surface': 0xFFFFFFFF,
  'surfaceSoft': 0xFFE8ECE2,
  'line': 0xFFDDE3D4,
  'lineStrong': 0xFF737D6A,
  'ink': 0xFF16200F,
  'inkMuted': 0xFF5B6357,
  'primary': 0xFFB8F04A,
  'onPrimary': 0xFF14210A,
  'primaryEdge': 0xFF4F8A16,
  'primaryDeep': 0xFF1E7B45,
  'panel': 0xFF16200F,
  'onPanel': 0xFFFFFFFF,
  'stageInk': 0xFF0E5E33,
  'coin': 0xFF1E40AF,
  'onCoin': 0xFFFFFFFF,
  'success': 0xFF1E7B45,
  'danger': 0xFFB91C1C,
  'stageSky': 0xFFE3F6C8,
  'stageGround': 0xFFCDEBA8,
  'stageGroundLine': 0xFFB3DB82,
  'paceSlow': 0xFF3A75D6,
  'paceMid': 0xFF5C1A5C,
  'paceFast': 0xFFB35C00,
  'spriteRim': 0x00000000,
  'bubble': 0xFFFFFFFF,
};
const _dark = {
  'background': 0xFF10160D,
  'surface': 0xFF1A2316,
  'surfaceSoft': 0xFF28331F,
  'line': 0xFF2E3A28,
  'lineStrong': 0xFF7F8B74,
  'ink': 0xFFEEF4E6,
  'inkMuted': 0xFFA3AE99,
  'primary': 0xFFB8F04A,
  'onPrimary': 0xFF14210A,
  'primaryEdge': 0xFF8CC63A,
  'primaryDeep': 0xFF5DD08A,
  'panel': 0xFFE4EDD8,
  'onPanel': 0xFF16200F,
  'stageInk': 0xFFB6EE84,
  'coin': 0xFF8FAEFF,
  'onCoin': 0xFF10160D,
  'success': 0xFF5DD08A,
  'danger': 0xFFFF8A7A,
  'stageSky': 0xFF1D2C15,
  'stageGround': 0xFF2A3F1D,
  'stageGroundLine': 0xFF3E5C2A,
  'paceSlow': 0xFF4F7FE8,
  'paceMid': 0xFFF2C0FA,
  'paceFast': 0xFFB8641A,
  'spriteRim': 0xFFEEF4E6,
  'bubble': 0xFF44573A,
};

double _lin(double v) =>
    v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

// 색각 이상 흉내(Machado 2009, 강도 1.0, 선형 RGB).
const _cvd = {
  'protan': [
    [0.152286, 1.052583, -0.204868],
    [0.114503, 0.786281, 0.099216],
    [-0.003882, -0.048116, 1.051998],
  ],
  'deutan': [
    [0.367322, 0.860646, -0.227968],
    [0.280085, 0.672501, 0.047413],
    [-0.011820, 0.042940, 0.968881],
  ],
  'tritan': [
    [1.255528, -0.076749, -0.178779],
    [-0.078411, 0.930809, 0.147602],
    [0.004733, 0.691367, 0.303900],
  ],
};

/// 선형 RGB → CIELAB(D65).
List<double> _lab(List<double> rgb) {
  final [r, g, b] = [for (final v in rgb) v.clamp(0.0, 1.0)];
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

/// 두 색의 거리(ΔE76). [kind] 가 있으면 그 색각 이상으로 본 색끼리 잰다.
double _deltaE(Color a, Color b, [String? kind]) {
  List<double> see(Color c) {
    final l = [_lin(c.r), _lin(c.g), _lin(c.b)];
    if (kind == null) return l;
    final m = _cvd[kind]!;
    return [for (final row in m) row[0] * l[0] + row[1] * l[1] + row[2] * l[2]];
  }

  final la = _lab(see(a)), lb = _lab(see(b));
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

/// 두 색의 거리(CIEDE2000). [kind] 가 있으면 그 색각 이상(Machado 2009)으로 본 색끼리 잰다.
/// ΔE76 은 채도 차이를 부풀려 녹·주황처럼 적·녹 색각 이상에서 헷갈리는 짝도 15 를 넘긴다.
double _deltaE2000(Color a, Color b, [String? kind]) {
  List<double> see(Color c) {
    final l = [_lin(c.r), _lin(c.g), _lin(c.b)];
    if (kind == null) return l;
    final m = _cvd[kind]!;
    return [for (final row in m) row[0] * l[0] + row[1] * l[1] + row[2] * l[2]];
  }

  return _de2000Lab(_lab(see(a)), _lab(see(b)));
}

/// CIEDE2000(Sharma·Wu·Dalal 2005) 을 L*a*b* 두 값에 적용한다.
double _de2000Lab(List<double> lab1, List<double> lab2) {
  final [l1, a1, b1] = lab1;
  final [l2, a2, b2] = lab2;
  double rad(double d) => d * math.pi / 180;
  double deg(double r) => r * 180 / math.pi;
  final cBar =
      (math.sqrt(a1 * a1 + b1 * b1) + math.sqrt(a2 * a2 + b2 * b2)) / 2;
  final g =
      0.5 *
      (1 -
          math.sqrt(math.pow(cBar, 7) / (math.pow(cBar, 7) + math.pow(25, 7))));
  final a1p = (1 + g) * a1, a2p = (1 + g) * a2;
  final c1p = math.sqrt(a1p * a1p + b1 * b1),
      c2p = math.sqrt(a2p * a2p + b2 * b2);
  final h1p = (deg(math.atan2(b1, a1p)) + 360) % 360;
  final h2p = (deg(math.atan2(b2, a2p)) + 360) % 360;
  final dLp = l2 - l1, dCp = c2p - c1p;
  var dh = h2p - h1p;
  if (c1p * c2p == 0) {
    dh = 0;
  } else if (dh > 180) {
    dh -= 360;
  } else if (dh < -180) {
    dh += 360;
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(rad(dh / 2));
  final lBar = (l1 + l2) / 2, cBarP = (c1p + c2p) / 2;
  final double hBar;
  if (c1p * c2p == 0) {
    hBar = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBar = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBar = (h1p + h2p + 360) / 2;
  } else {
    hBar = (h1p + h2p - 360) / 2;
  }
  final t =
      1 -
      0.17 * math.cos(rad(hBar - 30)) +
      0.24 * math.cos(rad(2 * hBar)) +
      0.32 * math.cos(rad(3 * hBar + 6)) -
      0.20 * math.cos(rad(4 * hBar - 63));
  final dTheta = 30 * math.exp(-math.pow((hBar - 275) / 25, 2));
  final rc =
      2 *
      math.sqrt(math.pow(cBarP, 7) / (math.pow(cBarP, 7) + math.pow(25, 7)));
  final sl =
      1 +
      0.015 * math.pow(lBar - 50, 2) / math.sqrt(20 + math.pow(lBar - 50, 2));
  final sc = 1 + 0.045 * cBarP, sh = 1 + 0.015 * cBarP * t;
  final rt = -math.sin(rad(2 * dTheta)) * rc;
  return math.sqrt(
    math.pow(dLp / sl, 2) +
        math.pow(dCp / sc, 2) +
        math.pow(dHp / sh, 2) +
        rt * (dCp / sc) * (dHp / sh),
  );
}

Map<String, Color> _colors(AppColors c) => {
  'background': c.background,
  'surface': c.surface,
  'surfaceSoft': c.surfaceSoft,
  'line': c.line,
  'lineStrong': c.lineStrong,
  'ink': c.ink,
  'inkMuted': c.inkMuted,
  'primary': c.primary,
  'onPrimary': c.onPrimary,
  'primaryEdge': c.primaryEdge,
  'primaryDeep': c.primaryDeep,
  'panel': c.panel,
  'onPanel': c.onPanel,
  'stageInk': c.stageInk,
  'coin': c.coin,
  'onCoin': c.onCoin,
  'success': c.success,
  'danger': c.danger,
  'stageSky': c.stageSky,
  'stageGround': c.stageGround,
  'stageGroundLine': c.stageGroundLine,
  'paceSlow': c.paceSlow,
  'paceMid': c.paceMid,
  'paceFast': c.paceFast,
  'spriteRim': c.spriteRim,
  'bubble': c.bubble,
};

/// 글자 쌍(보통 글자): 4.5:1 이상. (글자 토큰, 바탕 토큰)
const _textPairs = [
  ('ink', 'background'),
  ('ink', 'surface'),
  ('ink', 'surfaceSoft'),
  ('ink', 'stageSky'),
  ('inkMuted', 'background'),
  ('inkMuted', 'surface'),
  ('inkMuted', 'surfaceSoft'),
  ('onPrimary', 'primary'),
  ('onPanel', 'panel'),
  ('primaryDeep', 'background'),
  ('primaryDeep', 'surface'),
  ('stageInk', 'stageSky'),
  ('ink', 'bubble'),
  ('coin', 'background'),
  ('coin', 'surface'),
  ('success', 'background'),
  ('success', 'surface'),
  ('danger', 'background'),
  ('danger', 'surface'),
];

/// 큰 글자(24px 이상) 쌍: 3:1 이상. 레벨 업 같은 초록 큰 글자가 무대 위에 놓일 때.
/// primaryDeep 은 stageSky 위에 큰 글자로만 쓴다(공통 컴포넌트는 무대 위에 작은 글자를
/// 만들지 않는다. 말풍선은 bubble 위 ink, 무대 위 작은 글자는 stageInk).
const _largeTextPairs = [('primaryDeep', 'stageSky'), ('ink', 'stageGround')];

// 채움 전용 쌍(글자로 쓰지 않아 글자 대비를 검사하지 않는다, 작업 11 확인):
// - stageSky 위 inkMuted: 무대 위 보조 글자는 없다. 무대 위 글자는 stageInk·ink.
// - surfaceSoft 위 primaryDeep: 진행 막대 채움(아래 그림 쌍 3:1). 트랙 위 글자는 ink 만.

/// 면 경계·그림 쌍(글자 아님): 3:1 이상.
const _graphicPairs = [
  // 연두 면은 바탕과 1.2:1 이라 primaryEdge 경계선이 대신 모양을 보인다.
  ('primaryEdge', 'background'),
  ('primaryEdge', 'surface'),
  ('primaryEdge', 'surfaceSoft'),
  // 흰 보조 버튼·스위치 테두리.
  ('lineStrong', 'background'),
  ('lineStrong', 'surface'),
  ('lineStrong', 'surfaceSoft'),
  // 어두운 판(일시정지·탭 선택)은 스스로 바탕과 떨어진다.
  ('panel', 'background'),
  ('panel', 'surface'),
  // 진행 막대 채움은 트랙 위.
  ('primaryDeep', 'surfaceSoft'),
  // 코인 그림 안 별.
  ('onCoin', 'coin'),
  // 경로 선은 흰 카드(또는 바탕) 위.
  ('paceSlow', 'surface'),
  ('paceMid', 'surface'),
  ('paceFast', 'surface'),
  ('paceSlow', 'background'),
  ('paceMid', 'background'),
  ('paceFast', 'background'),
];

void main() {
  _fontTests();
  _titleSTests();
  _tokensJsonTests();
  _formTests();
  final themes = {
    'light': (appLightTheme(), _light),
    'dark': (appDarkTheme(), _dark),
  };

  for (final e in themes.entries) {
    final (theme, expected) = e.value;
    group('${e.key} 테마', () {
      test('AppColors 확장이 있고 모든 토큰 HEX 가 기대값과 같다', () {
        final c = theme.extension<AppColors>();
        expect(c, isNotNull);
        final actual = _colors(c!);
        expect(actual.keys.toSet(), expected.keys.toSet());
        for (final k in expected.keys) {
          expect(actual[k], Color(expected[k]!), reason: k);
        }
      });

      test('ColorScheme 매핑', () {
        final s = theme.colorScheme;
        expect(s.primary, Color(expected['primary']!));
        expect(s.onPrimary, Color(expected['onPrimary']!));
        expect(s.secondary, Color(expected['panel']!));
        expect(s.onSecondary, Color(expected['onPanel']!));
        expect(s.surface, Color(expected['surface']!));
        expect(s.onSurface, Color(expected['ink']!));
        expect(s.onSurfaceVariant, Color(expected['inkMuted']!));
        expect(s.surfaceContainerHighest, Color(expected['surfaceSoft']!));
        expect(s.outline, Color(expected['lineStrong']!));
        expect(s.outlineVariant, Color(expected['line']!));
        expect(s.error, Color(expected['danger']!));
        expect(theme.scaffoldBackgroundColor, Color(expected['background']!));
        expect(
          theme.brightness,
          e.key == 'dark' ? Brightness.dark : Brightness.light,
        );
      });

      final c = theme.extension<AppColors>()!;
      final m = _colors(c);
      for (final (fg, bg) in _textPairs) {
        test('글자 $fg 가 $bg 위에서 4.5:1 이상', () {
          expect(_contrast(m[fg]!, m[bg]!), greaterThanOrEqualTo(4.5));
        });
      }
      for (final (fg, bg) in _largeTextPairs) {
        test('큰 글자 $fg 가 $bg 위에서 3:1 이상', () {
          expect(_contrast(m[fg]!, m[bg]!), greaterThanOrEqualTo(3));
        });
      }
      for (final (fg, bg) in _graphicPairs) {
        test('면·그림 $fg 가 $bg 와 3:1 이상', () {
          expect(_contrast(m[fg]!, m[bg]!), greaterThanOrEqualTo(3));
        });
      }

      test('경로 페이스 3색 + 빠른 이동(ink-muted)은 색각 이상(적·녹·청)에서도 서로 구분된다'
          '(Machado 2009 흉내, CIEDE2000 15 이상)', () {
        final pace = {
          'slow': c.paceSlow,
          'mid': c.paceMid,
          'fast': c.paceFast,
          'fastMove': c.inkMuted,
        };
        final names = pace.keys.toList();
        for (final kind in [null, 'protan', 'deutan', 'tritan']) {
          for (var i = 0; i < names.length; i++) {
            for (var j = i + 1; j < names.length; j++) {
              expect(
                _deltaE2000(pace[names[i]]!, pace[names[j]]!, kind),
                greaterThanOrEqualTo(15),
                reason: '${kind ?? 'normal'} ${names[i]}-${names[j]}',
              );
            }
          }
        }
      });

      test('CIEDE2000 계산 확인: Sharma 2005 표 1번 짝 = 2.0425', () {
        // L*a*b* (50, 2.6772, -79.7751) vs (50, 0, -82.7485). 같은 식을 Lab 에 바로 적용.
        expect(
          _de2000Lab([50, 2.6772, -79.7751], [50, 0, -82.7485]),
          closeTo(2.0425, 1e-4),
        );
      });

      test('onError 가 error 위에서 4.5:1 이상', () {
        expect(
          _contrast(theme.colorScheme.onError, theme.colorScheme.error),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('TextButton 글자색(primaryDeep)이 surface 위에서 4.5:1 이상', () {
        final fg = theme.textButtonTheme.style!.foregroundColor!.resolve({})!;
        expect(fg, c.primaryDeep);
        expect(_contrast(fg, c.surface), greaterThanOrEqualTo(4.5));
      });

      test('다이얼로그: 모서리 radius-lg, 제목 title 스타일', () {
        final tx = theme.extension<AppText>()!;
        final d = theme.dialogTheme;
        expect(d.backgroundColor, c.surface);
        expect(
          (d.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(Radii.lg),
        );
        expect(d.titleTextStyle, tx.title);
        expect(d.contentTextStyle, tx.body);
      });
    });
  }

  group('다크 모드', () {
    const l = AppColors.light, d = AppColors.dark;
    test('반전이 아니라 같은 정체성: 연두 primary 는 그대로, 바탕은 풀빛 어둠', () {
      expect(d.primary, l.primary);
      expect(d.onPrimary, l.onPrimary);
      expect(_lum(d.background), lessThan(0.02));
      // 초록 기운: g 채널이 r·b 보다 크다.
      for (final bg in [d.background, d.surface, d.stageSky]) {
        expect(bg.g, greaterThan(bg.r));
        expect(bg.g, greaterThan(bg.b));
      }
    });
    test('카드·트랙이 바탕보다 한 단계씩 밝다(테두리 없이 톤으로 떨어진다)', () {
      expect(_lum(d.surface), greaterThan(_lum(d.background)));
      expect(_lum(d.surfaceSoft), greaterThan(_lum(d.surface)));
      expect(_lum(l.surface), greaterThan(_lum(l.background)));
    });
    test('말풍선 바탕은 두 테마 모두 무대 하늘과 ΔE76 15 이상 떨어진다(작업 12)', () {
      // 다크 surface 는 하늘과 ΔE 8 이라 말풍선 모양·꼬리가 묻혔다. 그래서 bubble 토큰을 따로 둔다.
      for (final c in [l, d]) {
        expect(_deltaE(c.bubble, c.stageSky), greaterThanOrEqualTo(15));
      }
      expect(l.bubble, l.surface);
    });
    test('다크 스프라이트 윤곽은 보이고 라이트는 투명', () {
      expect(l.spriteRim.a, 0);
      expect(d.spriteRim.a, 1);
      expect(_contrast(d.spriteRim, d.stageSky), greaterThanOrEqualTo(4.5));
    });
  });

  test('AppColors copyWith·lerp', () {
    const a = AppColors.light, b = AppColors.dark;
    expect(
      a.copyWith(background: const Color(0xFF000000)).background,
      const Color(0xFF000000),
    );
    expect(a.copyWith().paceFast, a.paceFast);
    expect(a.lerp(b, 0).ink, a.ink);
    expect(a.lerp(b, 1).background, b.background);
    expect(a.lerp(b, 1).stageGroundLine, b.stageGroundLine);
  });

  test('Gap·Radii·Borders 값', () {
    expect(
      [Gap.s1, Gap.s2, Gap.s3, Gap.s4, Gap.s5, Gap.s6, Gap.s7, Gap.s8],
      [4, 8, 12, 16, 20, 24, 28, 32],
    );
    expect(
      [Radii.sm, Radii.md, Radii.lg, Radii.xl, Radii.pill],
      [12, 20, 24, 28, 999],
    );
    expect(Borders.edge, 2);
    expect(Borders.groundLine, 4);
    expect(Borders.focus, 3);
  });

  test('사각 무대 치수: 모서리 24(카드 안 20), 땅 띠 56·40, 발 8 묻힘', () {
    expect(Stage.radius, Radii.lg);
    expect(Stage.radiusInCard, Radii.md);
    expect(Stage.groundHeight, 56);
    expect(Stage.groundHeightCompact, 40);
    expect(Stage.groundHeightMini, 24);
    expect(Stage.footSink, 8);
    // 작은 무대(2·3배)도 발이 묻히고 윗선이 보인다.
    expect(
      Stage.groundHeightMini,
      greaterThan(Borders.groundLine + Stage.footSink),
    );
    expect(
      Stage.groundHeight,
      greaterThan(Borders.groundLine + Stage.footSink),
    );
  });

  test('움직임 토큰: 나가기가 들어오기보다 짧고(60~70%), 누름은 100ms 이하', () {
    expect(Motion.press.inMilliseconds, lessThanOrEqualTo(100));
    expect(Motion.quick, greaterThan(Motion.press));
    expect(Motion.enter, greaterThan(Motion.quick));
    final ratio = Motion.exit.inMilliseconds / Motion.enter.inMilliseconds;
    expect(ratio, inInclusiveRange(0.6, 0.7));
    expect(Motion.celebrate, greaterThan(Motion.enter));
    // 들어올 때 감속, 나갈 때 가속.
    expect(Motion.enterCurve.transform(0.5), greaterThan(0.5));
    expect(Motion.exitCurve.transform(0.5), lessThan(0.5));
    expect(Motion.standard.transform(0), 0);
    expect(Motion.standard.transform(1), 1);
    // 튀어 오름은 끝에서 살짝 넘친다.
    final peak = [
      for (var t = 0.0; t <= 1; t += 0.05) Motion.pop.transform(t),
    ].reduce(math.max);
    expect(peak, greaterThan(1));
  });
}

void _fontTests() {
  for (final t in [appLightTheme(), appDarkTheme()]) {
    final tx = t.extension<AppText>()!;
    final all = {
      'distanceXl': tx.distanceXl,
      'numberL': tx.numberL,
      'title': tx.title,
      'titleS': tx.titleS,
      'stat': tx.stat,
      'button': tx.button,
      'heading': tx.heading,
      'body': tx.body,
      'bodyStrong': tx.bodyStrong,
      'label': tx.label,
      'caption': tx.caption,
    };
    test(
      '모든 글자 스타일은 RunmagochiSans(Pretendard 서브셋) 한 가족, 13 이상, wght 축 = fontWeight',
      () {
        expect(t.textTheme.bodyMedium!.fontFamily, 'RunmagochiSans');
        for (final MapEntry(:key, :value) in all.entries) {
          expect(value.fontFamily, 'RunmagochiSans', reason: key);
          expect(value.fontSize, greaterThanOrEqualTo(13), reason: key);
          expect(value.fontVariations, [
            FontVariation('wght', value.fontWeight!.value.toDouble()),
          ], reason: key);
        }
      },
    );
    test('글자 크기·굵기(direction-c)', () {
      const want = {
        'distanceXl': (128.0, 128.0, FontWeight.w800),
        'numberL': (64.0, 68.0, FontWeight.w800),
        'title': (26.0, 32.0, FontWeight.w800),
        'titleS': (22.0, 28.0, FontWeight.w700),
        'stat': (22.0, 28.0, FontWeight.w800),
        'button': (22.0, 28.0, FontWeight.w700),
        'heading': (17.0, 24.0, FontWeight.w800),
        'body': (17.0, 24.0, FontWeight.w500),
        'bodyStrong': (17.0, 24.0, FontWeight.w700),
        'label': (14.0, 20.0, FontWeight.w600),
        'caption': (13.0, 18.0, FontWeight.w600),
      };
      for (final MapEntry(:key, value: (size, line, weight)) in want.entries) {
        final s = all[key]!;
        expect(s.fontSize, size, reason: key);
        expect(s.height! * s.fontSize!, closeTo(line, 1e-9), reason: key);
        expect(s.fontWeight, weight, reason: key);
      }
    });
    test('숫자 스타일은 고정폭 숫자·좁은 자간(-0.02em 이하)', () {
      for (final s in [tx.distanceXl, tx.numberL, tx.stat]) {
        expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(s.letterSpacing!, lessThanOrEqualTo(-0.02 * s.fontSize!));
      }
      expect(tx.distanceXl.letterSpacing, closeTo(-0.04 * 128, 1e-9));
    });
  }

  test('pubspec 은 RunmagochiSans(Pretendard 서브셋) 하나만 번들하고 옛 글꼴은 없다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    // OFL 예약 글꼴 이름: 고친(서브셋) 글꼴은 파일·가족 이름에도 Pretendard 를 쓰지 않는다.
    expect(pubspec, contains('family: RunmagochiSans'));
    expect(pubspec, contains('asset: assets/fonts/RunmagochiSans.ttf'));
    expect(pubspec, isNot(contains('family: Pretendard')));
    expect(pubspec, isNot(contains('assets/fonts/PretendardVariable.ttf')));
    expect(pubspec, isNot(contains('Jua')));
    expect(pubspec, isNot(contains('NotoSansKR')));
    final ttf = File('assets/fonts/RunmagochiSans.ttf');
    expect(ttf.existsSync(), isTrue);
    // TrueType 시그니처 00 01 00 00.
    expect(ttf.openSync().readSync(4), [0, 1, 0, 0]);
    final ofl = File('assets/fonts/OFL-Pretendard.txt').readAsStringSync();
    expect(ofl, contains('SIL Open Font License'));
    final left = Directory('assets/fonts')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where(
          (n) =>
              n.contains('Jua') ||
              n.contains('NotoSans') ||
              (n.endsWith('.ttf') && n.contains('Pretendard')),
        );
    expect(left, isEmpty);
  });
}

void _titleSTests() {
  group('글자 크기 22 토큰', () {
    test('titleS 는 RunmagochiSans 22 / 줄 높이 28', () {
      for (final tx in [
        AppText.withColor(AppColors.light.ink),
        AppText.withColor(AppColors.dark.ink),
      ]) {
        expect(tx.titleS.fontSize, 22);
        expect(tx.titleS.fontFamily, 'RunmagochiSans');
        expect(tx.titleS.height, closeTo(28 / 22, 1e-9));
      }
      final a = AppText.withColor(AppColors.light.ink);
      expect(a.copyWith().titleS, a.titleS);
      expect(a.lerp(a, 0.5).titleS.fontSize, 22);
    });
    test('theme.dart 밖 lib 코드에 fontSize: 22 가 없다', () {
      final hits = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.replaceAll(r'\', '/').endsWith('lib/core/theme.dart')) {
          continue;
        }
        if (f.readAsStringSync().contains('fontSize: 22')) hits.add(f.path);
      }
      expect(hits, isEmpty);
    });
  });
}

String _camel(String kebab) {
  final p = kebab.split('-');
  return p.first +
      p.skip(1).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}

int _hex(String v) => v == 'transparent'
    ? 0x00000000
    : int.parse('FF${v.substring(1)}', radix: 16);

void _tokensJsonTests() {
  final json =
      jsonDecode(File('docs/design/tokens.json').readAsStringSync())
          as Map<String, dynamic>;
  test('tokens.json 색 토큰이 theme.dart 와 같다(라이트·다크 모두 값이 있다)', () {
    final tokens = (json['color'] as Map)['tokens'] as List;
    final names = <String>{};
    for (final t in tokens.cast<Map<String, dynamic>>()) {
      final name = _camel(t['name'] as String);
      names.add(name);
      final v = t['value'] as Map<String, dynamic>;
      expect(v.keys.toSet(), {'light', 'dark'}, reason: name);
      expect(
        Color(_hex(v['light'] as String)),
        Color(_light[name]!),
        reason: name,
      );
      expect(
        Color(_hex(v['dark'] as String)),
        Color(_dark[name]!),
        reason: name,
      );
    }
    expect(names, _light.keys.toSet());
  });
  test('tokens.json 글꼴은 Pretendard, 간격·움직임 토큰이 theme.dart 와 같다', () {
    final fam = ((json['type'] as Map)['families'] as Map).values.join(' ');
    expect(fam, contains('Pretendard'));
    expect(fam, isNot(contains('Jua')));
    final space = {
      for (final t in ((json['spacing'] as Map)['tokens'] as List).cast<Map>())
        t['name']: t['value'],
    };
    expect(space['space-7'], '28px');
    final motion = {
      for (final t in ((json['motion'] as Map)['tokens'] as List).cast<Map>())
        t['name']: t['value'],
    };
    expect(motion['duration-press'], '${Motion.press.inMilliseconds}ms');
    expect(motion['duration-quick'], '${Motion.quick.inMilliseconds}ms');
    expect(motion['duration-enter'], '${Motion.enter.inMilliseconds}ms');
    expect(motion['duration-exit'], '${Motion.exit.inMilliseconds}ms');
    expect(
      motion['duration-celebrate'],
      '${Motion.celebrate.inMilliseconds}ms',
    );
  });
  test('tokens.json 선 두께가 theme.dart 와 같고 옛 클레이 립·테두리는 없다', () {
    final border = {
      for (final t in ((json['border'] as Map)['tokens'] as List).cast<Map>())
        t['name']: t['value'],
    };
    expect(border, {
      'border-edge': '${Borders.edge.round()}px',
      'border-ground-line': '${Borders.groundLine.round()}px',
      'border-focus': '${Borders.focus.round()}px',
    });
  });
}

/// 작업 15: 입력칸·스위치·진행 표시·스낵바·화면 전환도 토큰으로 테마가 정한다.
void _formTests() {
  for (final (name, theme, c) in [
    ('라이트', appLightTheme(), AppColors.light),
    ('다크', appDarkTheme(), AppColors.dark),
  ]) {
    final tx = theme.extension<AppText>()!;
    group('작업 15 테마 ($name)', () {
      OutlineInputBorder outline(InputBorder? b) => b! as OutlineInputBorder;

      test(
        '입력칸: surface 채움, lineStrong 2 경계, 포커스 primaryDeep 3, 오류 danger',
        () {
          final d = theme.inputDecorationTheme;
          expect(d.filled, isTrue);
          expect(d.fillColor, c.surface);
          for (final b in [d.border, d.enabledBorder]) {
            expect(outline(b).borderSide.color, c.lineStrong);
            expect(outline(b).borderSide.width, Borders.edge);
            expect(outline(b).borderRadius, BorderRadius.circular(Radii.md));
          }
          expect(outline(d.focusedBorder).borderSide.color, c.primaryDeep);
          expect(outline(d.focusedBorder).borderSide.width, Borders.focus);
          expect(outline(d.errorBorder).borderSide.color, c.danger);
          expect(outline(d.focusedErrorBorder).borderSide.color, c.danger);
          expect(outline(d.focusedErrorBorder).borderSide.width, Borders.focus);
          expect(d.helperStyle!.color, c.inkMuted);
          expect(d.helperStyle!.fontSize, tx.caption.fontSize);
          expect(d.errorStyle!.color, c.danger);
          expect(d.counterStyle!.color, c.inkMuted);
          // 입력 경계는 바탕·카드 모두와 3:1 이상(면 경계).
          expect(_contrast(c.lineStrong, c.surface), greaterThanOrEqualTo(3));
          expect(
            _contrast(c.lineStrong, c.background),
            greaterThanOrEqualTo(3),
          );
        },
      );

      test('커서·선택 손잡이는 primaryDeep (연두는 흰 판 위에서 안 보인다)', () {
        final s = theme.textSelectionTheme;
        expect(s.cursorColor, c.primaryDeep);
        expect(s.selectionHandleColor, c.primaryDeep);
        expect(_contrast(c.primaryDeep, c.surface), greaterThanOrEqualTo(3));
      });

      test('진행 표시는 primaryDeep', () {
        expect(theme.progressIndicatorTheme.color, c.primaryDeep);
      });

      test('스위치: 켜짐 연두 + primaryEdge 경계, 꺼짐 surfaceSoft + lineStrong 경계', () {
        final s = theme.switchTheme;
        const on = {WidgetState.selected};
        const off = <WidgetState>{};
        expect(s.trackColor!.resolve(on), c.primary);
        expect(s.trackOutlineColor!.resolve(on), c.primaryEdge);
        expect(s.thumbColor!.resolve(on), c.onPrimary);
        expect(s.trackColor!.resolve(off), c.surfaceSoft);
        expect(s.trackOutlineColor!.resolve(off), c.lineStrong);
        expect(s.thumbColor!.resolve(off), c.inkMuted);
        expect(s.trackOutlineWidth!.resolve(off), Borders.edge);
      });

      test('스낵바: 어두운 판(panel) + onPanel 본문, 아래 띠(위 모서리 radius-md), 그림자 없음', () {
        final s = theme.snackBarTheme;
        expect(s.backgroundColor, c.panel);
        expect(s.contentTextStyle!.color, c.onPanel);
        expect(s.contentTextStyle!.fontSize, tx.body.fontSize);
        expect(s.actionTextColor, c.onPanel);
        expect(s.behavior, SnackBarBehavior.fixed);
        expect(s.elevation, 0);
        expect(
          (s.shape! as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(Radii.md)),
        );
        expect(_contrast(c.onPanel, c.panel), greaterThanOrEqualTo(4.5));
      });

      test('Android 화면 전환은 앱 전환(들어오기 enter, 나가기 exit)', () {
        final b = theme.pageTransitionsTheme.builders[TargetPlatform.android];
        expect(b, isA<AppPageTransitionsBuilder>());
        expect(b!.transitionDuration, Motion.enter);
        expect(b.reverseTransitionDuration, Motion.exit);
      });
    });
  }
}
