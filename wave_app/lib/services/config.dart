import 'package:flutter/foundation.dart';

class AppConfig {
  // We use localhost:8000 because we are using 'adb reverse'
  // to bridge the phone's port 8000 to the laptop's port 8000 over USB.
  static String get apiBaseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://localhost:8000';
  }
}
