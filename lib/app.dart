import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar/app/providers.dart';
import 'avatar/ui/avatar_screen.dart';
import 'core/home_tab.dart';
import 'core/theme.dart';
import 'core/ui/components.dart';
import 'onboarding/ui/onboarding_screen.dart';
import 'profile/app/providers.dart';
import 'run/ui/history_screen.dart';
import 'run/ui/home_screen.dart';
import 'shop/ui/shop_screen.dart';

class RunmagochiApp extends ConsumerWidget {
  const RunmagochiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '런마고치',
      theme: appLightTheme(),
      darkTheme: appDarkTheme(),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
      home: const _OnboardingGate(),
    );
  }
}

/// 첫 실행을 마쳤는지 읽어 첫 실행 화면 또는 홈을 보여 준다.
/// 읽는 동안은 빈 바탕 화면이라 홈이 잠깐 비치지 않는다. 홈(권한 안내·복구 창 포함)은
/// 첫 실행을 마친 뒤에야 만든다. 설정에서 초기화하면 [onboardedProvider] 가 다시 읽혀
/// 첫 실행 화면으로 돌아간다.
class _OnboardingGate extends ConsumerStatefulWidget {
  const _OnboardingGate();

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  @override
  void initState() {
    super.initState();
    _cancelOldReminders();
  }

  /// 이전 버전이 예약해 둔 주간 알림을 지운다. 기다리지 않고, 실패는 로그만 남긴다.
  void _cancelOldReminders() {
    ref
        .read(notificationSchedulerProvider)
        .cancelScheduled()
        .catchError((Object e) => debugPrint('알림: 예약 취소 실패 $e'));
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(onboardedProvider).value) {
      null => const Scaffold(),
      false => OnboardingScreen(
        onFinished: () => ref.invalidate(onboardedProvider),
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
    final countingDown = ref.watch(runCountdownProvider);
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
      // 카운트다운 중에는 러닝 중 화면처럼 탭을 숨긴다.
      bottomNavigationBar: countingDown
          ? null
          : AppTabBar(
              tabs: _tabs,
              index: index,
              onSelected: ref.read(homeTabProvider.notifier).select,
            ),
    );
  }
}

const _tabs = [
  AppTab(TabGlyph.run, '러닝'),
  AppTab(TabGlyph.history, '기록'),
  AppTab(TabGlyph.avatar, '아바타'),
  AppTab(TabGlyph.shop, '상점'),
];
