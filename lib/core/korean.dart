/// 한글 줄바꿈 보조.
library;

/// 단어 잇기 문자(U+2060). 이 문자 사이에서는 줄을 바꾸지 않는다.
const wordJoiner = '⁠';

/// 한글은 글자마다 줄이 바뀔 수 있어 "왔어/요!" 처럼 끊긴다. 단어 안 글자 사이에
/// [wordJoiner] 를 넣어 띄어쓰기에서만 줄이 바뀌게 한다(CSS word-break: keep-all).
/// 화면에 그릴 글자에만 쓰고, 스크린 리더 라벨은 원문을 쓴다.
String keepAll(String text) => text
    .split(' ')
    .map((w) => w.runes.map(String.fromCharCode).join(wordJoiner))
    .join(' ');
