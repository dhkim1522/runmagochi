import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'avatar/app/providers.dart';
import 'avatar/ui/avatar_screen.dart';
import 'core/home_tab.dart';
import 'core/stage/stage_weather.dart';
import 'core/theme.dart';
import 'core/ui/components.dart';
import 'onboarding/ui/onboarding_screen.dart';
import 'profile/app/providers.dart';
import 'reminder/app/providers.dart';
import 'run/ui/history_screen.dart';
import 'run/ui/home_screen.dart';
import 'shop/ui/shop_screen.dart';
import 'weather/app/weather_controller.dart';
import 'widget/pet_widget_sync.dart';

class RunmagochiApp extends ConsumerWidget {
  const RunmagochiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: '런마고치',
      theme: appLightTheme(),
      darkTheme: appDarkTheme(),
      themeMode: ref.watch(themeModeProvider).value ?? ThemeMode.system,
      // 무대들이 받은 날씨를 입는다(F25). 받기 전에는 맑은 낮.
      builder: (context, child) => StageWeatherScope(
        weather: ref.watch(stageWeatherProvider),
        child: child!,
      ),
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
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _cancelOldReminders();
    _refreshWeather();
    // 화면으로 돌아올 때 날씨가 30분 넘게 묵었으면 다시 받는다.
    _lifecycle = AppLifecycleListener(onResume: _refreshWeather);
  }

  void _refreshWeather() =>
      ref.read(stageWeatherProvider.notifier).refreshIfStale();

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 이전 버전이 예약해 둔 주간 알림을 지운 뒤 쉬는 날 알림(F27)을 다시 예약한다.
  /// 예약 취소는 대기 중인 알림을 모두 지우므로 반드시 그다음에 예약한다.
  /// 기다리지 않고, 실패는 로그만 남긴다.
  void _cancelOldReminders() {
    final reminders = ref.read(reminderServiceProvider);
    ref
        .read(notificationSchedulerProvider)
        .cancelScheduled()
        .catchError((Object e) => debugPrint('알림: 예약 취소 실패 $e'))
        .then((_) => reminders.refresh());
  }

  @override
  Widget build(BuildContext context) {
    return switch (ref.watch(onboardedProvider).value) {
      null => const Scaffold(),
      false => OnboardingScreen(
        onFinished: () => ref.invalidate(onboardedProvider),
      ),
      // 홈 화면 위젯 그림은 첫 실행을 마친 뒤부터 그린다(F29).
      true => const PetWidgetSync(child: _HomeShell()),
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
