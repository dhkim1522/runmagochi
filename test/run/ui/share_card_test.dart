import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:runmagochi/avatar/app/providers.dart';
import 'package:runmagochi/avatar/domain/growth_rules.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/app/share_service.dart';
import 'package:runmagochi/run/domain/run_goal.dart';
import 'package:runmagochi/run/domain/run_summary.dart';
import 'package:runmagochi/run/ui/share_card.dart';
import 'package:runmagochi/run/ui/summary_screen.dart';
import 'package:runmagochi/shop/app/providers.dart';

import 'fakes.dart';

class FakeSharer implements Sharer {
  final List<String> paths = [];
  final List<String?> texts = [];
  final List<bool> existed = [];
  final List<int> sizes = [];
  Object? error;
  Completer<void>? hold;

  @override
  Future<void> shareImage(String path, {String? text}) async {
    paths.add(path);
    texts.add(text);
    final f = File(path);
    existed.add(f.existsSync());
    sizes.add(f.existsSync() ? f.lengthSync() : 0);
    await hold?.future;
    if (error != null) throw error!;
  }
}

RunSummary _summary() => RunSummary(
  startedAt: DateTime(2026, 10, 16, 17, 51),
  endedAt: DateTime(2026, 10, 16, 18, 20),
  distanceM: 3200,
  movingTime: const Duration(minutes: 20, seconds: 5),
  avgPaceSecPerKm: 390,
  calories: 168,
  name: '금요일 오후 러닝',
  splits: const [
    Split(index: 1, distanceM: 1000, duration: Duration(seconds: 385)),
    Split(index: 2, distanceM: 1000, duration: Duration(seconds: 390)),
    Split(index: 3, distanceM: 1000, duration: Duration(seconds: 395)),
    Split(index: 4, distanceM: 200, duration: Duration(seconds: 80)),
  ],
  points: const [],
);

late Directory _tmp;

Future<FakeSharer> _pump(WidgetTester tester, {Widget? screen}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sharer = FakeSharer();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        growthServiceProvider.overrideWithValue(
          FakeGrowthService(growthState()),
        ),
        shopRepositoryProvider.overrideWithValue(FakeShop()),
        sharerProvider.overrideWithValue(sharer),
        shareTempDirProvider.overrideWithValue(() async => _tmp),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
        home:
            screen ??
            SummaryScreen.fromSummary(
              _summary(),
              goal: const DistanceGoal(3000),
            ),
      ),
    ),
  );
  await tester.pump();
  return sharer;
}

/// 실제 비동기(이미지 불러오기·캡처)가 끝나도록 번갈아 돌린다.
Future<void> _settleShare(WidgetTester tester, FakeSharer s) async {
  for (var i = 0; i < 40 && s.paths.isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() => _tmp = Directory.systemTemp.createTempSync('share_card_test'));
  tearDown(() => _tmp.deleteSync(recursive: true));

  testWidgets('카드에 거리·시간·페이스·목표 문구가 그려진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appLightTheme(),
        home: Scaffold(
          body: ShareCard(
            kind: AvatarKind.chick,
            stage: 1,
            mood: AvatarMood.normal,
            startedAt: DateTime(2026, 10, 16, 17, 51),
            distanceM: 3200,
            movingTime: const Duration(minutes: 20, seconds: 5),
            avgPaceSecPerKm: 390,
            goalLine: '목표 3km 달성',
            levelUpLine: '레벨 4 달성!',
          ),
        ),
      ),
    );
    expect(find.text('3.20'), findsOneWidget);
    expect(find.text('20:05'), findsOneWidget);
    expect(find.text('6\'30"'), findsOneWidget);
    expect(find.text('목표 3km 달성'), findsOneWidget);
    expect(find.text('레벨 4 달성!'), findsOneWidget);
    expect(find.text('runmagochi'), findsOneWidget);
    expect(find.text('10월 16일 (금) 오후 5:51'), findsOneWidget);
  });

  testWidgets('공유 버튼 -> 가짜 Sharer 가 비어 있지 않은 PNG 경로를 받는다', (tester) async {
    final s = await _pump(tester);
    await tester.tap(find.text('공유'));
    await tester.pump();
    await _settleShare(tester, s);
    expect(s.paths, hasLength(1));
    expect(s.paths.single, endsWith('.png'));
    expect(s.existed.single, isTrue);
    expect(s.sizes.single, greaterThan(1000));
    final bytes = File(s.paths.single).readAsBytesSync();
    // PNG 시그니처.
    expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    // 1080x1350 이고 아바타 자리에 배경과 다른 픽셀이 있다(시트를 읽은 뒤에 찍었다).
    final png = img.decodePng(bytes)!;
    expect(png.width, 1080);
    expect(png.height, 1350);
    final bg = png.getPixel(540, 400);
    var different = 0;
    for (var y = 330; y < 800; y += 3) {
      for (var x = 300; x < 780; x += 3) {
        if (png.getPixel(x, y) != bg) different++;
      }
    }
    expect(different, greaterThan(200));
    expect(find.text('공유하지 못했어요'), findsNothing);
  });

  testWidgets('공유가 실패하면 안내 문구를 보인다', (tester) async {
    final s = await _pump(tester);
    s.error = Exception('boom');
    await tester.tap(find.text('공유'));
    await tester.pump();
    await _settleShare(tester, s);
    expect(find.text('공유하지 못했어요'), findsOneWidget);
  });

  testWidgets('두 번 눌러도 한 번만 공유한다', (tester) async {
    final s = await _pump(tester);
    s.hold = Completer<void>();
    await tester.tap(find.text('공유'));
    await tester.pump();
    await tester.tap(find.text('공유'), warnIfMissed: false);
    await tester.pump();
    await _settleShare(tester, s);
    await tester.tap(find.text('공유'), warnIfMissed: false);
    await tester.pump();
    await _settleShare(tester, s);
    expect(s.paths, hasLength(1));
    s.hold!.complete();
    await tester.pump();
  });
}
