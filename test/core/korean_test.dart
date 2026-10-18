import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/korean.dart';

void main() {
  group('subjectParticle', () {
    test('받침 없는 한글 뒤에는 가', () {
      expect(subjectParticle('삐약이'), '가');
      expect(subjectParticle('토리'), '가');
      expect(subjectParticle('러니'), '가');
    });

    test('받침 있는 한글 뒤에는 이', () {
      expect(subjectParticle('말랑'), '이');
      expect(subjectParticle('콩콩'), '이');
      expect(subjectParticle('별빛'), '이');
    });

    test('숫자는 읽는 소리로 고른다', () {
      expect(subjectParticle('토리1'), '이'); // 일
      expect(subjectParticle('토리2'), '가'); // 이
      expect(subjectParticle('토리3'), '이'); // 삼
      expect(subjectParticle('토리5'), '가'); // 오
      expect(subjectParticle('토리0'), '이'); // 영
    });

    test('앞뒤 공백은 무시한다', () {
      expect(subjectParticle(' 말랑  '), '이');
    });

    test('판단할 수 없으면 이(가)', () {
      expect(subjectParticle('Bob'), '이(가)');
      expect(subjectParticle(''), '이(가)');
      expect(subjectParticle('토리!'), '이(가)');
    });
  });

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
