import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/run/app/permission_gate.dart';
import 'package:runmagochi/run/ui/permission_screen.dart';

class FakeGate implements PermissionGate {
  FakeGate(this.result, {this.afterRequest = GateResult.ready});
  GateResult result;
  GateResult afterRequest;
  int requested = 0;
  int settingsOpened = 0;
  int dismissed = 0;

  @override
  Future<GateResult> check() async => result;

  @override
  Future<GateResult> requestLocation() async {
    requested++;
    return result = afterRequest;
  }

  @override
  Future<void> openBatterySettings() async => settingsOpened++;

  @override
  void dismissBatteryGuide() => dismissed++;
}

Future<void> pump(WidgetTester tester, FakeGate gate) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [permissionGateProvider.overrideWithValue(gate)],
      child: MaterialApp(home: PermissionScreen(onReady: () {})),
    ),
  );
  await tester.pump();
}

void main() {
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
        child: MaterialApp(home: PermissionScreen(onReady: () => ready++)),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('권한 허용'));
    await tester.pump();
    expect(ready, 1);
  });

  testWidgets('locationDeniedForever면 설정 열기 버튼', (tester) async {
    final gate = FakeGate(GateResult.locationDeniedForever);
    await pump(tester, gate);

    expect(find.text('설정에서 위치 권한을 허용해 주세요'), findsOneWidget);
    await tester.tap(find.text('설정 열기'));
    await tester.pump();
    expect(gate.settingsOpened, 1);
  });

  testWidgets('needsBatteryGuide에서 나중에를 누르면 ready로 진행', (tester) async {
    var ready = 0;
    final gate = FakeGate(GateResult.needsBatteryGuide);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [permissionGateProvider.overrideWithValue(gate)],
        child: MaterialApp(home: PermissionScreen(onReady: () => ready++)),
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
        child: MaterialApp(home: PermissionScreen(onReady: () => ready++)),
      ),
    );
    await tester.pump();
    expect(ready, 1);
  });
}
