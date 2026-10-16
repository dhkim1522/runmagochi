/// 초/km 를 `6'25"` 로. 값이 없으면 `-'--"`.
String formatPace(double? secPerKm) {
  if (secPerKm == null || !secPerKm.isFinite || secPerKm < 0) return "-'--\"";
  final total = secPerKm.round();
  final seconds = (total % 60).toString().padLeft(2, '0');
  return "${total ~/ 60}'$seconds\"";
}

/// `18:42`, 한 시간 이상이면 `1:02:05`.
String formatDuration(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return '$m:$s';
}

/// 미터를 km 소수 둘째 자리로.
String formatKm(double meters) => (meters / 1000).toStringAsFixed(2);
