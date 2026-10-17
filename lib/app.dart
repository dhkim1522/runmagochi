import 'package:flutter/material.dart';

import 'avatar/ui/avatar_screen.dart';
import 'core/theme.dart';
import 'run/ui/history_screen.dart';
import 'run/ui/home_screen.dart';

class RunmagochiApp extends StatelessWidget {
  const RunmagochiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '런마고치',
      theme: appLightTheme(),
      darkTheme: appDarkTheme(),
      themeMode: ThemeMode.system,
      home: const _HomeShell(),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        // 가려진 탭은 애니메이션을 돌리지 않는다.
        children: [
          for (final (i, screen) in const <Widget>[
            HomeScreen(),
            HistoryScreen(),
            AvatarScreen(),
          ].indexed)
            TickerMode(enabled: i == _index, child: screen),
        ],
      ),
      bottomNavigationBar: _TabBar(
        index: _index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

const _tabs = [
  (Icons.directions_run, '러닝'),
  (Icons.history, '기록'),
  (Icons.pets, '아바타'),
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

class _TabItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final color = selected ? c.primaryDeep : c.inkMuted;
    final style = AppText.of(context).caption.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Gap.s2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 24, color: color),
                const SizedBox(height: 2),
                Text(label, style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
