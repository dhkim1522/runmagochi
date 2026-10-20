import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/korean.dart';

void main() {
  group('keepAll', () {
    test('단어 안 글자 사이에만 단어 잇기 문자를 넣는다', () {
      expect(keepAll('왔어요!'), '왔$wordJoiner어$wordJoiner요$wordJoiner!');
      expect(keepAll('알이 왔어요'), '알$wordJoiner이 왔$wordJoiner어$wordJoiner요');
      expect(keepAll('가').replaceAll(wordJoiner, ''), '가');
    });

    test('잇기 문자를 빼면 원문과 같다', () {
      const s = '달린 거리만큼 자라서 러닝화를 신고, 언젠가 마라토너가 돼요.';
      expect(keepAll(s).replaceAll(wordJoiner, ''), s);
    });
  });
}
