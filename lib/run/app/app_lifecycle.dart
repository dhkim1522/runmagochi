import 'dart:async';

import 'package:flutter/widgets.dart';

/// 앱이 화면에 있는지 알려 준다. 컨트롤러가 WidgetsBinding 을 직접 부르지
/// 않도록 사이에 둔다.
abstract class AppLifecycle {
  AppLifecycleState get current;
  Stream<AppLifecycleState> get changes;
}

/// Flutter 의 [AppLifecycleListener] 로 만든 실제 구현. 상태를 아직 모르면
/// 화면에 있는 것으로 본다.
class FlutterAppLifecycle implements AppLifecycle {
  FlutterAppLifecycle() {
    _listener = AppLifecycleListener(onStateChange: _controller.add);
  }

  final _controller = StreamController<AppLifecycleState>.broadcast();
  late final AppLifecycleListener _listener;

  @override
  AppLifecycleState get current =>
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  @override
  Stream<AppLifecycleState> get changes => _controller.stream;

  void dispose() {
    _listener.dispose();
    _controller.close();
  }
}
