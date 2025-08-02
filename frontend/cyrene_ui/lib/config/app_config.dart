import 'package:flutter/material.dart';

class AppConfig {
  static const String appName = 'Cyrene AI Console';
  static const String version = '1.0.0';

  // API Configuration
  static const String fastApiAuthUrl = "http://localhost:8001";
  static const String fastApiBotUrl = "http://localhost:8000";

  // Storage Keys
  static const String authTokenKey = 'auth_token';
  static const String userPrefsKey = 'user_preferences';
  static const String themeKey = 'theme_mode';

  // Default Values
  static const String defaultModelProvider = 'groq';
  static const String defaultModel = 'llama3-8b-8192';
  static const double defaultTemperature = 0.7;
  static const int defaultMaxTokens = 8192;

  // UI Constants
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;
  static const EdgeInsets defaultPadding = EdgeInsets.all(16.0);
  static const EdgeInsets screenPadding = EdgeInsets.all(24.0);
}
