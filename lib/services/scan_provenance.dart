import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/contact_grid_scan.dart';

class ScanProvenanceCollector {
  const ScanProvenanceCollector._();

  static Future<ScanProvenance> collect() async {
    final packageInfo = await PackageInfo.fromPlatform();
    var model = defaultTargetPlatform.name;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        model = androidInfo.model;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        model = iosInfo.utsname.machine;
      }
    } catch (_) {}

    return ScanProvenance(
      platform: defaultTargetPlatform.name,
      deviceModel: model,
      appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    );
  }
}
