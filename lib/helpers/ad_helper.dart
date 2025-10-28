import 'package:flutter/material.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';
import 'package:attendance_alchemist/services/ad_service.dart';

// This function can now be called from ANY page
void showRewardedAdDialog({
  required BuildContext context,
  required String title,
  required String content,
  required VoidCallback onReward,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          child: const Text('No, Thanks'),
          onPressed: () => Navigator.of(ctx).pop(),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.movie_filter_rounded),
          label: const Text('Watch Ad'),
          onPressed: () {
            Navigator.of(ctx).pop();
            // TODO: Call your real AdService here to load/show the ad.
            // e.g., AdService.instance.showRewardedAd(
            //   adUnitId: 'YOUR_REWARDED_AD_ID',
            //   onReward: onReward, // The function to call on success
            // );
            AdService.instance.showRewardedAd(onReward: onReward);
            // --- FOR TESTING ---
            // We'll call the reward function immediately for testing.
            // showTopToast('Test Ad Watched!');
            // onReward();
            // --- END TESTING ---
          },
        ),
      ],
    ),
  );
}
