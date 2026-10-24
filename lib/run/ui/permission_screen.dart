import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/permission_gate.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

const _locationMessage = '러닝 경로와 거리를 기록하려면 위치 권한이 필요해요.\n위치는 이 기기에만 저장돼요.';
const _preciseMessage = '정확한 위치를 허용해야 거리가 기록돼요';

class _PermissionScreenState extends ConsumerState<PermissionScreen>
    with WidgetsBindingObserver {
  GateResult? _result;
  bool _failed = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(ref.read(permissionGateProvider).check);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 설정 화면에서 돌아오면 다시 확인한다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_done) {
      _apply(ref.read(permissionGateProvider).check);
    }
  }

  Future<void> _apply(Future<GateResult> Function() action) async {
    if (_done) return;
    GateResult? result;
    try {
      result = await action();
    } catch (_) {
      result = null;
    }
    if (!mounted || _done) return;
    setState(() {
      _result = result;
      _failed = result == null;
    });
    if (result == GateResult.ready) _finish();
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onReady();
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.read(permissionGateProvider);
    final (message, actions) = switch (_result) {
      GateResult.needsLocation || GateResult.needsPreciseLocation => (
        _locationMessage,
        [
          AppButton(
            onPressed: () => _apply(gate.requestLocation),
            label: '권한 허용',
          ),
        ],
      ),
      GateResult.locationDeniedForever => (
        '설정에서 위치 권한을 허용해 주세요',
        [AppButton(onPressed: gate.openAppSettings, label: '설정 열기')],
      ),
      GateResult.needsBatteryGuide => (
        '배터리 최적화가 켜져 있으면 화면이 꺼졌을 때 기록이 끊길 수 있어요.\n'
            '설정에서 배터리 사용을 ‘제한 없음’으로 바꿔 주세요.',
        [
          AppButton(onPressed: gate.openBatterySettings, label: '설정 열기'),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.of(context).ink,
              textStyle: AppText.of(context).bodyStrong,
            ),
            onPressed: () {
              gate.dismissBatteryGuide();
              _finish();
            },
            child: const Text('나중에'),
          ),
        ],
      ),
      _ when _failed => (
        _locationMessage,
        [AppButton(onPressed: () => _apply(gate.check), label: '다시 시도')],
      ),
      _ => ('', <Widget>[]),
    };

    final c = AppColors.of(context);
    final t = AppText.of(context);
    final icon = _result == GateResult.needsBatteryGuide
        ? Icons.battery_alert_outlined
        : Icons.location_on_outlined;
    final loading = _result == null && !_failed;
    // 머리줄 → 흰 카드(무대색 동그라미 그림 + 안내) → 화면 아래 버튼.
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTitle('권한 안내'),
              const SizedBox(height: Gap.s5),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: message.isEmpty
                            ? const SizedBox.shrink()
                            : AppCard(
                                padding: const EdgeInsets.fromLTRB(
                                  Gap.s5,
                                  Gap.s8,
                                  Gap.s5,
                                  Gap.s6,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Center(
                                      child: ExcludeSemantics(
                                        child: DecoratedBox(
                                          key: const ValueKey(
                                            'permission-icon',
                                          ),
                                          decoration: BoxDecoration(
                                            color: c.stageSky,
                                            shape: BoxShape.circle,
                                          ),
                                          child: SizedBox.square(
                                            dimension: 72,
                                            child: Icon(
                                              icon,
                                              size: 36,
                                              color: c.stageInk,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: Gap.s5),
                                    KeepAllText(
                                      message,
                                      textAlign: TextAlign.center,
                                      style: t.body,
                                    ),
                                    if (_result ==
                                        GateResult.needsPreciseLocation) ...[
                                      const SizedBox(height: Gap.s3),
                                      KeepAllText(
                                        _preciseMessage,
                                        textAlign: TextAlign.center,
                                        style: t.bodyStrong.copyWith(
                                          color: c.primaryDeep,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
              ),
              if (actions.isNotEmpty) const SizedBox(height: Gap.s4),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}
