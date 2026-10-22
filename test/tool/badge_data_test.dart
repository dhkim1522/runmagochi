import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:runmagochi/achievement/domain/badges.dart';
import 'package:runmagochi/achievement/ui/badge_image.dart';

import '../../tool/sprites/badges.dart';

void main() {
  BadgeArt art(String id) => badges.firstWhere((b) => b.id == id);

  test('badgeCatalog 의 모든 id 에 같은 순서로 배지 그림이 있다', () {
    expect(badges.map((b) => b.id), badgeCatalog.map((b) => b.id));
  });

  test('배지 그림은 24×24, 네 귀퉁이가 투명, 팔레트 안 글자다', () {
    for (final b in badges) {
      final rows = badgeRows(b);
      expect(rows, hasLength(badgeSize), reason: b.id);
      for (final r in rows) {
        expect(r.length, badgeSize, reason: b.id);
      }
      for (final (x, y) in [(0, 0), (23, 0), (0, 23), (23, 23)]) {
        expect(rows[y][x], '.', reason: '${b.id} ($x, $y)');
      }
      expect(validateBadge(b), isEmpty, reason: b.id);
    }
  });

  test('메달 테두리는 12개가 같은 모양이고, 문양은 안쪽 바탕에만 그린다', () {
    for (final b in badges) {
      final rows = badgeRows(b);
      for (var y = 0; y < badgeSize; y++) {
        for (var x = 0; x < badgeSize; x++) {
          final frame = badgeMedal[y][x];
          if (frame == badgeField) continue;
          expect(rows[y][x], frame, reason: '${b.id} ($x, $y)');
        }
      }
      // 문양이 실제로 있다.
      final painted = [
        for (var y = 0; y < badgeSize; y++)
          for (var x = 0; x < badgeSize; x++)
            if (badgeMedal[y][x] == badgeField && rows[y][x] != badgeField) 1,
      ];
      expect(painted.length, greaterThan(20), reason: b.id);
    }
  });

  test('테두리 색은 등급을 따른다: 같은 갈래는 단계가 오를수록 높은 등급', () {
    for (final group in [
      ['dist_5k', 'dist_10k', 'dist_half'],
      ['total_50', 'total_100', 'total_300'],
      ['goals_10', 'goals_30'],
    ]) {
      final tiers = [for (final id in group) art(id).tier.index];
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i], greaterThan(tiers[i - 1]), reason: group.join(','));
      }
    }
    expect(art('total_300').tier, BadgeTier.gold);
    expect(art('dist_half').tier, BadgeTier.gold);
  });

  test('모든 배지 id 에 24×24 PNG 에셋이 있다', () {
    for (final b in badgeCatalog) {
      final path = badgeAsset(b.id);
      expect(path, 'assets/badges/${b.id}.png');
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path 없음');
      final image = img.decodePng(file.readAsBytesSync())!;
      expect([image.width, image.height], [badgeSize, badgeSize], reason: path);
      expect(image.getPixel(0, 0).a, 0, reason: path);
    }
  });
}
