// 캐릭터 콘셉트 미리보기(design/character/concepts.png). 안마다 1단계·4단계 idle 정지 프레임.
// 페이즈 2.5 작업 3 에서는 콘셉트 그림을 여기 따로 그렸다(커밋 1af5dbf). 페이즈 6 작업 4 부터는
// 실제 펫 그림(tool/sprites/<kind>.dart)의 body + normal 표정을 겹쳐 3종을 한 장에 보여 준다.
import 'pet_art.dart';
import 'pets.dart';
import 'sprite_data.dart';

const Palette conceptPalette = petPalette;

const Map<String, String> _names = {
  'jelly': '젤리',
  'chick': '병아리',
  'acorn': '도토리',
};

/// 콘셉트 이름 → [1단계, 4단계]. 순서는 페이즈 2.5 콘셉트 그대로(젤리·병아리·도토리).
Map<String, List<SpriteFrame>> get concepts => {
  for (final name in _names.keys)
    _names[name]!: [
      for (final s in [0, 3]) _still(pets.firstWhere((p) => p.name == name), s),
    ],
};

SpriteFrame _still(PetKind pet, int stage) {
  final body = bodyFrames(pet.stages[stage], 'idle').first;
  final face = faceFrames(pet, 'normal', 'idle').first;
  return SpriteFrame([
    for (var y = 0; y < body.height; y++)
      String.fromCharCodes([
        for (var x = 0; x < body.width; x++)
          face.rows[y].codeUnitAt(x) == 0x2E
              ? body.rows[y].codeUnitAt(x)
              : face.rows[y].codeUnitAt(x),
      ]),
  ]);
}
