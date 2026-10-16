/// Google Encoded Polyline Algorithm (정밀도 1e5).
String encodePolyline(List<(double, double)> points) {
  final buffer = StringBuffer();
  var prevLat = 0;
  var prevLng = 0;
  for (final (lat, lng) in points) {
    final latE5 = (lat * 1e5).round();
    final lngE5 = (lng * 1e5).round();
    _encodeValue(latE5 - prevLat, buffer);
    _encodeValue(lngE5 - prevLng, buffer);
    prevLat = latE5;
    prevLng = lngE5;
  }
  return buffer.toString();
}

List<(double, double)> decodePolyline(String encoded) {
  final points = <(double, double)>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextValue() {
    var result = 0;
    var shift = 0;
    int chunk;
    do {
      chunk = encoded.codeUnitAt(index++) - 63;
      result |= (chunk & 0x1f) << shift;
      shift += 5;
    } while (chunk >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    lat += nextValue();
    lng += nextValue();
    points.add((lat / 1e5, lng / 1e5));
  }
  return points;
}

void _encodeValue(int value, StringBuffer out) {
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}
