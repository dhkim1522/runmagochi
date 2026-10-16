// 에뮬레이터에 가상 GPS 를 1초마다 주입한다.
// 사용: dart run tool/fake_run.dart --minutes 5 --speed 3.0 --lat 37.5260 --lng 126.9240
// 선택: --seconds <초> (--minutes 대신), --adb <adb 경로>
import 'dart:io';

import 'package:runmagochi/run/domain/geo.dart';

import 'fake_run_path.dart';

Future<void> main(List<String> args) async {
  final opts = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    opts[args[i].replaceFirst('--', '')] = args[i + 1];
  }
  final seconds = opts.containsKey('seconds')
      ? int.parse(opts['seconds']!)
      : (double.parse(opts['minutes'] ?? '5') * 60).round();
  final speed = double.parse(opts['speed'] ?? '3.0');
  final lat = double.parse(opts['lat'] ?? '37.5260');
  final lng = double.parse(opts['lng'] ?? '126.9240');
  final adb = opts['adb'] ?? _findAdb();

  final path = buildPath(seconds: seconds, speedMps: speed, lat: lat, lng: lng);
  var total = 0.0;
  for (var i = 0; i < path.length; i++) {
    final (pLat, pLng) = path[i];
    final result = await Process.run(adb, [
      'emu',
      'geo',
      'fix',
      '$pLng',
      '$pLat',
    ]);
    if (result.exitCode != 0) {
      stderr.writeln(
        'adb 실패 (exit ${result.exitCode}): ${result.stderr}${result.stdout}',
      );
      exit(1);
    }
    if (i > 0) {
      total += haversineMeters(path[i - 1].$1, path[i - 1].$2, pLat, pLng);
    }
    if (i < path.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }
  stdout.writeln('총 거리: ${total.toStringAsFixed(1)} m (${path.length}개 점)');
}

String _findAdb() {
  final env = Platform.environment;
  final candidates = <String>[
    if (env['ANDROID_HOME'] != null)
      '${env['ANDROID_HOME']}/platform-tools/${Platform.isWindows ? 'adb.exe' : 'adb'}',
    if (Platform.isMacOS && env['HOME'] != null)
      '${env['HOME']}/Library/Android/sdk/platform-tools/adb',
    if (Platform.isWindows && env['LOCALAPPDATA'] != null)
      '${env['LOCALAPPDATA']}\\Android\\Sdk\\platform-tools\\adb.exe',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return 'adb';
}
