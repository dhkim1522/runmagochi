class LocationSample {
  const LocationSample({
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.speed,
  });

  final DateTime time;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
}
