import 'package:flutter/material.dart';

class AdProvider with ChangeNotifier {
  // These will reset to 'false' every time the app starts
  bool _isDarkThemeUnlocked = false;
  bool get isDarkThemeUnlocked => _isDarkThemeUnlocked;

  bool _isAbsenceTrendUnlocked = false;
  get isAbsenceTrendUnlocked => _isAbsenceTrendUnlocked;

  // For interstitial ad frequency
  int _calculationsSinceAd = 0;
  static const int _showAdAfterCalculations = 5;

  DateTime? _lastInterstitialShowTime; // Track when the last ad was shown
  // ...AND only if at least 1.5 minutes have passed
  static const Duration _minTimeBetweenAds = Duration(
    seconds: 90,
  ); // 1.5 minutes

  void unlockDarkTheme() {
    if (!_isDarkThemeUnlocked) {
      _isDarkThemeUnlocked = true;
      notifyListeners();
    }
  }

  void unlockAbsenceTrend() {
    if (!_isAbsenceTrendUnlocked) {
      _isAbsenceTrendUnlocked = true;
      notifyListeners();
    }
  }

  // --- Interstitial Logic ---
  void incrementCalculationCounter() {
    _calculationsSinceAd++;
  }

  bool get shouldShowInterstitial {
    final now = DateTime.now();
    bool calculationThresholdMet =
        _calculationsSinceAd >= _showAdAfterCalculations;
    bool timeDelayMet = true;

    // Check time delay only if an ad has been shown before
    if (_lastInterstitialShowTime != null) {
      timeDelayMet =
          now.difference(_lastInterstitialShowTime!) > _minTimeBetweenAds;
      print(
        "Time since last ad: ${now.difference(_lastInterstitialShowTime!)}. Delay met: $timeDelayMet",
      );
    } else {
      print("No last ad time recorded, time delay condition met by default.");
    }

    // Ad should show only if BOTH conditions are met
    if (calculationThresholdMet && timeDelayMet) {
      print("Threshold and Time Delay MET. Resetting counter and showing ad.");
      _calculationsSinceAd = 0; // Reset calculation counter
      _lastInterstitialShowTime = now; // Record the time this ad is shown
      return true;
    }

    // Debugging logs if conditions aren't met
    if (!calculationThresholdMet)
      print(
        "Calculation threshold NOT met ($_calculationsSinceAd < $_showAdAfterCalculations).",
      );
    if (!timeDelayMet)
      print(
        "Time delay NOT met (Last ad shown at: $_lastInterstitialShowTime).",
      );

    return false; // Don't show ad if either condition fails
  }
}
