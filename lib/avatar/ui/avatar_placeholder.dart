import 'package:flutter/material.dart';

class AvatarPlaceholder extends StatelessWidget {
  const AvatarPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text('아바타는 다음 업데이트에서 만나요'),
    );
  }
}
