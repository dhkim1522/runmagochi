// iOS 시뮬레이터(flutter run 없이 simctl 로 띄운 디버그 앱)를 Dart VM 서비스로 조작한다.
// simctl 에는 탭 명령이 없어서, 앱 안으로 Flutter 포인터 이벤트를 직접 넣는다.
//
// 사용: dart tool/capture/vm_ui.dart <VM 서비스 주소> <명령> [인자]
//   banner                  DEBUG 띠를 끈다
//   tap X Y                 논리 좌표(iPhone 16 Pro: 402×874)를 누른다
//   hold X Y MS             MS 밀리초 동안 누른다
//   swipe X1 Y1 X2 Y2 MS    끈다
//   text                    화면 맨 위 글자 확인용으로 위젯 트리 일부를 찍는다(생략 가능)
// 주소는 `xcrun simctl spawn <기기> log show --last 3m --predicate 'eventMessage CONTAINS "Dart VM service"'` 에서 얻는다.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

late WebSocket _ws;
int _id = 0;
final _pending = <int, Completer<Map<String, dynamic>>>{};

Future<Map<String, dynamic>> call(
  String method, [
  Map<String, dynamic>? params,
]) {
  final id = ++_id;
  final c = Completer<Map<String, dynamic>>();
  _pending[id] = c;
  _ws.add(
    jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params ?? {},
    }),
  );
  return c.future;
}

Future<void> main(List<String> a) async {
  final url = '${a[0].replaceFirst('http://', 'ws://')}ws';
  _ws = await WebSocket.connect(url);
  _ws.listen((m) {
    final j = jsonDecode(m as String) as Map<String, dynamic>;
    final c = _pending.remove(j['id']);
    if (c != null) c.complete(j);
  });
  final vm = (await call('getVM'))['result'] as Map<String, dynamic>;
  final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
  final iso =
      isolates.firstWhere(
            (i) => i['name'] == 'main',
            orElse: () => isolates.first,
          )['id']
          as String;
  final isolate =
      (await call('getIsolate', {'isolateId': iso}))['result']
          as Map<String, dynamic>;
  String libId(String uri) =>
      (isolate['libraries'] as List).cast<Map<String, dynamic>>().firstWhere(
            (l) => l['uri'] == uri,
          )['id']
          as String;
  final eventsLib = libId('package:flutter/src/gestures/events.dart');
  final bindingLib = libId('package:flutter/src/gestures/binding.dart');

  // 이벤트 객체는 events.dart 쪽에서 만들고(Offset·이벤트 클래스가 보이는 곳),
  // binding.dart 쪽에서 GestureBinding 에 넘긴다(두 곳에 다 보이는 이름이 없어서 객체 id 로 잇는다).
  Future<void> send(String kind, double x, double y) async {
    final made = await call('evaluate', {
      'isolateId': iso,
      'targetId': eventsLib,
      'expression': '$kind(pointer: 7, position: Offset($x, $y))',
    });
    if (made['error'] != null) {
      stderr.writeln(jsonEncode(made['error']));
      exit(1);
    }
    final id = (made['result'] as Map<String, dynamic>)['id'] as String;
    final r = await call('evaluate', {
      'isolateId': iso,
      'targetId': bindingLib,
      'expression':
          'GestureBinding.instance.handlePointerEvent(e as PointerEvent)',
      'scope': {'e': id},
    });
    if (r['error'] != null) {
      stderr.writeln(jsonEncode(r['error']));
      exit(1);
    }
  }

  Future<void> eval(String kindXY) async {
    final p = kindXY.split('|');
    await send(p[0], double.parse(p[1]), double.parse(p[2]));
  }

  String ev(String kind, double x, double y) => '$kind|$x|$y';

  switch (a[1]) {
    case 'banner':
      await call('ext.flutter.debugAllowBanner', {
        'isolateId': iso,
        'enabled': 'false',
      });
    case 'tap':
      final x = double.parse(a[2]), y = double.parse(a[3]);
      await eval(ev('PointerAddedEvent', x, y));
      await eval(ev('PointerDownEvent', x, y));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await eval(ev('PointerUpEvent', x, y));
      await eval(ev('PointerRemovedEvent', x, y));
    case 'hold':
      final x = double.parse(a[2]), y = double.parse(a[3]);
      await eval(ev('PointerAddedEvent', x, y));
      await eval(ev('PointerDownEvent', x, y));
      await Future<void>.delayed(Duration(milliseconds: int.parse(a[4])));
      await eval(ev('PointerUpEvent', x, y));
      await eval(ev('PointerRemovedEvent', x, y));
    case 'swipe':
      final x1 = double.parse(a[2]), y1 = double.parse(a[3]);
      final x2 = double.parse(a[4]), y2 = double.parse(a[5]);
      final ms = int.parse(a[6]);
      const steps = 20;
      await eval(ev('PointerAddedEvent', x1, y1));
      await eval(ev('PointerDownEvent', x1, y1));
      for (var i = 1; i <= steps; i++) {
        await Future<void>.delayed(Duration(milliseconds: ms ~/ steps));
        await eval(
          ev(
            'PointerMoveEvent',
            x1 + (x2 - x1) * i / steps,
            y1 + (y2 - y1) * i / steps,
          ),
        );
      }
      await eval(ev('PointerUpEvent', x2, y2));
      await eval(ev('PointerRemovedEvent', x2, y2));
    default:
      stderr.writeln('알 수 없는 명령 ${a[1]}');
      exit(2);
  }
  await _ws.close();
}
