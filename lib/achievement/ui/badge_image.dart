import 'package:flutter/material.dart';

/// 배지 그림 경로. 그림은 `tool/render_sprites.dart` 가 만든다(24×24, docs/specs/sprite-spec.md 배지 절).
String badgeAsset(String id) => 'assets/badges/$id.png';

/// 못 받은 배지의 흑백 행렬. 밝기(Rec. 709)를 그대로 둔다.
/// 미리보기(design/character/badges.png)도 같은 값으로 그린다.
const List<double> badgeGreyscaleMatrix = [
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
];

const ColorFilter badgeGreyscale = ColorFilter.matrix(badgeGreyscaleMatrix);

/// 못 받은 배지의 투명도. 아바타 탭의 잠긴 단계와 같다.
const double badgeLockedOpacity = 0.45;

/// 배지 도트 그림. 받은 배지는 컬러, 못 받은 배지는 같은 그림을 회색·흐리게 그린다.
/// 이름은 옆이나 아래 글자로 보이므로 그림은 읽기 도구에서 뺀다.
class BadgeImage extends StatelessWidget {
  const BadgeImage(this.id, {super.key, required this.earned, this.size = 48});

  /// `badgeCatalog` 의 id.
  final String id;
  final bool earned;

  /// 한 변(논리 px). 기본 48 은 24px 그림의 2배다. 정수배로 써야 도트가 고르다.
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      badgeAsset(id),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) {
        // 그림이 없으면 빈자리로 넘기지 않는다: 오류를 알리고 눈에 띄는 자리표시를 둔다.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'runmagochi achievement',
            context: ErrorDescription('배지 "$id" 그림(${badgeAsset(id)})을 읽는 중'),
          ),
        );
        final c = Theme.of(context).colorScheme;
        return Container(
          key: const ValueKey('badge-missing'),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.error, width: 2),
          ),
          child: Icon(Icons.broken_image, size: size / 2, color: c.error),
        );
      },
    );
    if (earned) return image;
    return Opacity(
      opacity: badgeLockedOpacity,
      child: ColorFiltered(colorFilter: badgeGreyscale, child: image),
    );
  }
}
