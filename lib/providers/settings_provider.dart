// lib/providers/settings_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart'; // For kDebugMode (optional for print/debugPrint)
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';

// Enum defining the possible actions on app launch/resume
enum AppLaunchOption { resume, clipboard, none }

class SettingsProvider with ChangeNotifier {
  // Use the SharedPreferences instance passed from main.dart
  final SharedPreferences prefs;

  // --- Settings Keys (Constants for safety) ---
  static const String launchOptionKey = 'launchOption';
  static const String showResultOverlayKey = 'showOverlay';
  static const String proactiveAlertsKey = 'proactiveAlerts';

  // --- Settings Properties with Defaults ---
  AppLaunchOption _launchOption = AppLaunchOption.resume; // Default to resume
  AppLaunchOption get launchOption => _launchOption;

  bool _showResultOverlay = true; // Default value
  bool get showResultOverlay => _showResultOverlay;

  bool _proactiveAlerts = false; // Default value
  bool get proactiveAlerts => _proactiveAlerts;

  // --- Initialization State ---
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // Completer to signal when initialization is done
  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationComplete => _initCompleter.future;

  // --- Constructor ---
  // Accepts the SharedPreferences instance
  SettingsProvider({required this.prefs}) {
    // Load settings immediately using the provided instance
    _loadSettings();
  }

  // --- Load Settings ---
  Future<void> _loadSettings() async {
    try {
      // Use the 'prefs' instance variable directly

      // Load Launch Option
      String savedLaunchOptionName =
          prefs.getString(launchOptionKey) ??
          AppLaunchOption.resume.name; // Default resume
      // Find the enum value matching the saved name
      _launchOption = AppLaunchOption.values.firstWhere(
        (e) => e.name == savedLaunchOptionName,
        orElse: () => AppLaunchOption.resume, // Fallback to resume
      );

      // Load Show Result Overlay preference
      _showResultOverlay =
          prefs.getBool(showResultOverlayKey) ?? true; // Default true

      // Load Proactive Alerts preference
      _proactiveAlerts =
          prefs.getBool(proactiveAlertsKey) ?? false; // Default false

      _isInitialized = true;
      debugPrint(
        // Use debugPrint for better logging during development
        "Settings Loaded: Launch Option = $_launchOption, Show Overlay = $_showResultOverlay, Proactive Alerts = $_proactiveAlerts",
      );

      // Signal initialization complete if not already done
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      notifyListeners(); // Notify listeners after loading all settings

      // Optional: Show toast based on initial load (might be annoying, consider removing)
      // if (_launchOption == AppLaunchOption.resume) {
      //   showTopToast("🔄 Resumed last save");
      // } else if (_launchOption == AppLaunchOption.clipboard) {
      //   showTopToast("📋 Pasting from clipboard");
      // }
    } catch (e, stacktrace) {
      debugPrint("Error loading settings: $e\n$stacktrace");
      // Set defaults on error
      _launchOption = AppLaunchOption.resume;
      _showResultOverlay = true;
      _proactiveAlerts = false;
      _isInitialized = true; // Still consider initialized, just with defaults

      // Signal completion (or error) if not already done
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stacktrace); // Signal error
      }
      notifyListeners();
    }
  }

  // --- Update Methods ---
  Future<void> setLaunchOption(AppLaunchOption option) async {
    if (_launchOption != option) {
      _launchOption = option;
      await prefs.setString(launchOptionKey, option.name);
      debugPrint("Settings Saved: Launch Option set to $_launchOption");
      showTopToast(
        "Launch Option set to ${option.name}",
      ); // Keep toast for user feedback
      notifyListeners();
    }
  }

  Future<void> setShowResultOverlay(bool show) async {
    if (_showResultOverlay != show) {
      _showResultOverlay = show;
      await prefs.setBool(showResultOverlayKey, show);
      debugPrint("Settings Saved: Show Overlay = $_showResultOverlay");
      notifyListeners();
    }
  }

  Future<void> setProactiveAlerts(bool show) async {
    if (_proactiveAlerts != show) {
      _proactiveAlerts = show;
      await prefs.setBool(proactiveAlertsKey, show);
      debugPrint("Settings Saved: Proactive Alerts = $_proactiveAlerts");
      notifyListeners();
      // Remember: Logic to register/cancel the background task is in SettingsPage's _onProactiveAlertsChanged
    }
  }

  Future<void> resetAllSettings() async {
    // Clear all preferences managed by this app.
    // Be careful if other parts of the app use SharedPreferences independently.
    // Consider removing specific keys instead of clear() if necessary.
    // await prefs.remove(launchOptionKey);
    // await prefs.remove(showResultOverlayKey);
    // await prefs.remove(proactiveAlertsKey);
    // Add removes for any other settings keys used ONLY by this provider.

    // A full clear might be okay if this provider manages ALL settings.
    await prefs.clear();

    // Reload settings, which will apply defaults and notify listeners
    await _loadSettings();
    showTopToast("Settings reset to defaults"); // User feedback
  }
}
