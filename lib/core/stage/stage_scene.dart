import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../theme.dart';

/// 사각 무대 배경 한 벌: 아래부터 하늘 → 먼 풍경 → 땅·길 → 앞 장식 네 겹(작업 25).
///
/// 겹은 한 점 투시로 그린다. 소실점은 펫 몸 뒤 지평선 위에 있고, 러닝 중에는 땅·길 무늬와
/// 길가 물체가 소실점 쪽으로 물러난다([flowSpeed]). 하늘·먼 풍경은 멈춰 있다.
/// 상점 배경 아이템은 겹 단위로 바꾼다: 다른 [StageScene] 을 만들어 `PetStage.scene` 에 준다.
/// 그림 원본은 `design/mockups/phase-6/stage-background/gen.py` (투시 식·색·속도).
@immutable
class StageScene {
  const StageScene({
    required this.name,
    required this.sky,
    required this.far,
    required this.ground,
    required this.roadside,
    this.period = 2,
    this.flowSpeed = 0.5,
    this.stepsPerPeriod = 32,
  });

  /// 배경 이름(테스트·디버그용).
  final String name;

  /// 1 하늘: 무대 전체 바탕. 위쪽 절반은 말풍선·날씨 자리로 비운다.
  final StageLayer sky;

  /// 2 먼 풍경: 지평선 위 띠. 멈춰 있다.
  final StageLayer far;

  /// 3 땅·길: 지평선 아래 바닥 면 전체(풀·길·무늬).
  final StageLayer ground;

  /// 4 앞 장식: 길가 물체. 그리는 순서는 펫 뒤다(펫보다 가까운 물체는 화면 좌우 끝에 있어
  /// 펫과 겹치지 않는다). 펫 앞에 와야 할 아이템이 생기면 5번째 겹을 따로 둔다.
  final StageLayer roadside;

  /// 흐르는 무늬가 되풀이되는 세상 깊이(카메라 높이 단위).
  final double period;

  /// 러닝 중 무늬가 물러나는 속도(카메라 높이 단위/초).
  final double flowSpeed;

  /// 한 [period] 를 몇 장으로 끊어 그리는가. 32장·4초 한 바퀴 = 초당 8장(도트 느낌, 배터리).
  final int stepsPerPeriod;

  /// 아래부터 그리는 순서.
  List<StageLayer> get layers => [sky, far, ground, roadside];

  /// [step] 번 장의 이동량(세상 깊이).
  double offsetAt(int step) => step * period / stepsPerPeriod;

  /// 러닝 시작부터 [seconds] 초 뒤의 장 번호.
  int stepAt(double seconds) {
    final steps = (seconds * flowSpeed * stepsPerPeriod / period).floor();
    return steps % stepsPerPeriod;
  }

  /// 멈춘 부분(모든 겹, 아래부터).
  void paintStill(StagePixels px, StageView v) {
    for (final l in layers) {
      l.paintStill(px, v);
    }
  }

  /// 흐르는 부분(모든 겹, 아래부터). [t] 는 세상 깊이 이동량.
  void paintFlow(StagePixels px, StageView v, double t) {
    for (final l in layers) {
      l.paintFlow(px, v, t);
    }
  }
}

/// 무대 배경 한 겹. 멈춘 부분은 크기·테마마다 한 번 그려 두고, 흐르는 부분은 장마다 그린다.
/// 같은 겹의 흐르는 부분은 그 겹의 멈춘 부분 위, 위 겹의 멈춘 부분 위에 그려진다.
abstract class StageLayer {
  const StageLayer();

  void paintStill(StagePixels px, StageView v) {}

  void paintFlow(StagePixels px, StageView v, double t) {}
}

/// 무대 한 장의 투시 격자. 배경 도트 1칸은 [artPx] 화면 px 이고, 격자는 무대 아래·가운데에
/// 맞춘다. 좌표는 칸 단위(x 오른쪽, y 아래쪽).
///
/// 카메라 높이 1, 지평선 행 [yh], 지평선에서 무대 아래까지 [k] 칸. 바닥 점(가로 X, 깊이 z):
/// x = cx + X·k/z, y = yh + k/z. 높이 h 인 점: y = yh + k(1 − h)/z. 무대 아래 끝이 z = 1.
@immutable
class StageView {
  StageView._({
    required this.size,
    required this.artPx,
    required this.cols,
    required this.rows,
    required this.k,
    required this.colors,
    required this.brightness,
    required this.detail,
  }) : originX = (size.width - cols * artPx) / 2,
       originY = size.height - rows * artPx;

  /// 펫 [scale] 배, 발끝이 무대 아래에서 [feetFromBottom] 위에 서는 무대.
  ///
  /// - 배경 도트: 6배 이상 4px(시안), 그보다 작으면 `2·배율/3` 내림(최소 1).
  /// - 지평선: 발끝 위 [horizonRows] 줄(스프라이트 줄 × 배율). 펫 가슴 높이라 소실점이
  ///   펫 몸 뒤에 숨는다.
  ///   무대가 낮으면 무대 높이의 [maxHorizon] 을 넘지 않는다.
  /// - 길가 물체는 [detailMinScale] 배 이상에서만 그린다(작은 카드 무대는 하늘·먼 풍경·길만).
  factory StageView.forPet({
    required Size size,
    required int scale,
    required double feetFromBottom,
    required AppColors colors,
    required Brightness brightness,
  }) {
    final artPx = artPxFor(scale);
    var cols = (size.width / artPx).ceil();
    if (cols.isOdd) cols++;
    final rows = math.max(1, (size.height / artPx).ceil());
    // 무대가 아주 낮으면(작은 화면·큰 글자) 위 1/4 은 하늘로 남긴다.
    final horizon = math.min(
      feetFromBottom + horizonRows * scale,
      size.height * maxHorizon,
    );
    return StageView._(
      size: size,
      artPx: artPx,
      cols: cols,
      rows: rows,
      k: math.max(1, (horizon / artPx).round()),
      colors: colors,
      brightness: brightness,
      detail: scale >= detailMinScale,
    );
  }

  /// 지평선이 발끝 위 몇 스프라이트 줄인가(발끝 y=29 → 지평선 y=16, 가슴 높이).
  static const int horizonRows = 13;

  /// 지평선이 올라갈 수 있는 가장 높은 자리(무대 높이 대비, 아래에서).
  static const double maxHorizon = 0.75;

  /// 길가 물체를 그리는 가장 작은 펫 배율.
  static const int detailMinScale = 3;

  /// 펫 배율별 배경 도트 크기(화면 px).
  static int artPxFor(int scale) => (scale * 2 ~/ 3).clamp(1, 4);

  final Size size;
  final int artPx;
  final int cols;
  final int rows;

  /// 지평선에서 무대 아래 끝까지 칸 수(카메라 높이를 칸으로 잰 값).
  final int k;
  final AppColors colors;
  final Brightness brightness;

  /// 길가 물체를 그리는가.
  final bool detail;

  /// 격자 (0, 0) 칸 왼쪽 위의 화면 위치.
  final double originX;
  final double originY;

  /// 지평선 행: 이 행부터 아래가 땅이다(음수면 지평선이 무대 위로 넘어간 작은 무대).
  int get yh => rows - k;

  /// 소실점의 가로 칸(가운데).
  double get cx => cols / 2;

  /// 바닥 점(가로 [x], 깊이 [z])의 가로 칸.
  double sx(double x, double z) => cx + x * k / z;

  /// 높이 [h] (카메라 높이 단위), 깊이 [z] 인 점의 세로 칸.
  double sy(double h, double z) => yh + k * (1 - h) / z;

  /// 땅 행 [y] 가운데의 깊이.
  double zAtRow(int y) => k / (y + 0.5 - yh);
}

/// 배경 도트 격자에 칸 단위로 칠하는 붓. 안티에일리어싱 없이 칸 경계에 딱 맞춘다.
class StagePixels {
  StagePixels(this.canvas, this.view);

  final Canvas canvas;
  final StageView view;
  final Paint _paint = Paint()..isAntiAlias = false;

  int get _px => view.artPx;

  /// 무대 전체를 [color] 로.
  void fill(Color color) {
    _paint.color = color;
    canvas.drawRect(Offset.zero & view.size, _paint);
  }

  /// [y] 행의 [x0]..[x1] 칸(양끝 포함).
  void span(int x0, int x1, int y, Color color) {
    final a = math.max(0, x0), b = math.min(view.cols - 1, x1);
    if (b < a || y < 0 || y >= view.rows) return;
    _paint.color = color;
    canvas.drawRect(
      Rect.fromLTWH(
        view.originX + a * _px,
        view.originY + y * _px,
        (b - a + 1) * _px.toDouble(),
        _px.toDouble(),
      ),
      _paint,
    );
  }

  /// [y] 행에서 칸 가운데가 [xc] 와 [hw] 보다 가까운 칸(경계 제외).
  void band(int y, double xc, double hw, Color color) {
    final x0 = (xc - hw - 0.5).floor() + 1;
    final x1 = (xc + hw - 0.5).ceil() - 1;
    span(x0, x1, y, color);
  }

  /// [y] 행에서 칸 가운데가 [xc] 와 [hw] 이내인 칸(경계 포함).
  void bandInclusive(int y, double xc, double hw, Color color) {
    final x0 = (xc - hw - 0.5).ceil();
    final x1 = (xc + hw - 0.5).floor();
    span(x0, x1, y, color);
  }

  /// 세로 기둥: 가운데 [xc], 반폭 [hw](최소 반 칸), 세로 [y0]..[y1].
  /// 1칸보다 짧으면 가운데 한 행만.
  void vspan(double xc, double hw, double y0, double y1, Color color) {
    final w = math.max(hw, 0.5);
    final mid = ((y0 + y1) / 2).floor();
    for (var y = y0.floor(); y < y1.ceil(); y++) {
      final inside = y0 <= y + 0.5 && y + 0.5 < y1;
      if (!inside && !(y1 - y0 < 1 && y == mid)) continue;
      bandInclusive(y, xc, w, color);
    }
  }

  /// 원: 가운데 ([xc], [yc]), 반지름 [r](최소 반 칸). 칸 가운데가 [yMin] 위나 [yMax]
  /// 아래인 행은 자른다.
  void disc(
    double xc,
    double yc,
    double r,
    Color color, {
    double? yMin,
    double? yMax,
  }) {
    final rr = math.max(r, 0.5);
    for (var y = (yc - rr - 1).floor(); y <= (yc + rr + 1).ceil(); y++) {
      final cy = y + 0.5;
      if (yMax != null && cy > yMax) continue;
      if (yMin != null && cy < yMin) continue;
      final d = rr * rr + 0.15 - (cy - yc) * (cy - yc);
      if (d < 0) continue;
      bandInclusive(y, xc, math.sqrt(d), color);
    }
  }

  /// 정사각형 [n]×[n] 칸, 왼쪽 위 ([x0], [y0]). [yMin] 위 행은 자른다.
  void square(int x0, int y0, int n, Color color, {int yMin = 0}) {
    for (var y = math.max(y0, yMin); y < y0 + n; y++) {
      span(x0, x0 + n - 1, y, color);
    }
  }
}

/// 펫 발밑 도트 그림자 색: 라이트 ink 14%, 다크 검정 30%(시안). 땅 띠 윗선이 없어져
/// 땅에 선 느낌을 이 그림자가 준다.
Color stageShadowColor(AppColors colors, Brightness brightness) =>
    brightness == Brightness.dark
    ? const Color(0x4D000000)
    : colors.ink.withValues(alpha: 0.14);
