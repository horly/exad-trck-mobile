import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppUpdateService {
  const AppUpdateService();
  static const channel = MethodChannel('com.exad.exad_tracking_mobile/updates');

  /// Google Play checks the installed build and the release available to this account/device.
  Future<int?> availableBuild() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final result = await channel
          .invokeMapMethod<String, dynamic>('checkForUpdate')
          .timeout(const Duration(seconds: 10));
      final build = result?['build'];
      return result?['available'] == true && build is int && build > 0
          ? build
          : null;
    } catch (_) {
      // Offline, sideloaded and unowned installs must not block the dashboard or invent an update.
      return null;
    }
  }

  Future<bool> openStore() async {
    try {
      return await channel
              .invokeMethod<bool>('openStore')
              .timeout(const Duration(seconds: 10)) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
