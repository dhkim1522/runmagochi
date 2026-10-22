// 캐릭터 후보 한 안의 데이터 형식(목록은 candidates.dart).
import '../pet_art.dart';
import '../sprite_data.dart';

/// 후보가 그리는 동작. 걷기는 빼고 idle·run 만 본다.
const List<String> candidateActions = ['idle', 'run'];

class Candidate {
  const Candidate({
    required this.id,
    required this.title,
    required this.palette,
    required this.kind,
    this.poses = petPoses,
  });

  /// 폴더 이름: a·b·c.
  final String id;

  /// 그림체 이름(문서·보고용).
  final String title;
  final Palette palette;

  /// 병아리 4단계와 표정 normal. 기준점은 이 후보의 머리 위치다.
  final PetKind kind;
  final PoseSet poses;

  /// [stage] 는 0부터(0 = 1단계).
  List<SpriteFrame> body(int stage, String action) =>
      bodyFrames(kind.stages[stage], action, poses);

  List<SpriteFrame> face(String action) =>
      faceFrames(kind, 'normal', action, poses);
}
