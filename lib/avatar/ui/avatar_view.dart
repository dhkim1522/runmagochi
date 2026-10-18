import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../domain/growth_rules.dart';
import 'sprite_sheet.dart';

/// 레이어 스프라이트 아바타. 페이즈 2는 body → face 순서로 겹쳐 그린다.
///
/// 크기는 `32 × scale` 정사각형이고, 시트의 프레임을 [fps] 로 넘긴다.
class AvatarView extends StatefulWidget {
  const AvatarView({
    super.key,
    required this.kind,
    required this.stage,
    required this.mood,
    required this.action,
    this.scale = 4,
  });

  final AvatarKind kind;

  /// 외형 단계 1~4.
  final int stage;
  final AvatarMood mood;
  final AvatarAction action;

  /// 정수 배율.
  final int scale;

  @override
  State<AvatarView> createState() => AvatarViewState();
}

@visibleForTesting
class AvatarViewState extends State<AvatarView> {
  /// 스프라이트 fps 간격으로만 프레임을 넘긴다 (vsync 마다 그리지 않는다).
  Timer? _timer;
  int _frame = 0;

  /// 레이어 이름 → (경로, 스트림, 리스너, 이미지)
  final Map<String, _Layer> _layers = {};

  /// 지금 그려지는 프레임 번호.
  @visibleForTesting
  int get frameIndex => _frame;

  @override
  void initState() {
    super.initState();
    _syncLayers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 가려진 탭(TickerMode 꺼짐)에서는 멈추고, 다시 보이면 이어서 돈다.
    if (TickerMode.valuesOf(context).enabled) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void didUpdateWidget(AvatarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action) {
      // 동작이 바뀌면 경과 시간을 0부터 다시 센다.
      _stop();
      _frame = 0;
      if (TickerMode.valuesOf(context).enabled) _start();
    }
    _syncLayers();
  }

  void _start() {
    if (_timer != null) return;
    final interval = Duration(
      microseconds: Duration.microsecondsPerSecond ~/ fps(widget.action),
    );
    _timer = Timer.periodic(interval, (_) {
      setState(() => _frame = (_frame + 1) % frameCount(widget.action));
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 현재 속성에 맞는 시트 경로로 레이어 이미지를 맞춘다.
  void _syncLayers() {
    final paths = {
      'body': bodySheet(widget.kind, widget.stage, widget.action),
      'face': faceSheet(widget.kind, widget.mood, widget.action),
    };
    for (final name in spriteLayerOrder) {
      final path = paths[name];
      if (path == null) continue;
      final cur = _layers[name];
      if (cur != null && cur.path == path) continue;
      cur?.dispose();
      _layers[name] = _Layer(path, _onImage);
    }
  }

  void _onImage() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _stop();
    for (final l in _layers.values) {
      l.dispose();
    }
    _layers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = (spriteFramePx * widget.scale).toDouble();
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AvatarPainter(
          images: [
            for (final name in spriteLayerOrder) _layers[name]?.image?.image,
          ],
          frame: _frame,
        ),
      ),
    );
  }
}

/// 시트 한 장의 로딩 상태.
class _Layer {
  _Layer(this.path, VoidCallback onChanged) {
    _stream = AssetImage(path).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (info, _) {
        final old = image;
        image = info.clone();
        old?.dispose();
        onChanged();
      },
      onError: (_, _) {
        // 시트가 없으면 그 레이어는 그리지 않는다.
      },
    );
    _stream.addListener(_listener);
  }

  final String path;
  late final ImageStream _stream;
  late final ImageStreamListener _listener;
  ImageInfo? image;

  void dispose() {
    _stream.removeListener(_listener);
    image?.dispose();
    image = null;
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({required this.images, required this.frame});

  /// [spriteLayerOrder] 순서. 아직 없거나 로딩 전이면 null.
  final List<ui.Image?> images;
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    const f = spriteFramePx;
    final dst = Offset.zero & size;
    for (final img in images) {
      if (img == null) continue;
      final src = Rect.fromLTWH(
        (frame * f).toDouble(),
        0,
        f.toDouble(),
        f.toDouble(),
      );
      canvas.drawImageRect(img, src, dst, paint);
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.frame != frame || !listEquals(old.images, images);
}

/// 아바타 종류를 아직 모를 때(성장 상태를 읽는 중) 두는 빈자리.
///
/// [AvatarView] 와 같은 `32 × scale` 정사각형이라, 다 읽고 아바타로 바뀌어도
/// 배치가 움직이지 않고, 다른 종류(병아리)가 잠깐 보였다 바뀌지도 않는다.
class AvatarSlot extends StatelessWidget {
  const AvatarSlot({super.key, this.scale = 4});

  /// 정수 배율.
  final int scale;

  @override
  Widget build(BuildContext context) =>
      SizedBox.square(dimension: (spriteFramePx * scale).toDouble());
}
