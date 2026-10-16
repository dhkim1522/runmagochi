import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/ui/avatar_placeholder.dart';
import '../../core/format.dart';
import '../app/permission_gate.dart';
import '../app/providers.dart';
import 'in_run_screen.dart';
import 'permission_screen.dart';

final weeklyTotalProvider = FutureProvider.autoDispose<(double, int)>(
  (ref) =>
      ref.read(runRepositoryProvider).weeklyTotal(ref.read(clockProvider)()),
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _countdown;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  Future<void> _restore() async {
    final controller = ref.read(runControllerProvider.notifier);
    final bool restored;
    try {
      restored = await controller.restoreIfAny();
    } catch (_) {
      return;
    }
    if (!restored || !mounted) return;
    final resume = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('기록 중이던 러닝이 있어요'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('종료하고 저장'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이어서 기록'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      await _openInRun();
    } else {
      try {
        await controller.end();
      } catch (_) {
        _toast('저장하지 못했어요');
      }
      ref.invalidate(weeklyTotalProvider);
    }
  }

  Future<void> _openInRun() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const InRunScreen()));
    ref.invalidate(weeklyTotalProvider);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onStart() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      if (!await _ensurePermission() || !mounted) return;
      for (var n = 3; n >= 1; n--) {
        setState(() => _countdown = n);
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
      try {
        await ref.read(runControllerProvider.notifier).start();
      } catch (_) {
        _toast('러닝을 시작하지 못했어요');
        return;
      }
      if (mounted) await _openInRun();
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _countdown = null;
        });
      }
    }
  }

  Future<bool> _ensurePermission() async {
    GateResult result;
    try {
      result = await ref.read(permissionGateProvider).check();
    } catch (_) {
      result = GateResult.needsLocation;
    }
    if (result == GateResult.ready) return true;
    if (!mounted) return false;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            PermissionScreen(onReady: () => Navigator.of(context).pop(true)),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final weekly = ref.watch(weeklyTotalProvider);
    final summary = weekly.when(
      data: (t) => '이번 주 ${formatKm(t.$1)} km · ${t.$2}회',
      loading: () => '이번 주 -',
      error: (_, _) => '이번 주 -',
    );
    return SafeArea(
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  summary,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                const Expanded(child: AvatarPlaceholder()),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _starting ? null : _onStart,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('시작'),
                  ),
                ),
              ],
            ),
          ),
          if (_countdown != null)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Text(
                    '$_countdown',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontSize: 120,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
