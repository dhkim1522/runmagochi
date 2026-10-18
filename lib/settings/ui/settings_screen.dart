import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/avatar_name.dart';
import '../../avatar/domain/growth_state.dart';
import '../../avatar/ui/weekly_goal_bar.dart';
import '../../avatar/ui/weekly_target_change.dart';
import '../../backup/app/backup_service.dart';
import '../../backup/app/providers.dart';
import '../../backup/ui/refresh_after_import.dart';
import '../../core/app_info.dart';
import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../../profile/app/providers.dart';

/// 체중(kg). 입력하지 않았으면 null. 저장하거나 가져온 뒤 invalidate 한다.
final _weightProvider = FutureProvider.autoDispose<double?>(
  (ref) => ref.read(profileRepositoryProvider).weightKg(),
);

/// 체중으로 받을 수 있는 범위(kg).
const double _minWeightKg = 30;
const double _maxWeightKg = 200;

/// 72 → `72`, 65.5 → `65.5`.
String _kgLabel(double kg) {
  final r = (kg * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
}

/// 설정: 체중, 이번 주 목표, 아바타 이름, 백업 내보내기·가져오기, 정보.
/// 홈 오른쪽 위 톱니로 들어온다. 시안 design/mockups/Settings.dc.html
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// 백업 작업 중이면 두 버튼을 끈다(두 번 누름 방지).
  bool _backupBusy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editWeight(double? current) async {
    final result = await showDialog<_WeightResult>(
      context: context,
      builder: (_) =>
          _WeightDialog(initial: current == null ? '' : _kgLabel(current)),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(profileRepositoryProvider).setWeightKg(result.kg);
    } catch (_) {
      _toast('체중을 저장하지 못했어요');
    }
    if (mounted) ref.invalidate(_weightProvider);
  }

  Future<void> _editTarget(double targetM) async {
    final m = await showWeeklyTargetDialog(context, targetM);
    if (m == null || !mounted) return;
    await changeWeeklyTarget(context, ref, m);
  }

  Future<void> _editName(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: current),
    );
    if (name == null || !mounted) return;
    try {
      await ref.read(growthRepositoryProvider).setAvatarName(name);
    } catch (_) {
      _toast('이름을 바꾸지 못했어요');
    }
    if (mounted) ref.invalidate(growthStateProvider);
  }

  Future<void> _runBackup(
    Future<BackupResult> Function(BackupService s) job,
    String doneMessage, {
    bool refresh = false,
  }) async {
    setState(() => _backupBusy = true);
    final BackupResult result;
    try {
      result = await job(ref.read(backupServiceProvider));
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
    if (!mounted) return;
    switch (result) {
      case BackupDone():
        if (refresh) {
          refreshAfterImport(ref);
          ref.invalidate(_weightProvider);
        }
        _toast(doneMessage);
      case BackupCancelled():
        break;
      case BackupBlockedByRun():
        _toast('러닝 중에는 할 수 없어요');
      case BackupFailed(:final message):
        _toast(message);
    }
  }

  Future<void> _export() => _runBackup((s) => s.export(), '백업 파일을 저장했어요');

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('백업 파일을 가져올까요?'),
        content: const Text('지금 데이터가 모두 백업 내용으로 바뀌어요. 되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('가져오기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _runBackup((s) => s.import(), '백업을 가져왔어요', refresh: true);
  }

  void _openLicenses() => showLicensePage(
    context: context,
    applicationName: '런마고치',
    applicationVersion: appVersion,
  );

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final GrowthState? g = ref.watch(growthStateProvider).value;
    final weight = ref.watch(_weightProvider);
    final weightLabel = switch (weight) {
      AsyncData(:final value) =>
        value == null ? '입력 안 함' : '${_kgLabel(value)}kg',
      _ => '-',
    };
    final VoidCallback? back = _backupBusy
        ? null
        : () => Navigator.of(context).maybePop();
    // 백업 작업 중에는 나가지 못하게 한다. 가져오기 뒤 화면 상태를 다시 읽어야 한다.
    return PopScope(
      canPop: !_backupBusy,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s5, Gap.s6),
            children: [
              Row(
                children: [
                  Semantics(
                    container: true,
                    button: true,
                    label: '뒤로',
                    excludeSemantics: true,
                    enabled: back != null,
                    onTap: back,
                    child: IconButton(
                      key: const ValueKey('settings-back'),
                      onPressed: back,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      icon: Icon(Icons.chevron_left, size: 32, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: Gap.s1),
                  const Flexible(child: ScreenTitle('설정')),
                ],
              ),
              const _SectionLabel('내 정보'),
              _RowsCard(
                children: [
                  _SettingsRow(
                    title: '체중',
                    subtitle: '칼로리 계산에만 써요',
                    value: weightLabel,
                    onTap: weight.hasValue
                        ? () => _editWeight(weight.value)
                        : null,
                  ),
                ],
              ),
              const _SectionLabel('러닝 · 아바타'),
              _RowsCard(
                children: [
                  _SettingsRow(
                    title: '이번 주 목표',
                    value: g == null
                        ? '-'
                        : '${WeeklyGoalBar.targetLabel(g.weekTargetM)}km',
                    onTap: g == null ? null : () => _editTarget(g.weekTargetM),
                  ),
                  _SettingsRow(
                    title: '아바타 이름',
                    value: g?.name ?? '-',
                    onTap: g == null ? null : () => _editName(g.name),
                  ),
                ],
              ),
              const _SectionLabel('백업'),
              ClayCard(
                padding: const EdgeInsets.all(Gap.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '기기를 바꿀 때 백업 파일로 기록을 옮겨요. 가져오면 지금 데이터는 백업 내용으로 모두 바뀌어요.',
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(height: Gap.s3),
                    Row(
                      children: [
                        Expanded(
                          child: ClayButton.accent(
                            context,
                            label: '내보내기',
                            onPressed: _backupBusy ? null : _export,
                          ),
                        ),
                        const SizedBox(width: Gap.s3),
                        Expanded(
                          child: ClayButton(
                            label: '가져오기',
                            onPressed: _backupBusy ? null : _import,
                            background: c.surfaceSoft,
                            foreground: c.ink,
                            lip: c.lineStrong,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const _SectionLabel('정보'),
              _RowsCard(
                children: [
                  _SettingsRow(title: '오픈소스 라이선스', onTap: _openLicenses),
                  _SettingsRow(title: '버전', detail: appVersion),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 묶음 이름(label, ink-muted). 위 묶음과 간격을 두고 카드 바로 위에 붙는다.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.s1, Gap.s4, Gap.s1, Gap.s2),
      child: Text(
        text,
        style: AppText.of(context).label.copyWith(color: c.inkMuted),
      ),
    );
  }
}

/// 행을 담는 클레이 카드. 행 사이에 2px line 구분선을 긋는다.
class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ClayCard(
      child: ClipRRect(
        // 눌림 물결이 둥근 모서리 밖으로 나가지 않게 테두리 안쪽에 맞춰 자른다.
        borderRadius: BorderRadius.circular(Radii.lg - Borders.thick),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, row) in children.indexed) ...[
                if (i > 0) Divider(height: 2, thickness: 2, color: c.line),
                row,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 설정 한 줄. [value] 가 있으면 오른쪽에 primary-deep 값과 꺾쇠, [detail] 은 흐린 글자.
/// [onTap] 이 있으면 하나의 버튼 노드("제목, 값")로 읽힌다.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    this.subtitle,
    this.value,
    this.detail,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final tappable = onTap != null || value != null;
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: subtitle != null ? 64 : 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: Gap.s3,
          horizontal: Gap.s4,
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final maxWidth = box.maxWidth;
            return Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.bodyStrong),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: Gap.s2),
                  ConstrainedBox(
                    // 긴 이름은 줄 너비의 절반까지만 쓰고 말줄임한다.
                    constraints: BoxConstraints(maxWidth: maxWidth / 2),
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: t.heading.copyWith(color: c.primaryDeep),
                    ),
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(width: Gap.s2),
                  Text(
                    detail!,
                    style: t.label.copyWith(
                      color: c.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (tappable) ...[
                  const SizedBox(width: Gap.s1),
                  Icon(Icons.chevron_right, size: 24, color: c.primaryDeep),
                ],
              ],
            );
          },
        ),
      ),
    );
    if (!tappable) {
      return MergeSemantics(child: content);
    }
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: value == null ? title : '$title, $value',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// 체중 창의 결과. [kg] 가 null 이면 체중을 지운다.
class _WeightResult {
  const _WeightResult(this.kg);
  final double? kg;
}

class _WeightDialog extends StatefulWidget {
  const _WeightDialog({required this.initial});
  final String initial;

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 비었으면 지우기, 30~200 이면 그 값(소수 첫째 자리), 아니면 null(저장 불가).
  _WeightResult? get _result {
    final text = _controller.text.trim();
    if (text.isEmpty) return const _WeightResult(null);
    final v = double.tryParse(text);
    if (v == null || !v.isFinite || v < _minWeightKg || v > _maxWeightKg) {
      return null;
    }
    return _WeightResult((v * 10).round() / 10);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AlertDialog(
      title: const Text('체중'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: InputDecoration(
          suffixText: 'kg',
          helperText: '비워 두면 65kg 으로 계산해요',
          errorText: result == null ? '30~200kg 사이로 입력해 주세요' : null,
        ),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: result == null
              ? null
              : () => Navigator.of(context).pop(result),
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = validateAvatarName(_controller.text);
    return AlertDialog(
      title: const Text('아바타 이름'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: avatarNameMaxLength,
        decoration: InputDecoration(errorText: error),
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: error == null
              ? () => Navigator.of(context).pop(_controller.text.trim())
              : null,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
