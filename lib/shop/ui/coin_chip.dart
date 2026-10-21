import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../app/providers.dart';

/// 코인 아이콘과 잔액(`1,240`). 누르면 [onTap]. 눌리는 영역은 높이 48 이상이다.
class CoinChip extends ConsumerWidget {
  const CoinChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AppColors.of(context);
    final t = AppText.of(context);
    final balance = ref.watch(coinBalanceProvider).value;
    final text = balance == null ? '-' : formatThousands(balance);
    return Semantics(
      button: true,
      label: '코인 $text',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on, size: 24, color: c.accentDeep),
                const SizedBox(width: Gap.s1),
                Text(text, style: t.titleS),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
