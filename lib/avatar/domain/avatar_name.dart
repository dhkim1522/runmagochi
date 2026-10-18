/// 아바타 이름 최대 글자 수.
const int avatarNameMaxLength = 10;

/// 아바타 이름 규칙: 앞뒤 공백을 뺀 뒤 1~[avatarNameMaxLength]자.
/// 맞으면 null, 아니면 화면에 그대로 보여 줄 안내 문장을 돌려준다.
/// 글자 수는 유니코드 코드 포인트 수로 센다(한글 한 글자 = 1).
String? validateAvatarName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) return '이름을 입력해 주세요';
  if (name.runes.length > avatarNameMaxLength) return '10자까지 쓸 수 있어요';
  return null;
}
