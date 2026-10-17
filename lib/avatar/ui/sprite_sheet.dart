import '../domain/growth_rules.dart';

/// 스프라이트 한 프레임의 한 변(px). 규격은 docs/specs/sprite-spec.md.
const int spriteFramePx = 32;

/// 동작별 시트의 프레임 수.
int frameCount(AvatarAction a) => switch (a) {
  AvatarAction.idle => 2,
  AvatarAction.walk => 4,
  AvatarAction.run => 4,
};

/// 동작별 초당 프레임 수.
double fps(AvatarAction a) => switch (a) {
  AvatarAction.idle => 4,
  AvatarAction.walk => 6,
  AvatarAction.run => 10,
};

/// 몸 시트 경로. [stage] 는 외형 단계 1~4.
String bodySheet(int stage, AvatarAction a) =>
    'assets/sprites/body/stage${stage}_${a.name}.png';

/// 표정 시트 경로.
String faceSheet(AvatarMood m, AvatarAction a) =>
    'assets/sprites/face/${m.name}_${a.name}.png';

/// 겹치는 순서(아래 → 위). 페이즈 2는 body·face 만 쓴다.
const spriteLayerOrder = [
  'body',
  'face',
  'bottom',
  'top',
  'shoes',
  'hat',
  'accessory',
];
