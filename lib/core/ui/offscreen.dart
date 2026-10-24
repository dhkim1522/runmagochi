import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// [card] 를 화면 밖에서 [size] 로 그려 PNG 바이트로 만든다(공유 카드·홈 화면 위젯).
///
/// 아바타 시트([sheets])를 먼저 읽어 두고(비어 있는 아바타가 찍히지 않게) 그린 뒤 찍는다.
Future<Uint8List> renderOffscreen(
  BuildContext context,
  Widget card, {
  required Size size,
  required double pixelRatio,
  List<String> sheets = const [],
}) async {
  final overlay = Overlay.of(context, rootOverlay: true);
  for (final p in sheets) {
    await precacheImage(AssetImage(p), context);
  }
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      // 화면 왼쪽 밖. 배치·그리기는 되지만 보이지 않는다.
      left: -size.width - 100,
      top: 0,
      child: RepaintBoundary(key: key, child: card),
    ),
  );
  overlay.insert(entry);
  try {
    // 그려진 뒤 이미지 리스너가 한 번 더 그리게 한다.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    entry.remove();
  }
}
