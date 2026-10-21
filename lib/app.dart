import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar/app/providers.dart';
import 'avatar/ui/avatar_screen.dart';
import 'core/home_tab.dart';
import 'core/theme.dart';
import 'onboarding/ui/onboarding_screen.dart';
import 'profile/app/providers.dart';
import 'run/ui/history_screen.dart';
import 'run/ui/home_screen.dart';
import 'shop/ui/shop_screen.dart';

class RunmagochiApp extends StatelessWidget {
  const RunmagochiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '런마고치',
      theme: appLightTheme(),
      darkTheme: appDarkTheme(),
      themeMode: ThemeMode.system,
      home: const _OnboardingGate(),
    );
  }
}

/// 첫 실행을 마쳤는지 읽어 첫 실행 화면 또는 홈을 보여 준다.
/// 읽는 동안은 빈 크림 화면이라 홈이 잠깐 비치지 않는다. 홈(권한 안내·복구 창 포함)은
/// 첫 실행을 마친 뒤에야 만든다.
class _OnboardingGate extends ConsumerStatefulWidget {
  const _OnboardingGate();

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  bool? _onboarded;

  @override
  void initState() {
    super.initState();
    _cancelOldReminders();
    _read();
  }

  /// 이전 버전이 예약해 둔 주간 알림을 지운다. 기다리지 않고, 실패는 로그만 남긴다.
  void _cancelOldReminders() {
    ref
        .read(notificationSchedulerProvider)
        .cancelScheduled()
        .catchError((Object e) => debugPrint('알림: 예약 취소 실패 $e'));
  }

  Future<void> _read() async {
    bool done;
    try {
      done = await ref.read(profileRepositoryProvider).isOnboarded();
    } catch (_) {
      // 읽지 못하면 사용자를 첫 실행에 가두지 않고 홈으로 보낸다.
      done = true;
    }
    if (mounted) setState(() => _onboarded = done);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_onboarded) {
      null => const Scaffold(),
      false => OnboardingScreen(
        onFinished: () => setState(() => _onboarded = true),
      ),
      true => const _HomeShell(),
    };
  }
}

class _HomeShell extends ConsumerWidget {
  const _HomeShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    return Scaffold(
      body: IndexedStack(
        index: index,
        // 가려진 탭은 애니메이션을 돌리지 않는다.
        children: [
          for (final (i, screen) in const <Widget>[
            HomeScreen(),
            HistoryScreen(),
            AvatarScreen(),
            ShopScreen(),
          ].indexed)
            TickerMode(enabled: i == index, child: screen),
        ],
      ),
      bottomNavigationBar: _TabBar(
        index: index,
        onSelected: ref.read(homeTabProvider.notifier).select,
      ),
    );
  }
}

const _tabs = [
  (Icons.directions_run, '러닝'),
  (Icons.history, '기록'),
  (Icons.pets, '아바타'),
  (Icons.storefront, '상점'),
];

/// 하단 탭바: 위에 2px line 테두리, 선택은 primary-deep 굵게, 나머지는 ink-muted.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.cream,
        border: Border(top: BorderSide(color: c.line, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (i, (icon, label)) in _tabs.indexed)
              Expanded(
                child: _TabItem(
                  icon: icon,
                  label: label,
                  selected: i == index,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = widget.selected ? c.primaryDeep : c.inkMuted;
    final style = AppText.of(context).caption.copyWith(
      color: color,
      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
    );
    // 키보드 포커스는 Tab 으로 받고 Enter·Space 로 선택한다 (ActivateIntent).
    Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.s2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(widget.label, style: style),
          ],
        ),
      ),
    );
    if (_focused) {
      content = DecoratedBox(
        position: DecorationPosition.foreground,
        key: const ValueKey('tab-focus-ring'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm),
          border: Border.all(color: c.primaryDeep, width: Borders.thick),
        ),
        child: content,
      );
    }
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: content,
        ),
      ),
    );
  }
}
