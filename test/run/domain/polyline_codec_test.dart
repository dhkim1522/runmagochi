import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/domain/polyline_codec.dart';

void main() {
  test('Google 예제 인코딩', () {
    expect(encodePolyline([(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)]),
        '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
  });
  test('디코딩은 인코딩의 역', () {
    final pts = [(37.52600, 126.92400), (37.52620, 126.92420)];
    expect(decodePolyline(encodePolyline(pts)), pts);
  });
  test('빈 목록은 빈 문자열', () => expect(encodePolyline([]), ''));
}
