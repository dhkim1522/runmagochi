import 'package:flutter_test/flutter_test.dart';
import 'package:runmagochi/shop/domain/catalog.dart';

void main() {
  test('목록은 6개이고 id 가 서로 다르다', () {
    expect(catalog, hasLength(6));
    expect(catalog.map((i) => i.id).toSet(), hasLength(6));
  });

  test('가격은 모두 100~400 코인이다', () {
    for (final item in catalog) {
      expect(item.price, inInclusiveRange(100, 400), reason: item.id);
    }
  });

  test('모자·소품이 3개씩이다', () {
    for (final slot in ItemSlot.values) {
      expect(
        catalog.where((i) => i.slot == slot),
        hasLength(3),
        reason: '$slot',
      );
    }
  });

  test('목록 내용', () {
    expect(
      [for (final i in catalog) (i.id, i.slot, i.name, i.price)],
      [
        ('cap', ItemSlot.hat, '러닝 캡', 100),
        ('beanie', ItemSlot.hat, '비니', 200),
        ('straw_hat', ItemSlot.hat, '밀짚모자', 300),
        ('sunglasses', ItemSlot.accessory, '선글라스', 150),
        ('headphones', ItemSlot.accessory, '헤드폰', 250),
        ('flower_pin', ItemSlot.accessory, '꽃 머리핀', 350),
      ],
    );
  });

  test('id 로 찾기: 없는 id 는 null', () {
    expect(itemById('beanie')!.name, '비니');
    expect(itemById('nope'), isNull);
  });
}
