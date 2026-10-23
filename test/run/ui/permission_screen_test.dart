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

Future<void> pumpThemed(
  WidgetTester tester,
  FakeGate gate, {
  bool dark = false,
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [permissionGateProvider.overrideWithValue(gate)],
      child: MaterialApp(
        theme: dark ? appDarkTheme() : appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PermissionScreen(onReady: () {}),
      ),
    ),
  );
  await tester.pump();
}

/// 작업 15: 새 시스템 짜임새.
void task15Tests() {
  for (final dark in [false, true]) {
    final name = dark ? '다크' : '라이트';
    final c = dark ? AppColors.dark : AppColors.light;
    for (final (result, icon) in [
      (GateResult.needsLocation, Icons.location_on_outlined),
      (GateResult.locationDeniedForever, Icons.location_on_outlined),
      (GateResult.needsBatteryGuide, Icons.battery_alert_outlined),
    ]) {
      testWidgets('$result: 흰 카드 위 무대색 동그라미 그림 + 문구, 버튼은 아래 ($name)', (
        tester,
      ) async {
        await pumpThemed(tester, FakeGate(result), dark: dark);
        final badge = find.byKey(const ValueKey('permission-icon'));
        expect(badge, findsOneWidget);
        final d =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: badge,
                            matching: find.byType(DecoratedBox),
                            matchRoot: true,
                          )
                          .first,
                    )
                    .decoration
                as BoxDecoration;
        expect(d.color, c.stageSky);
        expect(d.shape, BoxShape.circle);
        expect(tester.getSize(badge), const Size(72, 72));
        final i = tester.widget<Icon>(find.byIcon(icon));
        expect(i.color, c.stageInk);
        // 그림·문구는 한 흰 카드 안.
        final card = find.ancestor(of: badge, matching: find.byType(AppCard));
        expect(card, findsOneWidget);
        expect(tester.widget<AppCard>(card).radius, Radii.lg);
        // 주요 버튼은 화면 아래(아래 여백 16 안쪽).
        final button = tester.getRect(find.byType(AppButton));
        expect(button.bottom, greaterThan(844 - Gap.s4 - 60));
        expect(button.top, greaterThan(tester.getRect(card).bottom));
      });
    }

    testWidgets('첫 확인 중 진행 표시는 primaryDeep ($name)', (tester) async {
      final gate = FakeGate(GateResult.ready)..checkGate = Completer();
      await pumpThemed(tester, gate, dark: dark);
      final indicator = find.byType(CircularProgressIndicator);
      expect(indicator, findsOneWidget);
      final semanticsColor = Theme.of(
        tester.element(indicator),
      ).progressIndicatorTheme.color;
      expect(semanticsColor, c.primaryDeep);
    });

    testWidgets('360×640 글자 1.3배에서 넘치지 않는다 ($name)', (tester) async {
      for (final r in [
        GateResult.needsPreciseLocation,
        GateResult.needsBatteryGuide,
      ]) {
        await pumpThemed(
          tester,
          FakeGate(r),
          dark: dark,
          textScale: 1.3,
          size: const Size(360, 640),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(AppButton), findsOneWidget);
      }
    });
  }
}

void main() {
  task15Tests();
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

  group('PermissionHandlerGate 권한 요청', () {
    const channel = MethodChannel('runmagochi/battery');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(
      () => messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isIgnoringBatteryOptimizations',
      ),
    );
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    PermissionHandlerGate gate(PermissionStatus requested, List<String> log) =>
        PermissionHandlerGate(
          locationStatus: () async => PermissionStatus.denied,
          locationAccuracy: () async => LocationAccuracyStatus.precise,
          requestLocationPermission: () async => requested,
          requestNotificationPermission: () async {
            log.add('notification');
            return PermissionStatus.granted;
          },
        );

    test('요청 결과가 영구 거부면 locationDeniedForever (알림 권한은 그래도 요청)', () async {
      final log = <String>[];
      final g = gate(PermissionStatus.permanentlyDenied, log);
      expect(await g.requestLocation(), GateResult.locationDeniedForever);
      expect(log, ['notification']);
    });

    test('요청 결과가 허용이면 check() 결과를 돌려준다', () async {
      final g = PermissionHandlerGate(
        locationStatus: () async => PermissionStatus.granted,
        locationAccuracy: () async => LocationAccuracyStatus.precise,
        requestLocationPermission: () async => PermissionStatus.granted,
        requestNotificationPermission: () async => PermissionStatus.granted,
      );
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'isIgnoringBatteryOptimizations',
      );
      expect(await g.requestLocation(), GateResult.ready);
    });

    test('요청 결과가 거부(영구 아님)면 check() 결과를 돌려준다', () async {
      final g = gate(PermissionStatus.denied, []);
      expect(await g.requestLocation(), GateResult.needsLocation);
      expect(await g.check(), GateResult.needsLocation);
    });

    // 작업 27: Android 는 상태 조회가 영구 거부를 알려주지 않아 denied 만 준다.
    // 요청 창이 닫히며 앱이 다시 활성화될 때 부르는 check() 가 영구 거부를 덮어쓰면 안 된다.
    test('요청이 영구 거부를 알린 뒤에는 check() 도 locationDeniedForever', () async {
      final g = gate(PermissionStatus.permanentlyDenied, []);
      expect(await g.requestLocation(), GateResult.locationDeniedForever);
      expect(await g.check(), GateResult.locationDeniedForever);
    });

    test('영구 거부 뒤 설정에서 허용하면 check() 는 다시 상태를 따른다', () async {
      var status = PermissionStatus.denied;
      var accuracy = LocationAccuracyStatus.precise;
      final g = PermissionHandlerGate(
        locationStatus: () async => status,
        locationAccuracy: () async => accuracy,
        requestLocationPermission: () async =>
            PermissionStatus.permanentlyDenied,
        requestNotificationPermission: () async => PermissionStatus.granted,
      );
      expect(await g.requestLocation(), GateResult.locationDeniedForever);
      // 설정에서 대략적인 위치만 허용.
      accuracy = LocationAccuracyStatus.reduced;
      expect(await g.check(), GateResult.needsPreciseLocation);
      // 설정에서 정확한 위치까지 허용.
      status = PermissionStatus.granted;
      accuracy = LocationAccuracyStatus.precise;
      expect(await g.check(), GateResult.ready);
    });
  });

  testWidgets('권한 요청이 영구 거부를 알린 직후 앱이 다시 활성화돼도 설정 열기를 유지한다', (tester) async {
    // 에뮬레이터(API 36)에서 본 순서: 요청 결과 permanentlyDenied → 화면 갱신 →
    // resumed → check() 의 상태 조회 denied.
    final gate = PermissionHandlerGate(
      locationStatus: () async => PermissionStatus.denied,
      locationAccuracy: () async =>
          throw PlatformException(code: 'PERMISSION_DENIED'),
      requestLocationPermission: () async => PermissionStatus.permanentlyDenied,
      requestNotificationPermission: () async => PermissionStatus.granted,
    );
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
    expect(find.text('권한 허용'), findsOneWidget);

    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(find.text('설정 열기'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(find.text('설정 열기'), findsOneWidget);
    expect(find.text('권한 허용'), findsNothing);
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
