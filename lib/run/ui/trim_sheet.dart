import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../domain/run_summary.dart';
import '../domain/run_trim.dart';

/// 끝 시각을 고르는 시트. 고른 끝 시각을 돌려주고, 취소하거나 원래 끝 그대로면 null.
Future<DateTime?> showTrimSheet(BuildContext context, RunSummary summary) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.of(context).cream,
    builder: (_) => TrimSheet(summary: summary),
  );
}

/// 끝으로 고를 수 있는 시각: 점들의 시각(첫 점부터)과 원래 끝. 오름차순, 중복 없음.
List<DateTime> trimCandidates(RunSummary s) {
  final times = <DateTime>{
    for (final p in s.points)
      if (!p.time.isAfter(s.endedAt) && !p.time.isBefore(s.startedAt)) p.time,
    s.endedAt,
  }.toList()..sort();
  return times;
}

String _clock(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
}

class TrimSheet extends StatefulWidget {
  const TrimSheet({super.key, required this.summary});
  final RunSummary summary;

  @override
  State<TrimSheet> createState() => _TrimSheetState();
}

class _TrimSheetState extends State<TrimSheet> {
  late final List<DateTime> _times = trimCandidates(widget.summary);
  late int _index = _times.length - 1;

  bool get _atOriginal => _index == _times.length - 1;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final end = _times[_index];
    final preview = trimRunEnd(widget.summary, end);
    final canMove = _times.length > 1;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        Gap.s5,
        Gap.s5,
        Gap.s5,
        Gap.s4 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('끝부분 잘라내기', style: t.titleS),
          ),
          const SizedBox(height: Gap.s2),
          Text(
            '종료를 늦게 눌렀다면 끝 시각을 앞으로 당겨요.',
            style: t.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: Gap.s5),
          Text('끝 시각 ${_clock(end)}', style: t.heading),
          const SizedBox(height: Gap.s1),
          Text(
            '거리 ${formatKm(preview.distanceM)}km · 시간 ${formatDuration(preview.movingTime)}',
            style: t.body,
          ),
          const SizedBox(height: Gap.s3),
          Semantics(
            label: '끝 시각',
            child: Slider(
              value: _index.toDouble(),
              min: 0,
              max: (_times.length - 1).toDouble(),
              divisions: canMove ? _times.length - 1 : null,
              semanticFormatterCallback: (v) => _clock(_times[v.round()]),
              onChanged: canMove
                  ? (v) => setState(() => _index = v.round())
                  : null,
            ),
          ),
          const SizedBox(height: Gap.s3),
          Row(
            children: [
              Expanded(
                child: ClayButton(
                  label: '취소',
                  background: c.surface,
                  foreground: c.ink,
                  lip: c.line,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: Gap.s3),
              Expanded(
                child: ClayButton(
                  label: '잘라내기',
                  onPressed: _atOriginal
                      ? null
                      : () => Navigator.of(context).pop(end),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
