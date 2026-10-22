// UI 후보 시안용 캐릭터·배지 PNG 를 만든다(페이즈 6 작업 7, 두 트랙 공통 입력).
// 사용: fvm dart run tool/render_ui_candidate_pets.dart (저장소 루트에서)
// 결과: design/candidates/ui/shared/ 에 body + face 를 겹친 투명 PNG, 1배와 8배(최근접 확대)
//   chick_s3_idle_0 · chick_s3_run_0~3 · chick_s4_idle_0 · badge_goals_30
// 후보는 작업 18 에서 지운다.
import 'dart:io';

import 'package:image/image.dart' as img;

const String _out = 'design/candidates/ui/shared';
const int _frame = 32;
const int _scale = 8;

img.Image _sheet(String path) => img.decodePng(File(path).readAsBytesSync())!;

/// 시트에서 [index] 번째 32×32 프레임을 잘라 body 위에 face 를 겹친다.
img.Image _pet(int stage, String action, int index) {
  final body = _sheet('assets/sprites/chick/body/stage${stage}_$action.png');
  final face = _sheet('assets/sprites/chick/face/normal_$action.png');
  final out = img.Image(width: _frame, height: _frame, numChannels: 4);
  for (final layer in [body, face]) {
    img.compositeImage(
      out,
      layer,
      srcX: index * _frame,
      srcY: 0,
      srcW: _frame,
      srcH: _frame,
      dstX: 0,
      dstY: 0,
    );
  }
  return out;
}

void _save(String name, img.Image image) {
  File('$_out/$name.png').writeAsBytesSync(img.encodePng(image));
  final big = img.copyResize(
    image,
    width: image.width * _scale,
    height: image.height * _scale,
    interpolation: img.Interpolation.nearest,
  );
  File('$_out/${name}_8x.png').writeAsBytesSync(img.encodePng(big));
}

void main() {
  Directory(_out).createSync(recursive: true);
  _save('chick_s3_idle_0', _pet(3, 'idle', 0));
  for (var i = 0; i < 4; i++) {
    _save('chick_s3_run_$i', _pet(3, 'run', i));
  }
  _save('chick_s4_idle_0', _pet(4, 'idle', 0));
  _save('badge_goals_30', _sheet('assets/badges/goals_30.png'));
  stdout.writeln('wrote $_out');
}
