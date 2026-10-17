// 임시 스프라이트 생성기. 실제 에셋이 나오면 같은 이름의 PNG 로 교체한다.
// 실행: fvm dart run tool/gen_placeholder_sprites.dart (저장소 루트에서)
import 'dart:io';

import 'package:image/image.dart' as img;

const px = 32;
const frames = {'idle': 2, 'walk': 4, 'run': 4};
// 종류별 기본색: 병아리 노랑, 젤리 주황, 도토리 갈색. 단계가 오르면 조금씩 진해진다.
const kindColors = {
  'chick': 0xFFF2C94C,
  'jelly': 0xFFF2994A,
  'acorn': 0xFF9B6B43,
};
const moods = ['normal', 'sleepy', 'asleep'];

int shade(int rgb, double k) {
  int ch(int s) => (((rgb >> s) & 255) * k).round().clamp(0, 255);
  return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

void fill(img.Image im, int x, int y, int w, int h, int rgb) {
  img.fillRect(
    im,
    x1: x,
    y1: y,
    x2: x + w - 1,
    y2: y + h - 1,
    color: img.ColorRgba8((rgb >> 16) & 255, (rgb >> 8) & 255, rgb & 255, 255),
  );
}

/// 발끝이 프레임 아래에서 2px 위(y=29)에 오도록 그린다. 단계가 오르면 키 +3px.
img.Image body(String kind, int stage, String action) {
  final n = frames[action]!;
  final im = img.Image(width: px * n, height: px, numChannels: 4);
  final color = shade(kindColors[kind]!, 1 - 0.08 * (stage - 1));
  final dark = (color >> 1) & 0x7F7F7F;
  final h = 14 + 3 * (stage - 1); // 몸 높이
  final w = 12 + 2 * (stage - 1);
  for (var f = 0; f < n; f++) {
    final ox = f * px + (px - w) ~/ 2;
    final bob = (action != 'idle' && f.isOdd) ? 1 : 0; // 걷고 뛸 때 위아래로 흔들림
    final top = 29 - h - 4 - bob;
    fill(im, ox, top, w, h, color); // 몸통
    // 팔: 프레임마다 앞뒤로 흔든다. idle 은 아래위로 작게.
    final swing = action == 'idle'
        ? 0
        : (f % 2 == 0 ? -2 : 2) * (action == 'run' ? 2 : 1);
    fill(im, ox - 2 + swing, top + 3 + (action == 'idle' ? f : 0), 2, 6, dark);
    fill(im, ox + w - swing, top + 3 + (action == 'idle' ? f : 0), 2, 6, dark);
    // 다리: 프레임마다 벌어짐이 달라진다.
    final legShift = action == 'idle'
        ? 0
        : [-2, 0, 2, 0][f % 4] * (action == 'run' ? 2 : 1);
    fill(im, ox + 2 + legShift, 25 - bob, 3, 5 + bob, dark);
    fill(im, ox + w - 5 - legShift, 25 - bob, 3, 5 + bob, dark);
  }
  return im;
}

/// 눈 모양으로 표정을 구분한다. 몸 위쪽에 놓인다.
img.Image face(String mood, String action) {
  final n = frames[action]!;
  final im = img.Image(width: px * n, height: px, numChannels: 4);
  for (var f = 0; f < n; f++) {
    final ox = f * px;
    final bob = (action != 'idle' && f.isOdd) ? 1 : 0;
    final y = 12 - bob;
    switch (mood) {
      case 'normal': // 네모 눈
        fill(im, ox + 10, y, 3, 3, 0xFF222222);
        fill(im, ox + 19, y, 3, 3, 0xFF222222);
      case 'sleepy': // 가로줄 눈
        fill(im, ox + 9, y + 1, 5, 1, 0xFF222222);
        fill(im, ox + 18, y + 1, 5, 1, 0xFF222222);
      case 'asleep': // 가로줄 눈 + z
        fill(im, ox + 9, y + 1, 5, 1, 0xFF222222);
        fill(im, ox + 18, y + 1, 5, 1, 0xFF222222);
        final zy = 3 + (f.isOdd ? 1 : 0); // z 가 살짝 떠오름
        fill(im, ox + 24, zy, 4, 1, 0xFF4F6BED);
        fill(im, ox + 26, zy + 1, 1, 1, 0xFF4F6BED);
        fill(im, ox + 25, zy + 2, 1, 1, 0xFF4F6BED);
        fill(im, ox + 24, zy + 3, 4, 1, 0xFF4F6BED);
    }
  }
  return im;
}

void save(String path, img.Image im) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(im));
}

void main() {
  var n = 0;
  for (final kind in kindColors.keys) {
    for (final action in frames.keys) {
      for (var stage = 1; stage <= 4; stage++) {
        save(
          'assets/sprites/$kind/body/stage${stage}_$action.png',
          body(kind, stage, action),
        );
        n++;
      }
      for (final mood in moods) {
        save(
          'assets/sprites/$kind/face/${mood}_$action.png',
          face(mood, action),
        );
        n++;
      }
    }
  }
  stdout.writeln('임시 스프라이트 $n개 생성');
}
