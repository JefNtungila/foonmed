import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

abstract class VibratorPort {
  Future<bool> isSupported();
  Future<void> start({required int durationMs});
  Future<void> stop();
}

class PlatformVibrator implements VibratorPort {
  static const MethodChannel _channel = MethodChannel('foonmed/vibrator');

  @override
  Future<bool> isSupported() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        return await _channel.invokeMethod<bool>('isSupported') ?? false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return true;
    }
    return false;
  }

  @override
  Future<void> start({required int durationMs}) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _channel.invokeMethod<void>('start', {'durationMs': durationMs});
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Vibration.vibrate(duration: durationMs);
      return;
    }
    throw UnsupportedError(
      'Vibration is not supported on ${defaultTargetPlatform.name}',
    );
  }

  @override
  Future<void> stop() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        await _channel.invokeMethod<void>('stop');
      } on PlatformException {
        // ignore
      } on MissingPluginException {
        // ignore
      }
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Vibration.cancel();
    }
  }
}
