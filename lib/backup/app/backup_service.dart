import 'dart:convert';
import 'dart:typed_data';

import '../../avatar/app/growth_service.dart';
import '../../core/clock.dart';
import '../data/backup_file_store.dart';
import '../data/backup_repository.dart';
import '../domain/backup_codec.dart';

/// 백업 작업의 결과.
sealed class BackupResult {
  const BackupResult();
}

/// 끝까지 성공했다.
class BackupDone extends BackupResult {
  const BackupDone();
}

/// 사용자가 저장 위치·파일 선택을 취소했다. 아무것도 바뀌지 않는다.
class BackupCancelled extends BackupResult {
  const BackupCancelled();
}

/// 러닝이 진행 중이라 막았다. 파일 선택창도 띄우지 않는다.
class BackupBlockedByRun extends BackupResult {
  const BackupBlockedByRun();
}

/// 실패했다. [message] 는 화면에 그대로 보여 줄 수 있는 한국어 문장이다.
class BackupFailed extends BackupResult {
  const BackupFailed(this.message);
  final String message;
}

/// 백업 내보내기·가져오기 흐름 (결정 0015).
///
/// 가져오기는 기존 데이터를 모두 백업 내용으로 바꾼다. 화면(설정)은 [import] 를 부르기 전에
/// "지금 데이터가 모두 백업 내용으로 바뀌어요" 확인을 먼저 받고, 성공하면 `refreshAfterImport`(lib/backup/ui) 로
/// 화면 상태를 다시 읽는다.
class BackupService {
  BackupService(
    this._repository,
    this._files,
    this._growth,
    this._isRunActive,
    this._clock,
  );

  final BackupRepository _repository;
  final BackupFileStore _files;
  final GrowthService _growth;

  /// 러닝이 기록 중이거나 일시정지 중인지 알려 준다.
  final Future<bool> Function() _isRunActive;
  final Clock _clock;

  /// 러닝 중에는 일관된 스냅샷을 위해 내보내기도 막는다.
  Future<BackupResult> export() async {
    try {
      if (await _isRunActive()) return const BackupBlockedByRun();
      final now = _clock();
      final json = await _repository.exportJson(now);
      final saved = await _files.save(
        fileName(now),
        Uint8List.fromList(utf8.encode(json)),
      );
      return saved ? const BackupDone() : const BackupCancelled();
    } catch (_) {
      return const BackupFailed('백업 파일을 저장하지 못했어요');
    }
  }

  Future<BackupResult> import() async {
    try {
      if (await _isRunActive()) return const BackupBlockedByRun();
      final json = await _files.pickJson();
      if (json == null) return const BackupCancelled();
      // 도는 중인 성장 계산이 옛 DB 의 러닝 경험치를 새 DB 에 쓰지 않도록
      // 성장 계산과 같은 줄에서 바꾼다.
      await _growth.exclusive(() => _repository.importJson(json));
    } on BackupFormatException catch (e) {
      return BackupFailed(e.message);
    } catch (_) {
      return const BackupFailed('백업 파일을 가져오지 못했어요');
    }
    // 데이터는 이미 들어갔다. 성장 재계산이 실패해도 가져오기는 성공이다.
    try {
      await _growth.sync();
    } catch (_) {}
    return const BackupDone();
  }

  /// 기록·캐릭터 데이터를 지우고 첫 실행으로 돌아갈 준비를 한다. 설정값은 남긴다.
  /// 화면(설정)은 부르기 전에 확인을 받고, 성공하면 첫 실행 화면을 다시 띄운다.
  Future<BackupResult> reset() async {
    try {
      if (await _isRunActive()) return const BackupBlockedByRun();
      // 도는 중인 성장 계산이 지운 뒤에 옛 경험치를 쓰지 않도록 같은 줄에서 지운다.
      await _growth.exclusive(() => _repository.resetData(_clock()));
      return const BackupDone();
    } catch (_) {
      return const BackupFailed('데이터를 지우지 못했어요');
    }
  }

  /// `runmagochi-backup-YYYYMMDD.json` (기기 로컬 날짜).
  static String fileName(DateTime now) {
    final d = now.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'runmagochi-backup-${d.year.toString().padLeft(4, '0')}${two(d.month)}${two(d.day)}.json';
  }
}
