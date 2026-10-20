import 'dart:math' as math;

const double _earthRadiusMeters = 6371000;

double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final a =
      math.pow(math.sin(dPhi / 2), 2) +
      math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda / 2), 2);
  return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
}
