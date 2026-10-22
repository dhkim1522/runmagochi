import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/run/app/providers.dart';
import 'package:runmagochi/run/ui/history_screen.dart';

import 'fakes.dart';

// 작업 15(작업 14 리뷰): 기록의 기간 문구는 13 아래로 줄지 않고 줄바꿈·말줄임 없이 한 줄로
// 읽힌다. 글자 폭이 실제와 같아야 해서 이 파일은 앱 글꼴(RunmagochiSans)을 불러 잰다.

Future<void> _pump(WidgetTester tester, Size size, double scale) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(FakeRepo((0, 0))),
        runControllerProvider.overrideWith(() => FakeController()),
        clockProvider.overrideWithValue(() => DateTime(2026, 10, 22)),
      ],
      child: MaterialApp(
        theme: appLightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(body: HistoryScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// [text] 가 화면에 그려지는 실제 글자 크기(FittedBox 축소 반영).
double _shownSize(WidgetTester tester, Finder text, double base) =>
    base * tester.getRect(text).width / tester.getSize(text).width;

void main() {
  setUpAll(() async {
    final bytes = File('assets/fonts/RunmagochiSans.ttf').readAsBytesSync();
    await (FontLoader(
      'RunmagochiSans',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  const title = '2026년 10월 19일 ~ 10월 25일';

  for (final (size, scale) in [
    (const Size(360, 640), 1.3),
    (const Size(360, 640), 2.0),
    (const Size(360, 640), 1.0),
    (const Size(390, 844), 1.0),
  ]) {
    testWidgets(
      '주 기간 문구 ${size.width.toInt()}폭 글자 $scale배: 13 이상 한 줄, 화살표 48',
      (tester) async {
        await _pump(tester, size, scale);
        expect(tester.takeException(), isNull);
        final text = find.text(title);
        expect(text, findsOneWidget);
        expect(_shownSize(tester, text, 14 * scale), greaterThanOrEqualTo(13));
        final paragraph = tester.renderObject<RenderParagraph>(text);
        expect(paragraph.didExceedMaxLines, isFalse);
        // 한 줄(줄 높이 20 × 배율).
        expect(tester.getSize(text).height, closeTo(20 * scale, 1));
        for (final key in ['stats-prev', 'stats-next']) {
          expect(tester.getSize(find.byKey(Key(key))), const Size(48, 48));
        }
      },
    );
  }

  testWidgets('390폭 보통 글자에서는 화살표 사이 한 줄에 둔다', (tester) async {
    await _pump(tester, const Size(390, 844), 1);
    final text = tester.getRect(find.text(title));
    final prev = tester.getRect(find.byKey(const Key('stats-prev')));
    final next = tester.getRect(find.byKey(const Key('stats-next')));
    expect(text.left, greaterThan(prev.right));
    expect(text.right, lessThan(next.left));
    expect(text.center.dy, closeTo(prev.center.dy, 1));
  });

  testWidgets('좁으면 기간 문구를 화살표 줄 위 한 줄로 올린다', (tester) async {
    await _pump(tester, const Size(360, 640), 1.3);
    final text = tester.getRect(find.text(title));
    final prev = tester.getRect(find.byKey(const Key('stats-prev')));
    final next = tester.getRect(find.byKey(const Key('stats-next')));
    expect(text.bottom, lessThanOrEqualTo(prev.top));
    expect(prev.center.dy, closeTo(next.center.dy, 1));
  });
}
