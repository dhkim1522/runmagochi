// 페이즈 6 작업 1: 캐릭터 그림체 후보. 투표용 미리보기 전용이다(앱 에셋에 쓰지 않는다).
// 셋 다 병아리 1~4단계 idle·run, 표정 normal 을 그린다. 장비는 결정 0013.
// 그림 형식·프레임 펼치기는 pet_art.dart 를 그대로 쓰고, 팔레트·자세표만 후보마다 따로 둔다.
// 고른 안은 작업 3 에서 tool/sprites/chick.dart 로 옮긴다. 작업 18 에서 이 폴더를 지운다.
import 'a.dart';
import 'b.dart';
import 'c.dart';
import 'candidate.dart';

export 'candidate.dart';

final List<Candidate> candidates = [candidateA, candidateB, candidateC];
