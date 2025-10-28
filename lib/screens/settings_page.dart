import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:provider/provider.dart';
import 'package:attendance_alchemist/providers/settings_provider.dart';
import 'package:attendance_alchemist/providers/theme_provider.dart'; // <-- ADDED
import 'package:attendance_alchemist/widgets/custom_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:attendance_alchemist/mixins/scroll_to_top_mixin.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';
import 'package:attendance_alchemist/screens/schedule_page.dart';
import 'package:attendance_alchemist/providers/ad_provider.dart';
import 'package:workmanager/workmanager.dart';
import 'package:attendance_alchemist/helpers/ad_helper.dart';
import 'package:attendance_alchemist/services/remote_config_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> with ScrollToTopMixin {
  String _appVersion = 'Loading...';
  bool _showFooter = false; // <-- ADD State variable for footer visibility
  final double _footerRevealThreshold = 50.0;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    scrollController.removeListener(_scrollListener);
    // The mixin handles disposing scrollController
    super.dispose();
  }

  void _scrollListener() {
    if (scrollController.position.maxScrollExtent == 0)
      return; // Avoid check if not scrollable

    final show =
        scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - _footerRevealThreshold;

    if (show != _showFooter) {
      // Only update state if visibility changes
      setState(() {
        _showFooter = show;
      });
    }
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'Version ${info.version} (Build ${info.buildNumber})';
      });
    }
  }

  Future<void> _launchURL(String urlString, {String? mailtoSubject}) async {
    Uri url;
    if (mailtoSubject != null) {
      url = Uri(
        scheme: 'mailto',
        path: urlString,
        query:
            'subject=${Uri.encodeComponent(mailtoSubject)}&body=${Uri.encodeComponent("\n\nApp Version: $_appVersion\n")}',
      );
    } else {
      url = Uri.parse(urlString);
    }
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        showErrorToast('Could not launch $urlString');
      }
    } catch (e) {
      showErrorToast('Error: $e');
    }
  }

  // --- Confirmation Dialog for Reset ---
  void _showResetConfirmation(BuildContext context, SettingsProvider provider) {
    HapticFeedback.heavyImpact(); // Signal danger
    FocusScope.of(context).requestFocus(FocusNode());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you sure?'),
        content: const Text(
          'All settings (launch action, pop-up preference) will be reset to their defaults. This cannot be undone.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.warning_amber_rounded),
            label: const Text('Reset'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              provider.resetAllSettings(); // Call the provider method
              Navigator.of(ctx).pop();
              HapticFeedback.lightImpact();
              showTopToast('Settings have been reset.');
            },
          ),
        ],
      ),
    );
  }

  void _onProactiveAlertsChanged(bool value, SettingsProvider provider) {
    HapticFeedback.lightImpact();
    provider.setProactiveAlerts(value);
    const uniqueTaskName = "dailyAttendanceCheck8AM";

    if (value) {
      // --- REGISTER THE TASK ---
      // Workmanager().registerOneOffTask(
      //   // Change to "OneOffTask"
      //   "1", // Unique ID
      //   "dailyAttendanceCheck",
      //   initialDelay: const Duration(minutes: 1), // Run it in 1 minute
      //   constraints: Constraints(
      //     networkType: NetworkType.not_required,
      //     requiresBatteryNotLow: false, // Don't worry about battery for testing
      //   ),
      // );
      //   Workmanager().registerPeriodicTask(
      //     "1", // Unique ID
      //     "dailyAttendanceCheck",
      //     frequency: const Duration(minutes: 16), // How often to run
      //     // frequency: const Duration(hours: 12), // Example: Check twice a day
      //     constraints: Constraints(
      //       networkType: NetworkType.not_required,
      //       requiresBatteryNotLow: true,
      //     ),
      //   );
      //   showTopToast("Proactive Alerts Enabled!");
      // } else {
      final now = DateTime.now();
      DateTime next8AM = DateTime(
        now.year,
        now.month,
        now.day,
        8,
        0,
        0,
      ); // Today 8 AM
      if (now.isAfter(next8AM)) {
        // If it's already past 8 AM today, schedule for 8 AM tomorrow
        next8AM = next8AM.add(const Duration(days: 1));
      }
      final initialDelay = next8AM.difference(now);

      print(
        'Scheduling background check. Next run around: $next8AM (in $initialDelay)',
      );

      Workmanager().registerPeriodicTask(
        uniqueTaskName,
        "dailyAttendanceCheck",
        frequency: const Duration(
          hours: 24,
        ), // Run roughly once a day after the initial delay
        initialDelay: initialDelay, // Delay until the next 8 AM
        existingWorkPolicy: ExistingWorkPolicy
            .replace, // Replace if already scheduled with this name
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresCharging: false, // Don't require charging
          requiresBatteryNotLow: false, // Prefer not to run on low battery
        ),
      );
      showTopToast(
        "Proactive Alerts Enabled! Next check scheduled around 8 AM.",
      );
    } else {
      // --- CANCEL THE TASK ---
      // Workmanager().cancelByUniqueName("1");
      Workmanager().cancelByUniqueName(uniqueTaskName);
      showTopToast("Alerts Disabled.");
    }
  }

  void _showRewardedAdDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onReward,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            child: const Text('No, Thanks'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            child: const Text('Watch Ad'),
            onPressed: () {
              Navigator.of(ctx).pop();
              // You would call your AdService here
              // e.g., AdService.instance.showRewardedAd(
              //   adUnitId: 'YOUR_DARK_MODE_REWARDED_ID',
              //   onReward: onReward,
              // );

              // --- FOR TESTING ---
              showTopToast('Showing test ad...');
              onReward(); // Instantly reward for testing
              // --- END TESTING ---
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return; // Prevent multiple checks
    setState(() => _isCheckingUpdate = true);
    showTopToast('Checking for updates...');

    try {
      // 1. Get Current App Info
      final currentInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(currentInfo.buildNumber) ?? 0;
      final currentVersionName = currentInfo.version;

      // 2. Fetch Latest Version Info from Remote Config
      // Ensure Remote Config is fetched (it might already be fetched on app start)
      // You could add a specific fetch here if needed:
      // await RemoteConfigService.instance.fetchAndActivate();

      final latestVersionCode = RemoteConfigService.instance.getInt(
        'latest_version_code',
      );
      final latestVersionName = RemoteConfigService.instance.getString(
        'latest_version_name',
      );
      final updateUrl = RemoteConfigService.instance.getString('update_url');

      print('Current: Code=$currentVersionCode, Name=$currentVersionName');
      print('Latest: Code=$latestVersionCode, Name=$latestVersionName');

      // 3. Compare Versions (Prioritize Version Code)
      if (latestVersionCode > currentVersionCode) {
        // Update available
        if (mounted) {
          _showUpdateDialog(latestVersionName, updateUrl);
        }
      } else {
        // App is up-to-date
        showTopToast('✅ You have the latest version ($currentVersionName)');
      }
    } catch (e) {
      print("Error checking for updates: $e");
      showErrorToast('Could not check for updates. Please try again later.');
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  // --- ADD Update Dialog Method ---
  void _showUpdateDialog(String latestVersionName, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // User must interact
      builder: (ctx) => AlertDialog(
        title: const Text('✨ Update Available!'),
        content: Text(
          'A newer version ($latestVersionName) is available. Update now for the latest features and fixes.',
        ),
        actions: [
          TextButton(
            child: const Text('Later'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.system_update_alt_rounded),
            label: const Text('Update Now'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (updateUrl.isNotEmpty) {
                _launchURL(updateUrl); // Use your existing URL launcher
              } else {
                showErrorToast('Update URL not configured yet.');
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final adProvider = Provider.of<AdProvider>(context);
    final bool isDark = themeProvider.isDarkMode;
    final bool isUnlocked = adProvider.isDarkThemeUnlocked;

    final bool showProactiveAlertsFeature = false;

    // void handleDarkModeToggle(bool newValue) {
    //   HapticFeedback.lightImpact();
    //   if (newValue == true) {
    //     // Trying to turn ON
    //     if (isUnlocked) {
    //       themeProvider.toggleTheme(true); // Already unlocked
    //     } else {
    //       // --- SHOW THE AD DIALOG (from our new helper) ---
    // FocusScope.of(context).requestFocus(FocusNode());
    //       showRewardedAdDialog(
    //         context: context,
    //         title: 'Unlock Dark Mode',
    //         content:
    //             'Watch a short ad to unlock Dark Mode for this app session?',
    //         onReward: () {
    //           adProvider.unlockDarkTheme();
    //           themeProvider.toggleTheme(true);
    //         },
    //       );
    //     }
    //   } else {
    //     // Trying to turn OFF
    //     themeProvider.toggleTheme(false); // Always allow
    //   }
    // }

    void handleDarkModeToggle(bool newValue) {
      HapticFeedback.lightImpact();
      // Use listen: false inside callbacks/handlers
      final adProviderListenFalse = Provider.of<AdProvider>(
        context,
        listen: false,
      );
      final themeProviderListenFalse = Provider.of<ThemeProvider>(
        context,
        listen: false,
      );

      if (newValue == true) {
        // Trying to turn ON Dark Mode
        if (adProviderListenFalse.isDarkThemeUnlocked) {
          themeProviderListenFalse.applyUnlockedTheme(true);
        } else {
          // 1. Immediately request Dark Mode rebuild
          themeProviderListenFalse.toggleTheme(true);

          // 2. Use a simple Future.delayed
          Future.delayed(const Duration(milliseconds: 650), () {
            // Adjust duration
            if (!mounted) return;

            // 3. Revert to Light Mode *only if still locked*
            if (!Provider.of<AdProvider>(
              context,
              listen: false,
            ).isDarkThemeUnlocked) {
              themeProviderListenFalse.toggleTheme(false);

              // 4. Show the Ad Dialog *after* reverting (and only if still locked)
              FocusScope.of(context).requestFocus(FocusNode());
              showRewardedAdDialog(
                context: context,
                title: 'Unlock Dark Mode',
                content:
                    'Watch a short ad to unlock Dark Mode for this app session?',
                onReward: () {
                  if (!mounted) return;
                  Provider.of<AdProvider>(
                    context,
                    listen: false,
                  ).unlockDarkTheme();
                  themeProviderListenFalse.applyUnlockedTheme(true);
                },
              );
            }
          });
        }
      } else {
        themeProviderListenFalse.applyUnlockedTheme(false);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- App Header ---
                _buildSectionHeader(context, '🎓 My Schedule'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildSettingsTile(
                    context: context,
                    icon: Icons.calendar_month_rounded,
                    color: Colors.cyan.shade600,
                    title: 'Manage Class Schedule',
                    subtitle: 'Set your weekly recurring classes',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SchedulePage()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                // Padding(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 8.0,
                //     vertical: 16.0,
                //   ),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.center,
                //     crossAxisAlignment: CrossAxisAlignment.center, //centering
                //     children: [
                //       Image.asset(
                //         'assets/icon/icon.png',
                //         width: 60,
                //         height: 60,
                //       ), // Assuming you have an icon here
                //       const SizedBox(width: 16),
                //       Column(
                //         crossAxisAlignment: CrossAxisAlignment.start,
                //         children: [
                //           Text(
                //             'Attendance\nAlchemist',
                //             style: theme.textTheme.headlineSmall?.copyWith(
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //           Text(
                //             _appVersion,
                //             style: theme.textTheme.bodyMedium?.copyWith(
                //               color: theme.hintColor,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ],
                //   ),
                // ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 15.0),
                  child: Center(
                    // Center widget already correctly centers the Row horizontally
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Image.asset('assets/icon/icon.png', width: 60, height: 60),
                        // const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Attendance\nAlchemist',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _appVersion,
                              textAlign:
                                  TextAlign.center, // Center version text
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- General Settings Section ---
                _buildSectionHeader(context, '⚙️ General'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildSettingsToggle(
                        context: context,
                        icon: isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: Colors.blueAccent,
                        title: 'Dark Mode',
                        subtitle: (isUnlocked || isDark)
                            ? 'Switch between light and dark themes'
                            : 'Watch an ad to unlock for this session', // New subtitle
                        value: isDark,
                        onChanged: handleDarkModeToggle,
                        trailingWidget: (isUnlocked || isDark)
                            ? Switch(
                                value: isDark,
                                onChanged: handleDarkModeToggle,
                                activeColor: theme.colorScheme.primary,
                              )
                            : Icon(
                                Icons.movie_filter_rounded,
                                color: theme.colorScheme.primary,
                              ),
                      ),
                      _buildSettingsToggle(
                        context: context,
                        icon: Icons.reviews_outlined,
                        color: Colors.green,
                        title: 'Show Result Pop-up',
                        subtitle: 'Display a summary after calculation',
                        value: settingsProvider.showResultOverlay,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          settingsProvider.setShowResultOverlay(value);
                        },
                      ),
                      if (showProactiveAlertsFeature)
                        _buildSettingsToggle(
                          context: context,
                          icon: Icons.auto_awesome_rounded,
                          color: Colors.amber.shade700,
                          title: 'Proactive Alerts (Beta)', //(Premium)
                          subtitle:
                              'Get notified if you are in the danger zone',
                          value: settingsProvider.proactiveAlerts,
                          onChanged: (value) {
                            // This is where you would show a paywall.
                            // For now, we'll just enable it directly.
                            _onProactiveAlertsChanged(value, settingsProvider);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- On App Launch Section ---
                _buildSectionHeader(context, '🚀 On App Launch'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildSettingsRadio<AppLaunchOption>(
                        context: context,
                        icon: Icons.replay_rounded,
                        color: Colors.purpleAccent,
                        title: 'Resume Last Save',
                        subtitle: 'Automatically load your last saved data',
                        value: AppLaunchOption.resume,
                        groupValue: settingsProvider.launchOption,
                        onChanged: (value) {
                          if (value != null) {
                            HapticFeedback.lightImpact();
                            settingsProvider.setLaunchOption(value);
                          }
                        },
                      ),
                      _buildSettingsRadio<AppLaunchOption>(
                        context: context,
                        icon: Icons.content_paste_go_rounded,
                        color: Colors.orangeAccent,
                        title: 'Paste from Clipboard',
                        subtitle: 'Automatically paste and calculate',
                        value: AppLaunchOption.clipboard,
                        groupValue: settingsProvider.launchOption,
                        onChanged: (value) {
                          if (value != null) {
                            HapticFeedback.lightImpact();
                            settingsProvider.setLaunchOption(value);
                          }
                        },
                      ),
                      _buildSettingsRadio<AppLaunchOption>(
                        context: context,
                        icon: Icons.do_not_disturb_on_outlined,
                        color: Colors.grey,
                        title: 'Do Nothing',
                        subtitle: 'Start with a clean slate each time',
                        value: AppLaunchOption.none,
                        groupValue: settingsProvider.launchOption,
                        onChanged: (value) {
                          if (value != null) {
                            HapticFeedback.lightImpact();
                            settingsProvider.setLaunchOption(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- Get in Touch Section ---
                _buildSectionHeader(context, '💬 Get in Touch'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.email_outlined,
                        color: Colors.teal,
                        title: 'Email Us for Support',
                        subtitle: 'We\'ll get back to you soon',
                        onTap: () {
                          _launchURL(
                            'mailto:themadbrogrammers@gmail.com',
                            mailtoSubject: 'Attendance Alchemist Feedback',
                          );
                        },
                      ),
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.bug_report_outlined,
                        color: Colors.redAccent,
                        title: 'Report an Issue',
                        subtitle: 'Find a bug? Let us know on GitHub',
                        onTap: () {
                          _launchURL(
                            'https://github.com/your-repo/issues',
                          ); // <-- REPLACE
                        },
                      ),
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.star_outline_rounded,
                        color: Colors.yellow.shade700,
                        title: 'Rate the App',
                        subtitle: 'Enjoying the app? Leave a review!',
                        onTap: () {
                          _launchURL(
                            'https://play.google.com/store/apps/details?id=com.themadbrogrammers.attendance_alchemist',
                          ); // <-- REPLACE
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- "About & Legal" Section ---
                _buildSectionHeader(context, 'ℹ️ About & Legal'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.info_outline,
                        color: Colors.blueGrey,
                        title: 'App Version',
                        subtitle: _appVersion,
                        onTap: _isCheckingUpdate
                            ? null
                            : _checkForUpdates, // Call the check function
                        // --- ADD a trailing widget for loading state ---
                        trailingWidget: _isCheckingUpdate
                            ? const SizedBox(
                                // Show loading indicator
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                      ),
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.privacy_tip_outlined,
                        color: Colors.green.shade700,
                        title: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {
                          _launchURL(
                            'https://thingdoms.web.app/attendance-alchemist/privacy.html',
                          ); // <-- REPLACE
                        },
                      ),
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.gavel_outlined,
                        color: Colors.brown,
                        title: 'Terms of Service',
                        subtitle: 'The rules of use',
                        onTap: () {
                          _launchURL(
                            'https://thingdoms.web.app/attendance-alchemist/terms.html',
                          ); // <-- REPLACE
                        },
                      ),
                      _buildSettingsTile(
                        context: context,
                        icon: Icons.copy_all_rounded,
                        color: Colors.indigoAccent,
                        title: 'Copy Debug Info',
                        subtitle: 'Helpful for support requests',
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await Clipboard.setData(
                            ClipboardData(
                              text:
                                  'App Version: $_appVersion\n(Add other device info if needed)',
                            ),
                          );
                          showTopToast('Debug info copied to clipboard!');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // --- DANGER ZONE ---
                _buildSectionHeader(context, '🔥 Danger Zone'),
                CustomCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _buildSettingsTile(
                    context: context,
                    icon: Icons.delete_forever_rounded,
                    color: Colors.red.shade700,
                    title: 'Reset All Settings',
                    titleColor: Colors.red.shade700, // Make title red too
                    subtitle: 'Restores all settings to their defaults',
                    onTap: () =>
                        _showResetConfirmation(context, settingsProvider),
                  ),
                ),

                const SizedBox(height: 75),
                // Footer Text
                AnimatedOpacity(
                  opacity: _showFooter ? 1.0 : 0.0, // Control opacity via state
                  duration: const Duration(milliseconds: 300), // Fade duration
                  curve: Curves.easeIn, // Animation curve
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
                      child: Center(
                        child: Text(
                          '© ${DateTime.now().year} Attendance Alchemist\nMade with ❤️',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Section Header ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: title.startsWith('🔥') ? Colors.red.shade600 : null,
        ),
      ),
    );
  }

  // --- NEW Awesome Settings Tile ---
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Color? titleColor,
    required VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: titleColor ?? theme.textTheme.bodyLarge?.color,
        ),
      ),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing:
          trailingWidget ??
          (onTap != null
              ? const Icon(Icons.arrow_forward_ios_rounded, size: 16)
              : null),
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      enabled: onTap != null,
    );
  }

  // --- NEW Awesome Toggle Tile ---
  Widget _buildSettingsToggle({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing:
          trailingWidget ??
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
      onTap: () {
        // Toggle when tapping the row, not just the switch
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
    );
  }

  // --- NEW Awesome Radio Tile ---
  Widget _buildSettingsRadio<T>({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
      onTap: () {
        // Select when tapping the row, not just the radio
        if (value != groupValue) {
          onChanged(value);
        }
      },
    );
  }
}
