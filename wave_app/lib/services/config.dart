import 'package:flutter/foundation.dart';

class AppConfig {
  static const String apiBaseUrl = kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
}
