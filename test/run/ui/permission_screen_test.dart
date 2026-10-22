import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/components.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/ui/permission_screen.dart';

class FakeGate implements PermissionGate {
  FakeGate(this.result, {this.afterRequest = GateResult.ready});
  GateResult result;
  GateResult afterRequest;
  int requested = 0;
  int settingsOpened = 0;
  int appSettingsOpened = 0;
  Object? checkError;
  Object? requestError;
  Completer<GateResult>? checkGate;
  int dismissed = 0;

  @override
  Future<GateResult> check() async {
    if (checkError != null) throw checkError!;
    if (checkGate != null) return checkGate!.future;
    return result;
  }

  @override
  Future<GateResult> requestLocation() async {
    requested++;
    if (requestError != null) throw requestError!;
    return result = afterRequest;
  }

  @override
  Future<void> openBatterySettings() async => settingsOpened++;

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  void dismissBatteryGuide() => dismissed++;
}

Future<void> pump(WidgetTester tester, FakeGate gate) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [permissionGateProvider.overrideWithValue(gate)],
      child: MaterialApp(
        theme: appLightTheme(),
        home: PermissionScreen(onReady: () {}),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('글자 크기 1.3배에서 overflow 없이 그려진다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final r in [
      GateResult.needsPreciseLocation,
      GateResult.needsBatteryGuide,
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [permissionGateProvider.overrideWithValue(FakeGate(r))],
          child: MaterialApp(
            theme: appLightTheme(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: PermissionScreen(onReady: () {}),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('제목은 헤더다', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, FakeGate(GateResult.needsLocation));
    expect(
      tester.getSemantics(find.widgetWithText(ScreenTitle, '권한 안내')),
      matchesSemantics(label: '권한 안내', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('needsLocation이면 안내 문구와 권한 허용 버튼', (tester) async {
    final gate = FakeGate(GateResult.needsLocation);
    await pump(tester, gate);

    expect(
      find.text('러닝 경로와 거리를 기록하려면 위치 권한이 필요합니다. 위치는 이 기기에만 저장됩니다.'),
      findsOneWidget,
    );
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(gate.requested, 1);
  });

  testWidgets('권한 허용 후 ready가 되면 onReady를 부른다', (tester) async {
    var ready = 0;
    final gate = FakeGate(GateResult.needsLocation);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionGateProvider.overrideWithValue(gate)],
        child: MaterialApp(
          theme: appLightTheme(),
          home: PermissionScreen(onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('needsPreciseLocation이면 위치 안내에 정확한 위치 문구를 더한다', (tester) async {
    final gate = FakeGate(GateResult.needsPreciseLocation);
    await pump(tester, gate);

    expect(
      find.text('러닝 경로와 거리를 기록하려면 위치 권한이 필요합니다. 위치는 이 기기에만 저장됩니다.'),
      findsOneWidget,
    );
    expect(find.text('정확한 위치를 허용해야 거리가 기록됩니다'), findsOneWidget);
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(gate.requested, 1);
  });

  testWidgets('needsLocation이면 정확한 위치 문구는 없다', (tester) async {
    await pump(tester, FakeGate(GateResult.needsLocation));
    expect(find.text('정확한 위치를 허용해야 거리가 기록됩니다'), findsNothing);
  });

  testWidgets('locationDeniedForever면 설정 열기 버튼', (tester) async {
    final gate = FakeGate(GateResult.locationDeniedForever);
    await pump(tester, gate);

    expect(find.text('설정에서 위치 권한을 허용해 주세요'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pump();
    expect(gate.appSettingsOpened, 1);
    expect(gate.settingsOpened, 0);
  });

  testWidgets('needsBatteryGuide에서 나중에를 누르면 ready로 진행', (tester) async {
    var ready = 0;
    final gate = FakeGate(GateResult.needsBatteryGuide);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionGateProvider.overrideWithValue(gate)],
        child: MaterialApp(
          theme: appLightTheme(),
          home: PermissionScreen(onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('설정 열기'), findsOneWidget);
    await tester.tap(find.text('나중에'));
    await tester.pump();
    expect(gate.dismissed, 1);
    expect(ready, 1);
  });

  testWidgets('처음부터 ready면 바로 onReady', (tester) async {
    var ready = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionGateProvider.overrideWithValue(FakeGate(GateResult.ready)),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          home: PermissionScreen(onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('ready 뒤 앱이 다시 활성화돼도 onReady는 한 번만', (tester) async {
    var ready = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          permissionGateProvider.overrideWithValue(FakeGate(GateResult.ready)),
        ],
        child: MaterialApp(
          theme: appLightTheme(),
          home: PermissionScreen(onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('나중에 뒤 앱이 다시 활성화돼도 onReady는 한 번만', (tester) async {
    var ready = 0;
    final gate = FakeGate(GateResult.needsBatteryGuide);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionGateProvider.overrideWithValue(gate)],
        child: MaterialApp(
          theme: appLightTheme(),
          home: PermissionScreen(onReady: () => ready++),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('나중에'));
    await tester.pump();
    gate.result = GateResult.ready;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('check가 실패하면 위치 안내와 다시 시도 버튼', (tester) async {
    final gate = FakeGate(GateResult.ready)..checkError = StateError('boom');
    await pump(tester, gate);
    expect(find.text('다시 시도'), findsOneWidget);
    expect(find.textContaining('위치 권한이 필요합니다'), findsOneWidget);

    gate.checkError = null;
    gate.result = GateResult.needsLocation;
    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(find.text('권한 허용'), findsOneWidget);
  });

  testWidgets('requestLocation이 실패해도 다시 시도 버튼', (tester) async {
    final gate = FakeGate(GateResult.needsLocation)
      ..requestError = StateError('boom');
    await pump(tester, gate);
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('첫 확인 중에는 진행 표시', (tester) async {
    final gate = FakeGate(GateResult.ready)..checkGate = Completer();
    await pump(tester, gate);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('PermissionHandlerGate 배터리 확인', () {
    const channel = MethodChannel('runmagochi/battery');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    void mock(bool ignoring, List<String> calls) {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return call.method == 'isIgnoringBatteryOptimizations'
            ? ignoring
            : null;
      });
    }

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    PermissionHandlerGate gate() => PermissionHandlerGate(
      locationStatus: () async => PermissionStatus.granted,
      locationAccuracy: () async => LocationAccuracyStatus.precise,
    );

    test('최적화 제외 상태면 ready', () async {
      mock(true, []);
      expect(await gate().check(), GateResult.ready);
    });

    test('최적화가 켜져 있으면 needsBatteryGuide, 나중에 이후는 ready', () async {
      mock(false, []);
      final g = gate();
      expect(await g.check(), GateResult.needsBatteryGuide);
      g.dismissBatteryGuide();
      expect(await g.check(), GateResult.ready);
    });

    test('openBatterySettings는 채널을 호출한다', () async {
      final calls = <String>[];
      mock(false, calls);
      await gate().openBatterySettings();
      expect(calls, ['openBatteryOptimizationSettings']);
    });
  });

  group('PermissionHandlerGate 정확한 위치 확인', () {
    const channel = MethodChannel('runmagochi/battery');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() => messenger.setMockMethodCallHandler(channel, (_) async => true));
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    PermissionHandlerGate gate(
      PermissionStatus status,
      Future<LocationAccuracyStatus> Function() accuracy,
    ) => PermissionHandlerGate(
      locationStatus: () async => status,
      locationAccuracy: accuracy,
    );

    test('허용됐어도 대략적인 위치면 needsPreciseLocation', () async {
      final g = gate(
        PermissionStatus.granted,
        () async => LocationAccuracyStatus.reduced,
      );
      expect(await g.check(), GateResult.needsPreciseLocation);
    });

    test('대략적인 위치만 허용돼 상태가 denied여도 needsPreciseLocation', () async {
      final g = gate(
        PermissionStatus.denied,
        () async => LocationAccuracyStatus.reduced,
      );
      expect(await g.check(), GateResult.needsPreciseLocation);
    });

    test('위치 권한이 없어 정확도 조회가 실패하면 needsLocation', () async {
      final g = gate(
        PermissionStatus.denied,
        () async => throw PlatformException(code: 'PERMISSION_DENIED'),
      );
      expect(await g.check(), GateResult.needsLocation);
    });

    test('정확한 위치가 허용되면 ready', () async {
      final g = gate(
        PermissionStatus.granted,
        () async => LocationAccuracyStatus.precise,
      );
      expect(await g.check(), GateResult.ready);
    });
  });
}
