/// 전체 데이터를 JSON 파일 하나로 내보내고 가져온다 (결정 0015).
abstract interface class BackupRepository {
  /// 완료된 러닝과 부속 데이터를 JSON 문자열로 만든다. 진행 중 러닝·RunPoint 는 뺀다.
  Future<String> exportJson(DateTime now);

  /// 기존 데이터를 모두 지우고 [json] 으로 바꾼다. 형식이 틀리면 DB 를 건드리지 않고
  /// BackupFormatException 을 던진다. 쓰기는 한 트랜잭션이다.
  Future<void> importJson(String json);
}
