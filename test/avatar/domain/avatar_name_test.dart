import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/avatar/domain/avatar_name.dart';

void main() {
  test('앞뒤 공백을 빼고 1~10자면 통과한다', () {
    expect(validateAvatarName('삐약이'), isNull);
    expect(validateAvatarName('  토리  '), isNull);
    expect(validateAvatarName('가나다라마바사아자차'), isNull);
  });

  test('비었거나 공백뿐이면 이름을 입력하라고 한다', () {
    expect(validateAvatarName(''), '이름을 입력해 주세요');
    expect(validateAvatarName('   '), '이름을 입력해 주세요');
  });

  test('10자를 넘으면 10자까지라고 한다', () {
    expect(validateAvatarName('가나다라마바사아자차카'), '10자까지 쓸 수 있어요');
    expect(validateAvatarName(' 가나다라마바사아자차 '), isNull);
  });
}
