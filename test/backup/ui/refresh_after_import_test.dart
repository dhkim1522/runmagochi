import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/backup/ui/refresh_after_import.dart';
import 'package:runmagochi/shop/app/providers.dart';
import 'package:runmagochi/shop/data/shop_repository.dart';

void main() {
  testWidgets('가져온 뒤 장착·보유 상태를 다시 읽는다', (tester) async {
    var equippedLoads = 0;
    var ownedLoads = 0;
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equippedProvider.overrideWith((ref) async {
            equippedLoads++;
            return const Equipped();
          }),
          ownedItemsProvider.overrideWith((ref) async {
            ownedLoads++;
            return <String>{};
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            ref.watch(equippedProvider);
            ref.watch(ownedItemsProvider);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pump();
    expect([equippedLoads, ownedLoads], [1, 1]);

    refreshAfterImport(captured);
    await tester.pump();
    await tester.pump();

    expect(equippedLoads, 2);
    expect(ownedLoads, 2);
  });
}
