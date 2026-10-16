import 'package:flutter/material.dart';

import 'avatar/ui/avatar_placeholder.dart';
import 'run/ui/home_screen.dart';

class RunmagochiApp extends StatelessWidget {
  const RunmagochiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '런마고치',
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
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
        children: const [
          HomeScreen(),
          Center(child: Text('기록 화면')),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AvatarPlaceholder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_run), label: '러닝'),
          NavigationDestination(icon: Icon(Icons.history), label: '기록'),
          NavigationDestination(icon: Icon(Icons.pets), label: '아바타'),
        ],
      ),
    );
  }
}
