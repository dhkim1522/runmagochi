/// 주의 시작(월요일 0시, 현지)을 돌려준다.
DateTime weekStartOf(DateTime t) {
  final local = t.toLocal();
  // DateTime 생성자의 day 연산으로 구한다 (일광절약 시간 영향 없음).
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}
