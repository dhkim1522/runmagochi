import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/achievement/domain/badges.dart';
import 'package:runmagochi/achievement/ui/badge_image.dart';

Widget _wrap(Widget child) => MaterialApp(home: Center(child: child));

Image _image(WidgetTester tester) => tester.widget<Image>(find.byType(Image));

void main() {
  testWidgets('받은 배지는 컬러 그대로, 도트가 번지지 않게 그린다', (tester) async {
    await tester.pumpWidget(_wrap(const BadgeImage('dist_5k', earned: true)));
    final image = _image(tester);
    expect((image.image as AssetImage).assetName, 'assets/badges/dist_5k.png');
    expect(image.filterQuality, FilterQuality.none);
    expect(find.byType(ColorFiltered), findsNothing);
    expect(find.byType(Opacity), findsNothing);
    expect(tester.getSize(find.byType(BadgeImage)), const Size(48, 48));
  });

  testWidgets('못 받은 배지는 같은 그림을 회색으로, 투명도 0.45', (tester) async {
    await tester.pumpWidget(_wrap(const BadgeImage('dist_5k', earned: false)));
    final image = _image(tester);
    expect((image.image as AssetImage).assetName, 'assets/badges/dist_5k.png');
    expect(image.filterQuality, FilterQuality.none);
    final filtered = tester.widget<ColorFiltered>(find.byType(ColorFiltered));
    expect(filtered.colorFilter, badgeGreyscale);
    final opacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byType(ColorFiltered),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 0.45);
  });

  testWidgets('모든 배지 그림이 앱 에셋으로 묶여 읽힌다(pubspec assets)', (tester) async {
    await tester.pumpWidget(_wrap(const SizedBox()));
    final ctx = tester.element(find.byType(SizedBox));
    final failed = <String>[];
    await tester.runAsync(() async {
      for (final b in badgeCatalog) {
        await precacheImage(
          AssetImage(badgeAsset(b.id)),
          ctx,
          onError: (_, _) => failed.add(b.id),
        );
      }
    });
    expect(failed, isEmpty);
  });

  testWidgets('크기를 바꿀 수 있다', (tester) async {
    await tester.pumpWidget(
      _wrap(const BadgeImage('dawn', earned: true, size: 72)),
    );
    expect(tester.getSize(find.byType(BadgeImage)), const Size(72, 72));
  });

  test('회색 필터는 밝기를 유지하는 흑백 행렬이다', () {
    // 흰색은 흰색, 각 행의 합은 1.
    const m = badgeGreyscaleMatrix;
    for (var row = 0; row < 3; row++) {
      final sum = m[row * 5] + m[row * 5 + 1] + m[row * 5 + 2];
      expect(sum, closeTo(1, 1e-6));
      expect(m.sublist(row * 5, row * 5 + 3), m.sublist(0, 3));
    }
  });

  testWidgets('그림이 없으면 조용히 비우지 않고 눈에 띄는 자리표시와 오류를 낸다', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = old);
    await tester.pumpWidget(
      _wrap(const BadgeImage('no_such_badge', earned: true)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    FlutterError.onError = old;
    expect(find.byKey(const ValueKey('badge-missing')), findsOneWidget);
    expect(errors, isNotEmpty);
    expect(errors.first.toString(), contains('no_such_badge'));
  });
}
