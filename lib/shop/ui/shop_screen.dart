import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../avatar/app/providers.dart';
import '../../avatar/domain/growth_rules.dart';
import '../../avatar/ui/avatar_view.dart';
import '../../avatar/ui/sprite_sheet.dart' show spriteFramePx;
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/providers.dart';
import '../data/shop_repository.dart';
import '../domain/catalog.dart';
import 'coin_chip.dart';
import 'coin_history_screen.dart';

/// 네 번째 탭: 아이템을 아바타에 입혀 보고 사서 장착한다.
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ItemSlot _slot = ItemSlot.hat;

  /// 부위별로 고른 아이템 id. 고르지 않았으면 장착 중인 것, 그것도 없으면 첫 아이템.
  final Map<ItemSlot, String> _picked = {};

  /// 구매·장착이 진행 중이다. 진행 중에는 버튼이 막힌다.
  bool _busy = false;

  List<Item> get _items => [
    for (final i in catalog)
      if (i.slot == _slot) i,
  ];

  String? _equippedId(Equipped e, ItemSlot slot) =>
      slot == ItemSlot.hat ? e.hatItemId : e.accessoryItemId;

  Item _selected(Equipped e) {
    final id = _picked[_slot] ?? _equippedId(e, _slot);
    return _items.firstWhere((i) => i.id == id, orElse: () => _items.first);
  }

  void _refresh() {
    ref.invalidate(coinBalanceProvider);
    ref.invalidate(coinHistoryProvider);
    ref.invalidate(ownedItemsProvider);
    ref.invalidate(equippedProvider);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _confirm(Item item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          '${item.name}${_object(item.name)} ${formatThousands(item.price)} 코인에 살까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('구매'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _buyAndEquip(Item item) async {
    if (!await _confirm(item) || !mounted) return;
    final shop = ref.read(shopRepositoryProvider);
    try {
      await shop.purchase(item.id, item.price);
      await shop.equip(item.slot, item.id);
    } on InsufficientCoins {
      _message('코인이 모자라요');
    } on AlreadyOwned {
      _message('이미 가진 아이템이에요');
    } catch (_) {
      _message('처리하지 못했어요. 다시 시도해 주세요');
    }
  }

  Future<void> _equip(Item item, bool wear) async {
    try {
      await ref
          .read(shopRepositoryProvider)
          .equip(item.slot, wear ? item.id : null);
    } catch (_) {
      _message('처리하지 못했어요. 다시 시도해 주세요');
    }
  }

  /// 버튼 한 번에 하나만 처리한다. 확인 창을 띄우기 전에 막아 두 번 눌러도 한 번만 산다.
  Future<void> _act(
    Item item, {
    required bool owned,
    required bool worn,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (!owned) {
        await _buyAndEquip(item);
      } else {
        await _equip(item, !worn);
      }
    } finally {
      _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openHistory() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const CoinHistoryScreen()));

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(growthStateProvider).value;
    final equipped = ref.watch(equippedProvider).value;
    final owned = ref.watch(ownedItemsProvider).value;
    final balance = ref.watch(coinBalanceProvider).value;
    if (g == null || equipped == null || owned == null || balance == null) {
      return const SizedBox.shrink();
    }
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final selected = _selected(equipped);
    final isOwned = owned.contains(selected.id);
    final isWorn = _equippedId(equipped, _slot) == selected.id;
    final short = selected.price - balance;
    final canBuy = isOwned || short <= 0;

    final label = isWorn
        ? '벗기'
        : isOwned
        ? '장착하기'
        : '${formatThousands(selected.price)} 코인으로 구매하고 장착';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.s5, Gap.s4, Gap.s5, Gap.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: ScreenTitle('상점')),
                CoinChip(onTap: _openHistory),
              ],
            ),
            const SizedBox(height: Gap.s4),
            Expanded(
              // 스크롤 칸 높이로 무대 배율을 고른다(무대는 칸의 절반까지).
              child: LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 무대: 장착 중인 것에 고른 아이템을 얹어 보여 준다(폭 전체 사각 무대).
                      // 아이템 줄이 함께 보이게 러닝 중처럼 6배까지. 작은 화면·큰 글자에서는
                      // 스크롤 칸의 절반을 넘지 않는 가장 큰 배율로 줄여 아이템 카드가 첫
                      // 화면에 보이게 한다(작업 15).
                      LayoutBuilder(
                        builder: (context, box) {
                          double height(int s) =>
                              spriteFramePx * s +
                              Stage.groundHeightCompact -
                              Stage.footSink -
                              spriteFootGapRows * s +
                              Gap.s3;
                          final scale =
                              PetStage.largestScale(
                                max: 6,
                                min: 3,
                                fits: (s) =>
                                    spriteFramePx * s + 2 * Gap.s4 <=
                                        box.maxWidth &&
                                    height(s) <= viewport.maxHeight / 2,
                              ) ??
                              3;
                          final stage = PetStage(
                            key: const ValueKey('shop-stage'),
                            scale: scale,
                            groundHeight: Stage.groundHeightCompact,
                            pet: AvatarView(
                              key: const ValueKey('shop-stage-avatar'),
                              kind: g.kind,
                              stage: g.stage,
                              mood: g.mood,
                              action: AvatarAction.idle,
                              scale: scale,
                              hatItemId: _slot == ItemSlot.hat
                                  ? selected.id
                                  : equipped.hatItemId,
                              accessoryItemId: _slot == ItemSlot.accessory
                                  ? selected.id
                                  : equipped.accessoryItemId,
                            ),
                          );
                          return SizedBox(
                            height:
                                spriteFramePx * scale +
                                stage.petBottom +
                                Gap.s3,
                            child: stage,
                          );
                        },
                      ),
                      const SizedBox(height: Gap.s4),
                      ChipRow(
                        children: [
                          _slotTab('모자', ItemSlot.hat),
                          _slotTab('소품', ItemSlot.accessory),
                        ],
                      ),
                      const SizedBox(height: Gap.s4),
                      for (var i = 0; i < _items.length; i += 2)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Gap.s3),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var j = i; j < i + 2; j++) ...[
                                  if (j > i) const SizedBox(width: Gap.s3),
                                  Expanded(
                                    child: j < _items.length
                                        ? _ItemCard(
                                            item: _items[j],
                                            kind: g.kind,
                                            stage: g.stage,
                                            mood: g.mood,
                                            chosen: _items[j].id == selected.id,
                                            owned: owned.contains(_items[j].id),
                                            worn:
                                                _equippedId(equipped, _slot) ==
                                                _items[j].id,
                                            onTap: () => setState(
                                              () =>
                                                  _picked[_slot] = _items[j].id,
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.s2),
            if (!canBuy)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.s2),
                child: Text(
                  '코인이 ${formatThousands(short)} 부족해요',
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(color: c.danger),
                ),
              ),
            AppButton(
              key: const ValueKey('shop-action'),
              label: label,
              onPressed: _busy || !canBuy
                  ? null
                  : () => _act(selected, owned: isOwned, worn: isWorn),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotTab(String text, ItemSlot slot) => AppChip(
    label: text,
    selected: _slot == slot,
    onTap: () => setState(() => _slot = slot),
  );
}

/// 아이템 카드 미리보기 배율. 두 칸 카드는 좁은 폰(320)에서도 안쪽 폭이 96 을 넘는다.
/// 카드 줄이 IntrinsicHeight 라 LayoutBuilder 로 재지 않고 고정한다.
const int _previewScale = 3;

/// 미리보기 무대 높이: 펫 상자 + 펫 아래(땅 − 묻힘 − 발끝 아래 빈 줄) + 위 여백 4.
const double _previewHeight =
    spriteFramePx * _previewScale +
    Stage.groundHeightMini -
    Stage.footSink -
    spriteFootGapRows * _previewScale +
    Gap.s1;

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.kind,
    required this.stage,
    required this.mood,
    required this.chosen,
    required this.owned,
    required this.worn,
    required this.onTap,
  });

  final Item item;
  final AvatarKind kind;
  final int stage;
  final AvatarMood mood;
  final bool chosen;
  final bool owned;
  final bool worn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final status = worn
        ? '장착 중'
        : owned
        ? '보유'
        : formatThousands(item.price);
    return Semantics(
      button: true,
      selected: chosen,
      label: '${item.name} $status',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: ValueKey('item-${item.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AppCard(
          radius: Radii.md,
          borderColor: chosen ? c.primaryEdge : null,
          padding: const EdgeInsets.all(Gap.s3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 작은 사각 무대(하늘·땅) 위 미리보기. 배경 아이템이 생기면 같은 겹을 바꾼다.
              SizedBox(
                height: _previewHeight,
                child: PetStage(
                  scale: _previewScale,
                  groundHeight: Stage.groundHeightMini,
                  radius: Radii.sm,
                  pet: AvatarView(
                    kind: kind,
                    stage: stage,
                    mood: mood,
                    action: AvatarAction.idle,
                    scale: _previewScale,
                    hatItemId: item.slot == ItemSlot.hat ? item.id : null,
                    accessoryItemId: item.slot == ItemSlot.accessory
                        ? item.id
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: Gap.s3),
              Text(item.name, textAlign: TextAlign.center, style: t.bodyStrong),
              const SizedBox(height: Gap.s1),
              if (owned || worn)
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: t.label.copyWith(
                    color: worn ? c.primaryDeep : c.inkMuted,
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: Gap.s1),
                    Flexible(
                      child: Text(
                        status,
                        style: t.label.copyWith(
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: Gap.s1),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이름 끝 글자에 받침이 있으면 `을`, 없으면 `를`.
String _object(String name) {
  final code = name.runes.last;
  final hasFinal =
      code >= 0xAC00 && code <= 0xD7A3 && (code - 0xAC00) % 28 != 0;
  return hasFinal ? '을' : '를';
}
