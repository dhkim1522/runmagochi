/// 한국어 조사 고르기.
library;

const _hangulFirst = 0xAC00;
const _hangulLast = 0xD7A3;

/// 받침이 있게 읽히는 숫자(영·일·삼·육·칠·팔).
const _digitsWithFinal = {'0', '1', '3', '6', '7', '8'};

/// [word] 뒤에 붙일 주격 조사. 받침이 있으면 '이', 없으면 '가'.
/// 마지막 글자가 한글·숫자가 아니어서 판단할 수 없으면 '이(가)'.
String subjectParticle(String word) {
  final w = word.trim();
  if (w.isEmpty) return '이(가)';
  final last = w.runes.last;
  if (last >= _hangulFirst && last <= _hangulLast) {
    return (last - _hangulFirst) % 28 == 0 ? '가' : '이';
  }
  final ch = String.fromCharCode(last);
  if (RegExp(r'[0-9]').hasMatch(ch)) {
    return _digitsWithFinal.contains(ch) ? '이' : '가';
  }
  return '이(가)';
}

/// 단어 잇기 문자(U+2060). 이 문자 사이에서는 줄을 바꾸지 않는다.
const wordJoiner = '⁠';

/// 한글은 글자마다 줄이 바뀔 수 있어 "왔어/요!" 처럼 끊긴다. 단어 안 글자 사이에
/// [wordJoiner] 를 넣어 띄어쓰기에서만 줄이 바뀌게 한다(CSS word-break: keep-all).
/// 화면에 그릴 글자에만 쓰고, 스크린 리더 라벨은 원문을 쓴다.
String keepAll(String text) => text
    .split(' ')
    .map((w) => w.runes.map(String.fromCharCode).join(wordJoiner))
    .join(' ');
