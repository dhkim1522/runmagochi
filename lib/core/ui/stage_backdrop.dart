import 'dart:ui' show Picture, PictureRecorder;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../stage/park_scene.dart';
import '../stage/stage_scene.dart';
import '../theme.dart';

/// 사각 무대 배경([StageScene] 네 겹)과 펫 발밑 그림자. `PetStage` 가 펫 뒤에 깐다.
///
/// [moving] 이면 땅·길 무늬와 길가 물체가 소실점 쪽으로 물러난다(러닝 중). 애니메이션 줄이기
/// ([Motion.reduced])면 0번 장에 멈추고, [moving] 이 꺼지면(일시정지) 그 자리에 멈춘다.
/// 흐름은 펫을 다시 만들지 않는다: 자기 [RepaintBoundary] 안 [CustomPaint] 만 다시 그리고,
/// 멈춘 겹과 장마다의 흐르는 겹은 크기·테마별로 [Picture] 에 담아 둔다.
class StageBackdrop extends StatefulWidget {
  const StageBackdrop({
    super.key,
    this.scene = parkScene,
    required this.scale,
    required this.feetFromBottom,
    this.moving = false,
  });

  final StageScene scene;

  /// 펫 정수 배율. 배경 도트 크기·지평선 높이·그림자 폭이 따른다.
  final int scale;

  /// 무대 아래에서 펫 발끝까지.
  final double feetFromBottom;

  /// 길이 흐르는가(러닝 중이고 멈추지 않았을 때).
  final bool moving;

  @override
  State<StageBackdrop> createState() => StageBackdropState();
}

@visibleForTesting
class StageBackdropState extends State<StageBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  final ValueNotifier<int> _step = ValueNotifier(0);
  final _StageCache _cache = _StageCache();

  /// 흐름을 (다시) 시작할 때의 장 번호. 일시정지 뒤 이어서 흐른다.
  int _startStep = 0;

  /// 지금 그리는 장 번호(0 ~ stepsPerPeriod − 1).
  @visibleForTesting
  int get step => _step.value;

  /// 흐르는 중인가(티커가 돈다).
  @visibleForTesting
  bool get flowing => _ticker.isActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StageBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene != widget.scene) {
      _ticker.stop();
      _step.value = 0;
    }
    _sync();
  }

  void _sync() {
    final reduced = Motion.reduced(context);
    final run = widget.moving && !reduced;
    if (reduced) _step.value = 0;
    if (run && !_ticker.isActive) {
      _startStep = _step.value;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    final s = widget.scene;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    // 장 번호가 바뀔 때만 알린다(초당 8장).
    _step.value = (_startStep + s.stepAt(seconds)) % s.stepsPerPeriod;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _step.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _StagePainter(
          scene: widget.scene,
          colors: AppColors.of(context),
          brightness: Theme.of(context).brightness,
          scale: widget.scale,
          feetFromBottom: widget.feetFromBottom,
          step: _step,
          cache: _cache,
        ),
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({
    required this.scene,
    required this.colors,
    required this.brightness,
    required this.scale,
    required this.feetFromBottom,
    required this.step,
    required this.cache,
  }) : super(repaint: step);

  final StageScene scene;
  final AppColors colors;
  final Brightness brightness;
  final int scale;
  final double feetFromBottom;
  final ValueListenable<int> step;
  final _StageCache cache;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final view = StageView.forPet(
      size: size,
      scale: scale,
      feetFromBottom: feetFromBottom,
      colors: colors,
      brightness: brightness,
    );
    cache.use((scene, size, scale, feetFromBottom, colors, brightness));
    final i = step.value;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPicture(
      cache.base ??= _record(size, (c) {
        scene.paintStill(StagePixels(c, view), view);
      }),
    );
    canvas.drawPicture(
      cache.frames[i] ??= _record(size, (c) {
        scene.paintFlow(StagePixels(c, view), view, scene.offsetAt(i));
      }),
    );
    _paintShadow(canvas, size, view);
    canvas.restore();
  }

  /// 발밑 도트 그림자: 폭 20 스프라이트 칸, 배경 도트 3줄(가운데 줄만 끝까지), 발끝 2줄 위부터.
  void _paintShadow(Canvas canvas, Size size, StageView v) {
    final px = v.artPx.toDouble();
    final w = 20.0 * scale;
    final left = (size.width - w) / 2;
    final top = size.height - feetFromBottom - 2 * px;
    final paint = Paint()
      ..isAntiAlias = false
      ..color = stageShadowColor(colors, brightness);
    final inset = 3 * px;
    canvas.drawRect(Rect.fromLTWH(left + inset, top, w - 2 * inset, px), paint);
    canvas.drawRect(Rect.fromLTWH(left, top + px, w, px), paint);
    canvas.drawRect(
      Rect.fromLTWH(left + inset, top + 2 * px, w - 2 * inset, px),
      paint,
    );
  }

  static Picture _record(Size size, void Function(Canvas) draw) {
    final rec = PictureRecorder();
    draw(Canvas(rec, Offset.zero & size));
    return rec.endRecording();
  }

  @override
  bool shouldRepaint(_StagePainter old) =>
      old.scene != scene ||
      old.colors != colors ||
      old.brightness != brightness ||
      old.scale != scale ||
      old.feetFromBottom != feetFromBottom ||
      old.step != step;
}

/// 크기·테마·배경이 같은 동안 그려 둔 그림: 멈춘 겹 한 장, 흐르는 겹은 장마다 한 장.
class _StageCache {
  Object? _key;
  Picture? base;
  final Map<int, Picture> frames = {};

  /// [key] 가 바뀌면 그려 둔 그림을 버린다.
  void use(Object key) {
    if (key == _key) return;
    dispose();
    _key = key;
  }

  void dispose() {
    base?.dispose();
    base = null;
    for (final p in frames.values) {
      p.dispose();
    }
    frames.clear();
    _key = null;
  }
}
