import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/core/theme.dart';
import 'package:runmagochi/core/ui/clay.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: appLightTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('ClayButton 은 높이 64 에 라벨이 보이고 탭하면 불린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _wrap(ClayButton(label: '시작', onPressed: () => taps++)),
    );
    expect(find.text('시작'), findsOneWidget);
    await tester.tap(find.text('시작'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(AnimatedContainer)).height, 64);
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
}
