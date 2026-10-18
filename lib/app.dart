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
