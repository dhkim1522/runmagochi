import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ui/clay.dart';
import '../app/permission_gate.dart';

class PermissionScreen extends ConsumerStatefulWidget {
  const PermissionScreen({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  ConsumerState<PermissionScreen> createState() => _PermissionScreenState();
}

const _locationMessage = '러닝 경로와 거리를 기록하려면 위치 권한이 필요합니다. 위치는 이 기기에만 저장됩니다.';
const _preciseMessage = '정확한 위치를 허용해야 거리가 기록됩니다';

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
          ClayButton(
            onPressed: () => _apply(gate.requestLocation),
            label: '권한 허용',
          ),
        ],
      ),
      GateResult.locationDeniedForever => (
        '설정에서 위치 권한을 허용해 주세요',
        [ClayButton(onPressed: gate.openAppSettings, label: '설정 열기')],
      ),
      GateResult.needsBatteryGuide => (
        '배터리 최적화가 켜져 있으면 화면이 꺼졌을 때 기록이 끊길 수 있습니다. 설정에서 배터리 사용을 제한 없음으로 바꿔 주세요.',
        [
          ClayButton(onPressed: gate.openBatterySettings, label: '설정 열기'),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.of(context).inkMuted,
              textStyle: AppText.of(context).label,
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
        [ClayButton(onPressed: () => _apply(gate.check), label: '다시 시도')],
      ),
      _ => ('', <Widget>[]),
    };

    final c = AppColors.of(context);
    final t = AppText.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s6, Gap.s5, Gap.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenTitle('권한 안내'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (message.isNotEmpty)
                          ClayCard(
                            padding: const EdgeInsets.all(Gap.s5),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: t.body,
                                ),
                                if (_result ==
                                    GateResult.needsPreciseLocation) ...[
                                  const SizedBox(height: Gap.s2),
                                  Text(
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
                        const SizedBox(height: Gap.s6),
                        if (_result == null && !_failed)
                          const Center(child: CircularProgressIndicator()),
                        ...actions,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
