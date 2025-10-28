import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'; // For ChangeNotifier

class RemoteConfigService with ChangeNotifier {
  // --- Singleton Pattern ---
  RemoteConfigService._privateConstructor();
  static final RemoteConfigService instance =
      RemoteConfigService._privateConstructor();
  // ---

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // --- Default value ---
  // This is the value used if fetching fails or before it completes.
  // Set it to `false` for maximum safety. If it can't reach Firebase,
  // it will default to ads OFF.
  final Map<String, dynamic> _defaultValues = {'ads_enabled': false};

  // --- Getter ---
  bool get adsEnabled => _remoteConfig.getBool('ads_enabled');

  // --- ADD THESE METHODS ---
  int getInt(String key) {
    return _remoteConfig.getInt(key);
  }

  String getString(String key) {
    return _remoteConfig.getString(key);
  }

  bool getBool(String key) {
    // Good to have for consistency
    return _remoteConfig.getBool(key);
  }

  Future<void> init() async {
    try {
      // 1. Set in-app default values
      await _remoteConfig.setDefaults(_defaultValues);

      // 2. Set config settings for fetching (e.g., how often to refresh)
      // For an emergency switch, you want a short refresh time.
      // For normal use, 12 hours is fine. Let's use 1 hour.
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          // This controls how long the app uses a cached value before
          // trying to fetch a new one.
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // 3. Fetch and Activate
      await _remoteConfig.fetchAndActivate();

      print('Remote Config fetched and activated.');
      print('Ads Enabled: $adsEnabled');

      // Notify listeners that the value might have updated
      notifyListeners();
    } catch (e) {
      print('Error initializing Remote Config: $e');
      // Will use the default value (false)
    }
  }

  Future<bool> fetchAndActivate() async {
    try {
      bool updated = await _remoteConfig.fetchAndActivate();
      if (updated) {
        print('Remote Config fetched and activated successfully.');
        notifyListeners(); // Notify if values might have changed
      } else {
        print('Remote Config fetch successful, but no new values activated.');
      }
      return updated;
    } catch (e) {
      print('Error fetching/activating Remote Config: $e');
      return false;
    }
  }
}
