import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/ui/components.dart';
import '../app/providers.dart';

/// 흰 알약 코인 칩: 앱 코인 그림 24 + 잔액(`1,240`, 17/800 고정폭 숫자). 누르면 [onTap].
/// 높이 48 이상이고, 누르면 살짝 작아졌다 돌아온다.
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
      child: Pressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.s3, 0, Gap.s4, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(),
                  const SizedBox(width: Gap.s2),
                  Text(
                    text,
                    style: t.heading.copyWith(
                      color: c.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
