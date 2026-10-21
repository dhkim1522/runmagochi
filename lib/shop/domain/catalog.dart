/// 아이템을 다는 부위.
enum ItemSlot { hat, accessory }

/// 상점에서 파는 꾸미기 아이템. 그림은 `assets/sprites/<종류>/<부위>/<id>_<동작>.png`.
class Item {
  const Item({
    required this.id,
    required this.slot,
    required this.name,
    required this.price,
  });

  final String id;
  final ItemSlot slot;
  final String name;

  /// 코인 가격.
  final int price;
}

/// 상점 목록. 화면에 이 순서로 보인다.
const List<Item> catalog = [
  Item(id: 'cap', slot: ItemSlot.hat, name: '러닝 캡', price: 100),
  Item(id: 'beanie', slot: ItemSlot.hat, name: '비니', price: 200),
  Item(id: 'straw_hat', slot: ItemSlot.hat, name: '밀짚모자', price: 300),
  Item(id: 'sunglasses', slot: ItemSlot.accessory, name: '선글라스', price: 150),
  Item(id: 'headphones', slot: ItemSlot.accessory, name: '헤드폰', price: 250),
  Item(id: 'flower_pin', slot: ItemSlot.accessory, name: '꽃 머리핀', price: 350),
];

/// [id] 의 아이템. 목록에 없으면 null.
Item? itemById(String id) {
  for (final item in catalog) {
    if (item.id == id) return item;
  }
  return null;
}
