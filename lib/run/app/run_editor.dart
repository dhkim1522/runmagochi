import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_state.dart';
import '../domain/run_summary.dart';
import 'providers.dart';

/// 끝낸 러닝을 고친다. 지금은 요약 화면의 끝부분 잘라내기만 한다.
class RunEditor {
  RunEditor(this._ref);

  final Ref _ref;

  /// 방금 끝낸 러닝의 끝을 [newEnd] 로 앞당긴다.
  ///
  /// 1. 메모리의 원본 점으로 요약을 다시 계산하고(`trimRunEnd`, 종료 때 체중)
  ///    저장소의 요약·경로·구간을 바꾼다. 컨트롤러의 lastSummary 도 바뀐다.
  /// 2. 그 러닝의 거리 경험치를 새 거리로 다시 매기고 그 주 목표를 다시
  ///    판정한다(`GrowthService.runRevised`). 레벨이 내려갈 수 있다.
  ///
  /// [shown] 은 요약 화면이 지금 보여 주는 gain(종료 직후 sync 결과, 또는 앞선
  /// 잘라내기의 결과)이다. 돌려주는 gain 은 [shown] 에 이번 변화를 더한 것으로,
  /// 그대로 화면에 보여 주고 다음 잘라내기 때 [shown] 으로 넘긴다. [shown] 이
  /// null 이거나 경험치 계산이 실패하면(Exception) null 이다. 기록은 이미 바뀌었고
  /// 경험치는 다음 sync 가 새 거리로 고친다. 같은
  /// [newEnd] 로 다시 부르면 기록은 그대로이고 경험치 계산만 다시 한다.
  ///
  /// 끝낸 러닝이 없으면 [StateError], [newEnd] 가 범위 밖이면 [ArgumentError],
  /// 기록 저장이 실패하면 그 오류를 던진다. 이때 기록과 경험치는 그대로다.
  /// 성장 화면 상태(growthStateProvider)는 다시 계산하게 한다.
  Future<(RunSummary, GrowthGain?)> trimLastRun(
    DateTime newEnd, {
    GrowthGain? shown,
  }) async {
    final (runId, trimmed) = await _ref
        .read(runControllerProvider.notifier)
        .trimLastSummary(newEnd);
    GrowthGain? delta;
    try {
      delta = await _ref
          .read(growthServiceProvider)
          .runRevised(runId, trimmed.startedAt);
    } on Exception {
      delta = null;
    }
    _ref.invalidate(growthStateProvider);
    if (shown == null || delta == null) return (trimmed, null);
    return (trimmed, shown.revisedBy(delta));
  }
}

final runEditorProvider = Provider<RunEditor>(RunEditor.new);
