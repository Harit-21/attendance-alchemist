import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// class ThemeProvider extends ChangeNotifier {
//   final SharedPreferences prefs;
//   ThemeMode _themeMode;

//   ThemeProvider({required this.prefs})
//     : _themeMode = _loadThemeFromPrefs(prefs);

//   ThemeMode get themeMode => _themeMode;

//   bool get isDarkMode => _themeMode == ThemeMode.dark;

//   // This matches the logic from the web app
//   // static ThemeMode _loadThemeFromPrefs(SharedPreferences prefs) {
//   //   final theme = prefs.getString('color-theme');
//   //   if (theme == 'dark') {
//   //     return ThemeMode.dark;
//   //   } else if (theme == 'light') {
//   //     return ThemeMode.light;
//   //   } else {
//   //     // If no preference, default to system
//   //     return ThemeMode.system;
//   //   }
//   // }

//   // This matches the logic from the web app
//   static ThemeMode _loadThemeFromPrefs(SharedPreferences prefs) {
//     final theme = prefs.getString('color-theme');
//     if (theme == 'dark') {
//       return ThemeMode.dark;
//     } else if (theme == 'light') {
//       return ThemeMode.light;
//     } else {
//       // ✅ On first launch, match system brightness immediately
//       final systemBrightness =
//           WidgetsBinding.instance.platformDispatcher.platformBrightness;
//       final isDark = systemBrightness == Brightness.dark;
//       prefs.setString('color-theme', isDark ? 'dark' : 'light');
//       return isDark ? ThemeMode.dark : ThemeMode.light;
//     }
//   }

//   void toggleTheme(bool isDark) {
//     _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
//     // Save the preference
//     prefs.setString('color-theme', isDark ? 'dark' : 'light');
//     // Notify all listeners to rebuild
//     notifyListeners();
//   }
// }

class ThemeProvider extends ChangeNotifier {
  // SharedPreferences is no longer needed for initial loading,
  // but keep it if you save other settings here.
  final SharedPreferences prefs;

  // --- START LIGHT BY DEFAULT ---
  ThemeMode _themeMode = ThemeMode.light;

  // Remove the constructor logic that loads from prefs
  ThemeProvider({required this.prefs});

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // --- REMOVE or COMMENT OUT _loadThemeFromPrefs ---
  // static ThemeMode _loadThemeFromPrefs(SharedPreferences prefs) {
  //   // ... (logic removed) ...
  //   return ThemeMode.light; // Always start light
  // }

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    // --- DO NOT SAVE THE PREFERENCE ---
    // Saving happens only through AdProvider unlock now
    // prefs.setString('color-theme', isDark ? 'dark' : 'light');
    notifyListeners();
  }

  // Optional: Add a method specifically for unlocking via ad
  void applyUnlockedTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    // You could potentially save the *unlocked* state here if needed
    // prefs.setString('color-theme', isDark ? 'dark' : 'light');
  }
}
