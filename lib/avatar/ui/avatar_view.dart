import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import '../../core/theme.dart';
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
class AvatarViewState extends State<AvatarView> with WidgetsBindingObserver {
  /// 스프라이트 fps 간격으로만 프레임을 넘긴다 (vsync 마다 그리지 않는다).
  Timer? _timer;
  int _frame = 0;

  /// 탭이 보이는 중인가(TickerMode).
  bool _visible = true;

  /// 앱이 앞에 있는가. 백그라운드·화면 꺼짐이면 배터리를 위해 멈춘다.
  bool _foreground = true;

  /// 레이어 이름 → (경로, 스트림, 리스너, 이미지)
  final Map<String, _Layer> _layers = {};

  /// 지금 그려지는 프레임 번호.
  @visibleForTesting
  int get frameIndex => _frame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final life = WidgetsBinding.instance.lifecycleState;
    _foreground = life == null || life == AppLifecycleState.resumed;
    _syncLayers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 가려진 탭(TickerMode 꺼짐)에서는 멈추고, 다시 보이면 이어서 돈다.
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 백그라운드·화면 꺼짐이면 멈추고, 다시 앞으로 오면 이어서 돈다.
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// 보이고 앞에 있을 때만 타이머가 돈다.
  void _sync() {
    if (_visible && _foreground) {
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
      _sync();
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
    WidgetsBinding.instance.removeObserver(this);
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
    final images = [
      for (final name in spriteLayerOrder) _layers[name]?.image?.image,
    ];
    final rim = rimColor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        // 윤곽이 1픽셀 번지는 만큼 자기 크기 밖으로 나가도 잘리지 않게 한다.
        clipBehavior: Clip.none,
        children: [
          // 윤곽은 같은 프레임 이미지를 색만 바꿔 다시 그린다 (디코딩 없음).
          if (rim != null)
            Positioned.fill(
              child: CustomPaint(
                key: avatarRimKey,
                painter: _AvatarPainter(
                  images: images,
                  frame: _frame,
                  rim: rim,
                  rimOffset: widget.scale.toDouble(),
                ),
              ),
            ),
          Positioned.fill(
            child: CustomPaint(
              painter: _AvatarPainter(images: images, frame: _frame),
            ),
          ),
        ],
      ),
    );
  }

  /// 윤곽 색. 테마 토큰이 투명(라이트)이면 null 이라 윤곽 층을 만들지 않는다.
  @visibleForTesting
  Color? get rimColor {
    final rim = Theme.of(context).extension<AppColors>()?.spriteRim;
    return rim == null || rim.a == 0 ? null : rim;
  }
}

/// 다크 테마 아바타의 윤곽 층을 찾는 키 (테스트용).
@visibleForTesting
const avatarRimKey = ValueKey('avatar-rim');

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
  _AvatarPainter({
    required this.images,
    required this.frame,
    this.rim,
    this.rimOffset = 0,
  });

  /// [spriteLayerOrder] 순서. 아직 없거나 로딩 전이면 null.
  final List<ui.Image?> images;
  final int frame;

  /// 있으면 스프라이트 대신 이 색의 실루엣을 상하좌우로 [rimOffset] 만큼 밀어 그린다.
  final Color? rim;
  final double rimOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = FilterQuality.none;
    final rim = this.rim;
    if (rim != null) {
      paint.colorFilter = ColorFilter.mode(rim, BlendMode.srcIn);
    }
    const f = spriteFramePx;
    final dst = Offset.zero & size;
    final offsets = rim == null
        ? const [Offset.zero]
        : [
            Offset(rimOffset, 0),
            Offset(-rimOffset, 0),
            Offset(0, rimOffset),
            Offset(0, -rimOffset),
          ];
    for (final img in images) {
      if (img == null) continue;
      final src = Rect.fromLTWH(
        (frame * f).toDouble(),
        0,
        f.toDouble(),
        f.toDouble(),
      );
      for (final o in offsets) {
        canvas.drawImageRect(img, src, dst.shift(o), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.frame != frame ||
      old.rim != rim ||
      old.rimOffset != rimOffset ||
      !listEquals(old.images, images);
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
