import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: appLightTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  _pressSyncTests();
  testWidgets('ClayButton 은 높이 64 에 라벨이 보이고 탭하면 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(ClayButton(label: '시작', onPressed: () => taps++)),
    );
    expect(find.text('시작'), findsOneWidget);
    await tester.tap(find.text('시작'));
    expect(taps, 1);
    expect(ClayButton.height, 64);
    expect(
      tester.getSize(find.byType(Container).first).height,
      ClayButton.height,
    );
  });

  testWidgets('ClayButton 은 onPressed 가 null 이면 눌리지 않는다', (tester) async {
    await tester.pumpWidget(
      _wrap(const ClayButton(label: '시작', onPressed: null)),
    );
    await tester.tap(find.text('시작'));
    await tester.pump();
    expect(find.text('시작'), findsOneWidget);
  });

  testWidgets('ClayBar 는 0~1 로 자른 채움 비율을 가진다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 200,
          child: ClayBar(
            value: 1.5,
            height: 14,
            fill: Colors.transparent,
            track: Colors.transparent,
          ),
        ),
      ),
    );
    final f = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(f.widthFactor, 1.0);
  });

  testWidgets('StatCard 는 라벨과 값을 보인다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SizedBox(
          width: 110,
          child: StatCard(label: '시간', value: '18:42'),
        ),
      ),
    );
    expect(find.text('시간'), findsOneWidget);
    expect(find.text('18:42'), findsOneWidget);
  });

  testWidgets('ClayButton 은 라벨과 버튼이 한 시맨틱 노드다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(ClayButton(label: '시작', onPressed: () {})));
    expect(
      tester.getSemantics(find.byType(ClayButton)),
      matchesSemantics(
        label: '시작',
        isButton: true,
        isEnabled: true,
        hasEnabledState: true,
        hasTapAction: true,
      ),
    );
    expect(find.bySemanticsLabel('시작'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('ScreenTitle 은 헤더로 표시된다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(const ScreenTitle('기록')));
    expect(
      tester.getSemantics(find.byType(ScreenTitle)),
      matchesSemantics(label: '기록', isHeader: true),
    );
    handle.dispose();
  });
}

void _pressSyncTests() {
  testWidgets('ClayButton 누름: 이동과 립이 같은 애니메이션으로 함께 변한다', (tester) async {
    await tester.pumpWidget(_wrap(ClayButton(label: '시작', onPressed: () {})));
    double lip() {
      final box =
          tester.widget<Container>(find.byType(Container).first).decoration
              as BoxDecoration;
      return box.boxShadow!.single.offset.dy;
    }

    double shift() => tester
        .widget<Transform>(
          find.descendant(
            of: find.byType(ClayPress),
            matching: find.byType(Transform),
          ),
        )
        .transform
        .getTranslation()
        .y;

    expect(lip(), Borders.lip);
    expect(shift(), 0);
    final g = await tester.startGesture(tester.getCenter(find.text('시작')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // 중간 시점: 둘 다 끝값이 아니고, 이동 + 립 = 고정.
    expect(lip(), inExclusiveRange(Borders.lipPressed, Borders.lip));
    expect(shift() + lip(), closeTo(Borders.lip, 0.001));
    await tester.pump(const Duration(milliseconds: 100));
    expect(lip(), Borders.lipPressed);
    expect(shift(), Borders.lip - Borders.lipPressed);
    await g.up();
  });
}
