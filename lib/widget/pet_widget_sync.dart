import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../avatar/app/providers.dart';
import '../core/ui/offscreen.dart';
import '../shop/app/providers.dart';
import '../weather/app/weather_controller.dart';
import 'pet_widget_card.dart';

/// iOS 위젯과 앱이 그림을 나누는 App Group.
const petWidgetAppGroup = 'group.com.dhkim1522.runmagochi';

/// 네이티브 위젯 이름. Android 는 AppWidgetProvider 클래스, iOS 는 Widget kind.
const petWidgetAndroidName = 'com.dhkim1522.runmagochi.PetWidgetProvider';
const petWidgetIosName = 'PetWidget';

/// 위젯 그림을 저장하는 키. 네이티브 위젯이 이 키로 파일 경로를 읽는다.
const petWidgetImageKey = 'pet_image';

/// 그린 위젯 그림을 홈 화면 위젯으로 보낸다. 테스트는 가짜로 바꾼다.
abstract interface class PetWidgetPublisher {
  Future<void> publish(Uint8List png);
}

/// home_widget 으로 파일을 저장하고 위젯을 갱신한다.
class HomeWidgetPublisher implements PetWidgetPublisher {
  const HomeWidgetPublisher();

  @override
  Future<void> publish(Uint8List png) async {
    final group = Platform.isIOS ? petWidgetAppGroup : null;
    await HomeWidget.saveFile(
      petWidgetImageKey,
      png,
      extension: 'png',
      appGroupId: group,
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: petWidgetAndroidName,
      iOSName: petWidgetIosName,
    );
  }
}

/// 위젯을 쓸 수 있는 기기인가(Android·iOS 앱). 테스트·웹에서는 false.
final petWidgetEnabledProvider = Provider<bool>(
  (_) => !kIsWeb && (Platform.isAndroid || Platform.isIOS),
);

final petWidgetPublisherProvider = Provider<PetWidgetPublisher>(
  (_) => const HomeWidgetPublisher(),
);

typedef PetWidgetRenderer =
    Future<Uint8List> Function(BuildContext context, PetWidgetCard card);

/// 위젯 카드를 PNG 로 그린다. 테스트는 가짜로 바꾼다.
final petWidgetRendererProvider = Provider<PetWidgetRenderer>(
  (_) =>
      (context, card) => renderOffscreen(
        context,
        card,
        size: petWidgetSize,
        pixelRatio: petWidgetPixelRatio,
        sheets: card.sheets,
      ),
);

/// 성장 상태·장착 아이템·날씨가 바뀔 때마다 홈 화면 위젯 그림을 다시 그려 보낸다 (F29).
/// 첫 실행을 마친 홈 아래에 둔다. 실패는 로그만 남긴다.
class PetWidgetSync extends ConsumerStatefulWidget {
  const PetWidgetSync({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PetWidgetSync> createState() => _PetWidgetSyncState();
}

class _PetWidgetSyncState extends ConsumerState<PetWidgetSync> {
  bool _scheduled = false;
  bool _publishing = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(petWidgetEnabledProvider)) {
      // 성장 상태를 미리 읽기 시작한다(홈이 이미 읽고 있으면 같은 값).
      ref.read(growthStateProvider);
      _schedule();
    }
  }

  void _schedule() {
    if (!ref.read(petWidgetEnabledProvider) || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _publish();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _publish() async {
    if (!mounted) return;
    if (_publishing) {
      _dirty = true;
      return;
    }
    final growth = ref.read(growthStateProvider).value;
    if (growth == null) return;
    final equipped = ref.read(equippedProvider).value;
    final card = PetWidgetCard(
      kind: growth.kind,
      stage: growth.stage,
      mood: growth.mood,
      name: growth.name,
      level: growth.level.level,
      kmToNextLevel: growth.kmToNextLevel,
      weather: ref.read(stageWeatherProvider),
      hatItemId: equipped?.hatItemId,
      accessoryItemId: equipped?.accessoryItemId,
    );
    _publishing = true;
    try {
      final png = await ref.read(petWidgetRendererProvider)(context, card);
      await ref.read(petWidgetPublisherProvider).publish(png);
    } catch (e) {
      debugPrint('위젯: 갱신 실패 $e');
    } finally {
      _publishing = false;
    }
    if (_dirty) {
      _dirty = false;
      _schedule();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(petWidgetEnabledProvider)) {
      ref.listen(growthStateProvider, (_, next) {
        if (next.hasValue) _schedule();
      });
      ref.listen(equippedProvider, (_, _) => _schedule());
      ref.listen(stageWeatherProvider, (_, _) => _schedule());
    }
    return widget.child;
  }
}
