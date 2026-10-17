// 페이즈 2.5 작업 3 캐릭터 콘셉트. 안마다 1단계·4단계 idle 정지 프레임.
import 'sprite_data.dart';

const Palette conceptPalette = {
  'o': 0xFF431407, // 외곽선 (ink)
  'k': 0xFF431407, // 눈
  'w': 0xFFFFFFFF, // 눈 반짝임
  'h': 0xFFFFEDD5, // 하이라이트 (surface-soft)
  'b': 0xFFFB923C, // 주황 몸
  'B': 0xFFEA580C, // 주황 그림자
  'p': 0xFFFDA4AF, // 볼
  'g': 0xFF15803D, // 잎
  'G': 0xFF4ADE80, // 잎 밝은 쪽
  'a': 0xFF2563EB, // 헤어밴드 (accent)
  'y': 0xFFFFF7ED, // 알 껍데기
  'Y': 0xFFFED7AA, // 알 그림자
  'm': 0xFFFACC15, // 병아리 몸
  'M': 0xFFCA8A04, // 병아리 그림자
  'c': 0xFF92400E, // 도토리 모자
  'C': 0xFFB45309, // 도토리 모자 밝은 쪽
  'n': 0xFFF4A261, // 도토리 몸
  'N': 0xFFC2410C, // 도토리 몸 그림자
};

/// 콘셉트 이름 → [1단계, 4단계].
const Map<String, List<SpriteFrame>> concepts = {
  '젤리': [
    SpriteFrame([
      '......gG........',
      '.....gGGg.......',
      '......g.........',
      '....oooooooo....',
      '..oobbbbbbbboo..',
      '.obbhhbbbbbbbbo.',
      '.obhhbbbbbbbbbo.',
      'obbbbbbbbbbbbbbo',
      'obbbwkbbbbwkbbbo',
      'obbbkkbbbbkkbbbo',
      'obppbbbbbbbbppbo',
      'obbbbbboobbbbbbo',
      'oBbbbbbbbbbbbbBo',
      '.oBBbbbbbbbbBBo.',
      '..ooBBBBBBBBoo..',
      '....oooooooo....',
      '....oo....oo....',
    ]),
    SpriteFrame([
      '......oooooooo......',
      '....oobbbbbbbboo....',
      '...obbhhbbbbbbbbo...',
      '..obbhhbbbbbbbbbbo..',
      '..obbbbbbbbbbbbbbo..',
      '.oaaaaaaaaaaaaaaaao.',
      '.obbbbbbbbbbbbbbbbo.',
      '.obbbwkbbbbbbwkbbbo.',
      '.obbbkkbbbbbbkkbbbo.',
      '.obppbbbbbbbbbbppbo.',
      '.obbbbbbboobbbbbbbo.',
      'oBbbbbbbbbbbbbbbbbBo',
      'oBbbbbbbbbbbbbbbbbBo',
      '.oBBbbbbbbbbbbbbBBo.',
      '..ooBBBBBBBBBBBBoo..',
      '....oooooooooooo....',
      '....ooo......ooo....',
    ]),
  ],
  '병아리': [
    SpriteFrame([
      '....oooooo....',
      '...oyyyyyyo...',
      '..oyhhyyyyyo..',
      '.oyhyyyyyyyyo.',
      '.oyyyyyyyyyyo.',
      'oyyykyyyykyyyo',
      'oyyykyyyykyyyo',
      'oYyyyyyyyyyyYo',
      'oYooYYooYYooYo',
      'oYYYYYYYYYYYYo',
      '.oYYYYYYYYYYo.',
      '..oooooooooo..',
    ]),
    SpriteFrame([
      '.......mm.........',
      '......mm..........',
      '....oooooooooo....',
      '...ommmmmmmmmmo...',
      '..ommhhmmmmmmmmo..',
      '..oaaaaaaaaaaaao..',
      '.ommmwkmmmmwkmmmo.',
      '.ommmkkmmmmkkmmmo.',
      '.ommmmmbbbbmmmmmo.',
      '.omMmmmmbbmmmmMmo.',
      'oMMmmmmmmmmmmmmMMo',
      'oMmmmmmmmmmmmmmmMo',
      '.oMMmmmmmmmmmmMMo.',
      '..ooMMMMMMMMMMoo..',
      '....oooooooooo....',
      '.....bb....bb.....',
    ]),
  ],
  '도토리': [
    SpriteFrame([
      '......cc......',
      '...oooooooo...',
      '..oCCCCCCCCo..',
      '.oCcCcCcCcCco.',
      '.occcccccccco.',
      '..onnnnnnnno..',
      '..onkknnkkno..',
      '..onnnnnnnno..',
      '..onpnnnnpno..',
      '...onnoonno...',
      '...oNnnnnNo...',
      '....oooooo....',
      '....oo..oo....',
    ]),
    SpriteFrame([
      '........cc........',
      '....oooooooooo....',
      '...oCCCCCCCCCCo...',
      '..oCcCcCcCcCcCco..',
      '..occcccccccccco..',
      '..oaaaaaaaaaaaao..',
      '..onnnnnnnnnnnno..',
      '..onnwknnnnwknno..',
      '..onnkknnnnkknno..',
      '..onpnnnnnnnnpno..',
      '..onnnnnoonnnnno..',
      '.oNnnnnnnnnnnnnNo.',
      '.oNNnnnnnnnnnnNNo.',
      '..ooNNNNNNNNNNoo..',
      '....oooooooooo....',
      '...ooo......ooo...',
    ]),
  ],
};
