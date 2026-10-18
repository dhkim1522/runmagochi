import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/growth_state.dart';

void main() {
  group('GrowthGain.revisedBy', () {
    const original = GrowthGain(
      distanceXp: 50,
      goalBonusXp: 50,
      levelBefore: 1,
      levelAfter: 3,
      stageBefore: 1,
      stageAfter: 2,
    );

    test('경험치는 더하고 레벨·단계는 원래 시작과 지금 값으로 잇는다', () {
      const delta = GrowthGain(
        distanceXp: -20,
        goalBonusXp: -50,
        levelBefore: 3,
        levelAfter: 2,
        stageBefore: 2,
        stageAfter: 1,
      );
      final revised = original.revisedBy(delta);
      expect(revised.distanceXp, 30);
      expect(revised.goalBonusXp, 0);
      expect(revised.levelBefore, 1);
      expect(revised.levelAfter, 2);
      expect(revised.stageBefore, 1);
      expect(revised.stageAfter, 1);
      expect(revised.leveledUp, isTrue);
    });

    test('변화가 없으면 원래 값과 같다', () {
      const delta = GrowthGain(
        distanceXp: 0,
        goalBonusXp: 0,
        levelBefore: 3,
        levelAfter: 3,
        stageBefore: 2,
        stageAfter: 2,
      );
      final revised = original.revisedBy(delta);
      expect(revised.distanceXp, 50);
      expect(revised.goalBonusXp, 50);
      expect(revised.levelAfter, 3);
      expect(revised.stageAfter, 2);
    });

    test('여러 번 잘라도 이어서 합칠 수 있다', () {
      const first = GrowthGain(
        distanceXp: -10,
        goalBonusXp: 0,
        levelBefore: 3,
        levelAfter: 3,
        stageBefore: 2,
        stageAfter: 2,
      );
      const second = GrowthGain(
        distanceXp: -10,
        goalBonusXp: -50,
        levelBefore: 3,
        levelAfter: 2,
        stageBefore: 2,
        stageAfter: 1,
      );
      final revised = original.revisedBy(first).revisedBy(second);
      expect(revised.distanceXp, 30);
      expect(revised.goalBonusXp, 0);
      expect(revised.levelBefore, 1);
      expect(revised.levelAfter, 2);
    });
  });
}
