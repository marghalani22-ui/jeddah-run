import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Asks for location access, explaining what is missing when it fails.
Future<bool> ensureLocation(BuildContext context) async {
  void say(String m) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  if (!await Geolocator.isLocationServiceEnabled()) {
    say('شغّل الموقع (GPS) من إعدادات الجوال');
    await Geolocator.openLocationSettings();
    return false;
  }
  var p = await Geolocator.checkPermission();
  if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
  if (p == LocationPermission.deniedForever) {
    say('اسمح للتطبيق بالموقع من الإعدادات');
    await Geolocator.openAppSettings();
    return false;
  }
  return p == LocationPermission.always || p == LocationPermission.whileInUse;
}

Future<bool> hasLocation() async {
  final p = await Geolocator.checkPermission();
  return p == LocationPermission.always || p == LocationPermission.whileInUse;
}

/// High-accuracy stream that keeps running with the screen off.
LocationSettings runSettings() => AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'جري جدة',
        notificationText: 'نسجّل جولتك الحين',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
