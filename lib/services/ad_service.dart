import 'dart:io';
import 'package:flutter/foundation.dart'; // Required for kDebugMode
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart'; // Optional: for error messages
import 'package:attendance_alchemist/services/remote_config_service.dart';

class AdService {
  // --- Singleton Pattern ---
  AdService._privateConstructor();
  static final AdService instance = AdService._privateConstructor();
  // ---

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  final int _maxInterstitialLoadAttempts = 3;

  RewardedAd? _rewardedAd;
  int _rewardedLoadAttempts = 0;
  final int _maxRewardedLoadAttempts = 3;

  // --- Ad Unit IDs ---
  // IMPORTANT: REPLACE WITH YOUR ACTUAL IDs BEFORE RELEASE
  // Use Test IDs during development: https://developers.google.com/admob/android/test-ads

  // --- ANDROID ---

  static final String _androidBannerIdHome = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // <-- REPLACE
      : '';
  static final String _androidBannerIdAnalysis = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // <-- REPLACE (was SETTINGS_BANNER_ANDROID)
      : '';
  static final String _androidBannerIdPlanner = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // <-- REPLACE (was SETTINGS_BANNER_ANDROID)
      : '';
  static final String _androidBannerIdSchedule = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111' // <-- REPLACE (was SETTINGS_BANNER_ANDROID)
      : '';

  // static final String _androidInterstitialId = Platform.isAndroid
  //     ? 'ca-app-pub-YOUR_PUB_ID/INTERSTITIAL_ANDROID' // <-- REPLACE
  //     : '';
  // static final String _androidRewardedId = Platform.isAndroid
  //     ? 'ca-app-pub-YOUR_PUB_ID/REWARDED_ANDROID' // <-- REPLACE
  //     : '';

  static final String _androidInterstitialId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : '';
  static final String _androidRewardedId = Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917' // Always use test ID
      : '';

  // --- iOS ---
  static final String _iosBannerIdHome = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/HOME_BANNER_IOS' // <-- REPLACE
      : '';
  static final String _iosBannerIdAnalysis = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/ANALYSIS_BANNER_IOS' // <-- REPLACE
      : '';
  static final String _iosBannerIdPlanner = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/PLANNER_BANNER_IOS' // <-- REPLACE
      : '';

  static final String _iosInterstitialId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/INTERSTITIAL_IOS' // <-- REPLACE
      : '';
  static final String _iosRewardedId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/REWARDED_IOS' // <-- REPLACE
      : '';

  // --- Getters for Platform Specific IDs ---
  String get homeBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdHome : _iosBannerIdHome;
  String get analysisBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdAnalysis : _iosBannerIdAnalysis;
  String get plannerBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdPlanner : _iosBannerIdPlanner;
  String get scheduleBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdSchedule : _iosBannerIdPlanner;

  String get interstitialAdUnitId =>
      Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
  String get rewardedAdUnitId =>
      Platform.isAndroid ? _androidRewardedId : _iosRewardedId;

  // --- Banner Ad Logic ---
  // (We'll create a separate widget for banners, managed there)

  // --- Interstitial Ad Logic ---
  void createInterstitialAd() {
    if (!RemoteConfigService.instance.adsEnabled) {
      print(
        "AdService: Ads are disabled by Remote Config. Skipping interstitial load.",
      );
      return;
    }
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0; // Reset attempts on success
          print('InterstitialAd loaded.');
          _interstitialAd?.fullScreenContentCallback =
              _buildInterstitialCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          print('InterstitialAd failed to load: $error');
          if (_interstitialLoadAttempts <= _maxInterstitialLoadAttempts) {
            print('Retrying interstitial load...');
            createInterstitialAd(); // Retry loading
          }
        },
      ),
    );
  }

  FullScreenContentCallback<InterstitialAd> _buildInterstitialCallbacks() {
    return FullScreenContentCallback(
      onAdShowedFullScreenContent: (InterstitialAd ad) =>
          print('$ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose(); // Dispose the ad after dismissal
        createInterstitialAd(); // Preload the next one
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createInterstitialAd(); // Try preloading again
      },
    );
  }

  void showInterstitialAd() {
    if (!RemoteConfigService.instance.adsEnabled) {
      print(
        "AdService: Ads are disabled by Remote Config. Skipping interstitial show.",
      );
      return;
    }

    if (_interstitialAd == null) {
      print('Interstitial ad not ready yet.');
      // Optionally try loading one if it's null (might happen on first load)
      if (_interstitialLoadAttempts <= _maxInterstitialLoadAttempts) {
        createInterstitialAd();
      }
      return;
    }
    // _interstitialAd!.fullScreenContentCallback = _buildInterstitialCallbacks(); // Set callbacks before showing
    _interstitialAd!.show();
    _interstitialAd = null; // Ad is consumed after showing
  }

  // --- Rewarded Ad Logic ---
  void createRewardedAd() {
    if (!RemoteConfigService.instance.adsEnabled) {
      print(
        "AdService: Ads are disabled by Remote Config. Skipping rewarded load.",
      );
      return;
    }

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          print('$ad loaded.');
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0; // Reset load attempts on success
        },
        onAdFailedToLoad: (LoadAdError error) {
          print('RewardedAd failed to load: $error');
          _rewardedAd = null;
          _rewardedLoadAttempts += 1;
          if (_rewardedLoadAttempts <= _maxRewardedLoadAttempts) {
            print('Retrying rewarded ad load...');
            createRewardedAd(); // Retry loading
          }
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onReward}) {
    if (!RemoteConfigService.instance.adsEnabled) {
      print(
        "AdService: Ads are disabled by Remote Config. Skipping rewarded show.",
      );
      // Optionally show a toast? Or just fail silently.
      showErrorToast('Ads are temporarily unavailable.');
      return;
    }

    if (_rewardedAd == null) {
      print('Rewarded ad is not ready yet.');
      // Optionally show a toast or message
      showErrorToast('Reward ad not ready. Please try again shortly.');
      // Try to load one if not available
      if (_rewardedLoadAttempts <= _maxRewardedLoadAttempts) {
        createRewardedAd();
      }
      return;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) =>
          print('ad onAdShowedFullScreenContent.'),
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        print('$ad onAdDismissedFullScreenContent.');
        ad.dispose(); // Dispose the ad
        createRewardedAd(); // Load the next one
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        print('$ad onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        createRewardedAd(); // Load the next one
      },
    );

    // Set immersive mode before showing
    // _rewardedAd!.setImmersiveMode(true); // Uncomment if needed

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        print('$ad with reward $RewardItem(${reward.amount}, ${reward.type})');
        onReward(); // <<< Execute the reward callback
      },
    );
    _rewardedAd = null; // Ad is consumed
  }
}
