import 'dart:io'; // Import for File, Directory, Platform operations
import 'package:file_picker/file_picker.dart'; // Import file_picker classes
import 'package:path_provider/path_provider.dart'; // Import path_provider functions
import 'package:permission_handler/permission_handler.dart'; // Import permission_handler classes & functions
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart'; // For indicators
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/providers/theme_provider.dart';
import 'package:attendance_alchemist/widgets/custom_card.dart'; // Using CustomCard for consistency
import 'package:attendance_alchemist/widgets/dropzone_widget.dart'; // Still used for file drop/pick
import 'package:attendance_alchemist/widgets/saves_modal.dart';
import 'package:attendance_alchemist/widgets/max_drop_overlay.dart';
import 'package:attendance_alchemist/widgets/path_to_target_dialog.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';
import 'package:attendance_alchemist/mixins/scroll_to_top_mixin.dart';
import 'dart:async';
import 'package:attendance_alchemist/helpers/ad_helper.dart';
import 'package:attendance_alchemist/providers/ad_provider.dart';
import 'package:attendance_alchemist/services/ad_service.dart';
import 'package:attendance_alchemist/widgets/banner_ad_widget.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class HomePage extends StatefulWidget {
  final bool isActive;

  const HomePage({super.key, required this.isActive});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage>
    with WidgetsBindingObserver, ScrollToTopMixin {
  final _targetPercentController = TextEditingController();
  final _rawDataController = TextEditingController();
  bool _showRawDataInput = false; // Start with text input hidden by default

  final GlobalKey _resultsKey = GlobalKey();

  // DateTime? _lastResultTimestamp;
  SharedPreferences? _prefs;

  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _prefs = await SharedPreferences.getInstance();
      _initializeControllers();
      _targetPercentController.addListener(_onTargetPercentageChanged);
      Provider.of<AttendanceProvider>(
        context,
        listen: false,
      ).addListener(_onProviderUpdate);
      _handleAppLaunchOrResume();
    });
  }

  Future<void> _handleAppLaunchOrResume() async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    // Ensure prefs are loaded
    _prefs ??= await SharedPreferences.getInstance();
    final String preference =
        _prefs?.getString('loadPreference') ?? 'none'; // Default to 'none'

    print("Handling App Launch/Resume. Preference: $preference"); // Debug print

    // Only handle if provider doesn't already have data from a previous load
    if (provider.rawData.isEmpty) {
      if (preference == 'clipboard') {
        print("Attempting auto-paste...");
        await _handlePaste(context); // Call existing paste handler
      } else if (preference == 'resume') {
        print("Attempting auto-resume (handled by provider's loadSavedData)");
        // Assuming loadSavedData is called elsewhere on init or handled manually
        // bool loaded = await provider.loadSavedData(); // Or call it here if needed
      }
      // 'none' does nothing
    } else {
      print("Provider already has data, skipping launch action.");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reset the flag when the app resumes
      print("App resumed, resetting overlay flag."); // Debug print
      Provider.of<AttendanceProvider>(
        context,
        listen: false,
      ).resetOverlayFlag();
      // Optionally trigger a check if data exists?
      // _showMaxDropOverlayIfNeeded(); // Or let the next calculation trigger it
      _handleAppLaunchOrResume();
    }
  }

  void _initializeControllers() {
    if (!mounted) return;
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    _targetPercentController.text = provider.targetPercentage.toString();
    // Sync raw data controller ONLY if it's currently empty and provider has data
    // This prevents overwriting user input if they start typing before provider loads fully
    if (_rawDataController.text.isEmpty && provider.rawData.isNotEmpty) {
      _rawDataController.text = provider.rawData;
    }
  }

  void _onTargetPercentageChanged() {
    // Cancel any existing timer
    _debounceTimer?.cancel();

    // Start a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 650), () {
      // Adjust duration (e.g., 500-1000ms)
      print(
        "Debounce timer finished, updating target percentage.",
      ); // Debug print
      _updateTargetPercentage(); // Call the actual update logic after delay
    });
  }

  void _updateTargetPercentage() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final text = _targetPercentController.text;
    final newTarget = int.tryParse(text);

    if (newTarget != null && newTarget != provider.targetPercentage) {
      print("Updating Provider Target: $newTarget"); // Debug print
      provider.setTargetPercentage(newTarget);
      // setTargetPercentage now triggers calculateHours() internally if needed
    } else if (text.isEmpty && provider.targetPercentage != 0) {
      // Handle empty case if needed, maybe reset to default?
      // Or just let it be until a valid number is entered
      print("Target text empty, not updating provider yet."); // Debug print
    }
  }

  void _onProviderUpdate() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    if (!provider.isLoading && provider.result.dataParsedSuccessfully) {
      _checkScroll();
      _showMaxDropOverlayIfNeeded();

      // --- ADD INTERSTITIAL LOGIC ---
      final adProvider = Provider.of<AdProvider>(context, listen: false);
      adProvider.incrementCalculationCounter(); // Tell provider a calc happened

      if (adProvider.shouldShowInterstitial) {
        print("Showing Interstitial Ad (triggered by calculation count)");
        AdService.instance.showInterstitialAd(); // Call the service to show
      }
      // --- END INTERSTITIAL LOGIC ---
    }
    // Handle loading state or errors if needed
    else if (provider.isLoading) {
      // Maybe do something while loading
    } else if (provider.errorMessage != null) {
      // Maybe do something on error (e.g., don't show ad)
    }
  }

  void _checkScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _resultsKey.currentContext != null) {
        Scrollable.ensureVisible(
          _resultsKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _showMaxDropOverlayIfNeeded() {
    final provider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    ); // Get provider
    final bool showOverlayPref =
        _prefs?.getBool('showOverlay') ?? true; // Read preference

    if (!widget.isActive) {
      print("MaxDropOverlay skipped: HomePage is not the active tab.");
      return; // Stop right here if the page isn't visible
    }

    // Check preference AND provider's flag
    if (showOverlayPref && !provider.overlayShownThisSession) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("Showing MaxDropOverlay: Pref ON, Flag is false.");
          FocusScope.of(context).requestFocus(FocusNode());
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return MaxDropOverlay(result: provider.result);
            },
          ).then((_) {
            // if (mounted) {
            //   FocusScope.of(context).unfocus();
            // }
          });
          provider.markOverlayAsShown();
        }
      });
    } else {
      if (!showOverlayPref) {
        print("MaxDropOverlay skipped: Preference is OFF.");
      } else if (provider.overlayShownThisSession) {
        print("MaxDropOverlay skipped: Provider flag is already true.");
      }
    }
  }

  @override
  void dispose() {
    // --- Cancel timer on dispose ---
    _debounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    Provider.of<AttendanceProvider>(
      context,
      listen: false,
    ).removeListener(_onProviderUpdate);
    // --- Remove the NEW listener ---
    _targetPercentController.removeListener(_onTargetPercentageChanged);
    _targetPercentController.dispose();
    _rawDataController.dispose();
    super.dispose();
  }

  // --- Action Handlers ---
  Future<void> _handlePaste(BuildContext context) async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pastedText = clipboardData?.text;
      if (pastedText != null && pastedText.isNotEmpty) {
        _rawDataController.text = pastedText;
        provider.setRawData(pastedText, newFileName: 'Pasted from clipboard');
        showTopToast('📋 Pasted from clipboard!');
        // Close keyboard after paste
        FocusScope.of(context).unfocus();
        // Optionally hide input after paste
        if (!_showRawDataInput) setState(() => _showRawDataInput = true);
      } else {
        showTopToast('Clipboard is empty.');
      }
    } catch (e) {
      showTopToast(
        '❌ Error pasting: ${e.toString()}',
        backgroundColor: Colors.red.shade700,
      );
    }
  }

  void _handleCalculate() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    // Sync latest text from controller *before* calculating
    provider.updateRawDataWithoutCalc(_rawDataController.text);
    provider.calculateHours();
    FocusScope.of(context).unfocus(); // Hide keyboard
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        final bool hasData = provider.rawData.isNotEmpty;
        final bool canCalculate = hasData && !provider.isLoading;

        final String? currentFileName = provider.fileName;
        final String dataSourceStatus =
            currentFileName ?? (hasData ? "Pasted Data" : "No Data Loaded");

        // --- Sync Controllers ---
        if (_targetPercentController.text !=
            provider.targetPercentage.toString()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Schedule update after build
            if (mounted) {
              _targetPercentController.text = provider.targetPercentage
                  .toString();
              _targetPercentController.selection = TextSelection.fromPosition(
                TextPosition(offset: _targetPercentController.text.length),
              );
            }
          });
        }
        // Sync raw data controller (carefully)
        final bool rawDataHasFocus =
            FocusScope.of(
              context,
            ).focusedChild?.toString().contains('EditableText') ??
            false; // Basic focus check
        if (!rawDataHasFocus && _rawDataController.text != provider.rawData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Schedule update after build
            if (mounted) {
              _rawDataController.text = provider.rawData;
              _rawDataController.selection = TextSelection.fromPosition(
                TextPosition(offset: _rawDataController.text.length),
              );
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Attendance Alchemist'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(
                  themeProvider.isDarkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  // --- ADD THIS LOGIC ---
                  final adProvider = Provider.of<AdProvider>(
                    context,
                    listen: false,
                  );
                  final themeProvider = Provider.of<ThemeProvider>(
                    context,
                    listen: false,
                  ); // Use listen: false in onPressed
                  bool currentlyDark = themeProvider.isDarkMode;
                  bool tryingToTurnOn =
                      !currentlyDark; // We are trying to turn ON if it's currently OFF

                  HapticFeedback.lightImpact();

                  if (tryingToTurnOn) {
                    // Trying to turn ON Dark Mode
                    if (adProvider.isDarkThemeUnlocked) {
                      themeProvider.applyUnlockedTheme(
                        true,
                      ); // Apply immediately if unlocked
                    } else {
                      // --- TEASER EFFECT ---
                      themeProvider.toggleTheme(true); // Briefly switch to Dark

                      Future.delayed(const Duration(milliseconds: 650), () {
                        if (!mounted) return;

                        // Revert to Light Mode *only if still locked*
                        if (!Provider.of<AdProvider>(
                          context,
                          listen: false,
                        ).isDarkThemeUnlocked) {
                          themeProvider.toggleTheme(false);
                        }

                        // Show the Ad Dialog (only if still locked)
                        if (!Provider.of<AdProvider>(
                          context,
                          listen: false,
                        ).isDarkThemeUnlocked) {
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
                              themeProvider.applyUnlockedTheme(true);
                            },
                          );
                        }
                      });
                      // --- END TEASER ---
                    }
                  } else {
                    // Trying to turn OFF Dark Mode
                    themeProvider.applyUnlockedTheme(
                      false,
                    ); // Always allow turning off
                  }
                },
              ),
              if (hasData)
                IconButton(
                  icon: const Icon(
                    Icons.delete_sweep_outlined,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Clear Data',
                  onPressed: () async {
                    FocusScope.of(context).requestFocus(FocusNode());
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Clear'),
                        content: const Text(
                          'Clear current and saved attendance data?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      provider.clearData();
                      _rawDataController.clear();
                      showTopToast('🧹 Data Cleared.');
                    }
                  },
                ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            // Use a Column as the main body
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // --- Input Card ---
                        CustomCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Input Attendance Data',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _showRawDataInput
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      size: 20, // Adjust size if needed
                                      color: theme
                                          .colorScheme
                                          .secondary, // Use a distinct color
                                    ),
                                    tooltip: _showRawDataInput
                                        ? 'Hide Input Field'
                                        : 'Show Input Field',
                                    splashRadius: 20, // Smaller splash effect
                                    constraints:
                                        const BoxConstraints(), // Remove extra padding
                                    padding: const EdgeInsets.all(
                                      4,
                                    ), // Minimal padding
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => setState(
                                      () => _showRawDataInput =
                                          !_showRawDataInput,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // --- Animated Input Area ---
                              AnimatedCrossFade(
                                firstChild: _buildRawDataInput(
                                  provider,
                                ), // TextField
                                secondChild:
                                    const DropzoneWidget(), // Dropzone (Handles click internally)
                                crossFadeState: _showRawDataInput
                                    ? CrossFadeState.showFirst
                                    : CrossFadeState.showSecond,
                                duration: const Duration(milliseconds: 250),
                                layoutBuilder:
                                    (topChild, topKey, bottomChild, bottomKey) {
                                      // Smoother animation
                                      return Stack(
                                        alignment: Alignment.topCenter,
                                        children: <Widget>[
                                          Positioned(
                                            key: bottomKey,
                                            child: bottomChild,
                                          ),
                                          Positioned(
                                            key: topKey,
                                            child: topChild,
                                          ),
                                        ],
                                      );
                                    },
                              ),
                              // --- Data Source Status Text ---
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  bottom: 4.0,
                                ), // Added bottom padding too
                                child: Center(
                                  child: Text(
                                    'Source: $dataSourceStatus', // dataSourceStatus is defined earlier in build
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              // --- END Data Source Status Text ---
                              const SizedBox(height: 16),
                              // Action Button (Paste Only)
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .center, // Center the group
                                children: [
                                  // Save Button
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.save_alt_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Saves'),
                                    onPressed: provider.isLoading
                                        ? null
                                        : () {
                                            FocusScope.of(
                                              context,
                                            ).requestFocus(FocusNode());
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled:
                                                  true, // Important for keyboard interaction
                                              shape:
                                                  const RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            20,
                                                          ),
                                                        ),
                                                  ),
                                              builder: (_) =>
                                                  const SavesModal(), // Show the new modal widget
                                            );
                                          },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: theme.hintColor.withOpacity(0.5),
                                      ),
                                      foregroundColor: theme.hintColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Paste Button
                                  OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.content_paste_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Paste'),
                                    onPressed: provider.isLoading
                                        ? null
                                        : () => _handlePaste(context),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                        color: theme.hintColor.withOpacity(0.5),
                                      ),
                                      foregroundColor: theme.hintColor,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // GAUGE
                        if (!provider.isLoading &&
                            provider.errorMessage == null &&
                            provider.result.dataParsedSuccessfully &&
                            provider.result.totalConducted >
                                0) // Only show if data is valid
                          CustomCard(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Current Standing',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.hintColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 180, // Adjust height
                                  child: SfRadialGauge(
                                    axes: <RadialAxis>[
                                      RadialAxis(
                                        minimum: 0,
                                        maximum: 100,
                                        showLabels: false,
                                        showTicks: false,
                                        startAngle: 180, // Start from the left
                                        endAngle:
                                            0, // End on the right (semicircle)
                                        axisLineStyle: AxisLineStyle(
                                          thickness: 0.2, // Adjust thickness
                                          thicknessUnit: GaugeSizeUnit.factor,
                                          color: theme.disabledColor
                                              .withOpacity(0.15),
                                          // Add a subtle corner style
                                          cornerStyle: CornerStyle.bothCurve,
                                        ),
                                        pointers: <GaugePointer>[
                                          RangePointer(
                                            value: provider
                                                .result
                                                .currentPercentage
                                                .clamp(0.0, 100.0),
                                            width: 0.2, // Match axis thickness
                                            sizeUnit: GaugeSizeUnit.factor,
                                            // Use a gradient based on status
                                            gradient: SweepGradient(
                                              colors: <Color>[
                                                // Determine gradient based on whether above target
                                                provider
                                                            .result
                                                            .currentPercentage >=
                                                        provider
                                                            .targetPercentage
                                                    ? Colors.green.shade300
                                                    : Colors.red.shade300,
                                                provider
                                                            .result
                                                            .currentPercentage >=
                                                        provider
                                                            .targetPercentage
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                              ],
                                              stops: <double>[0.25, 0.75],
                                            ),
                                            cornerStyle: CornerStyle
                                                .bothCurve, // Rounded ends
                                            enableAnimation: true,
                                            animationDuration: 800,
                                            animationType:
                                                AnimationType.easeOutBack,
                                          ),
                                          // Marker for the target percentage
                                          MarkerPointer(
                                            value: provider.targetPercentage
                                                .toDouble(),
                                            markerType:
                                                MarkerType.invertedTriangle,
                                            markerHeight: 12,
                                            markerWidth: 12,
                                            color:
                                                theme.brightness ==
                                                    Brightness.dark
                                                ? Colors.white70
                                                : Colors.black54,
                                            offsetUnit: GaugeSizeUnit.factor,
                                            markerOffset:
                                                -0.05, // Position it just inside the track
                                          ),
                                        ],
                                        annotations: <GaugeAnnotation>[
                                          GaugeAnnotation(
                                            widget: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  '${provider.result.currentPercentage.toStringAsFixed(1)}%',
                                                  style: theme.textTheme.displaySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        provider
                                                                .result
                                                                .currentPercentage >=
                                                            provider
                                                                .targetPercentage
                                                        ? (theme.brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors
                                                                    .green
                                                                    .shade300
                                                              : Colors
                                                                    .green
                                                                    .shade700)
                                                        : (theme.brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors
                                                                    .red
                                                                    .shade300
                                                              : Colors
                                                                    .red
                                                                    .shade700),
                                                    height: 1.1,
                                                  ),
                                                ),
                                                Text(
                                                  'Target: ${provider.targetPercentage}%',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: theme.hintColor,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            angle: 90, // Center
                                            positionFactor:
                                                0.1, // Position below center
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),

                        // --- Target Card ---
                        CustomCard(
                          padding: const EdgeInsets.all(16),
                          child: _buildTargetInput(context, provider),
                        ),
                        const SizedBox(height: 16),

                        // --- Calculate Button ---
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: provider.isLoading
                                ? Container(
                                    width: 18,
                                    height: 18,
                                    margin: const EdgeInsets.only(right: 8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.onPrimary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.calculate_outlined,
                                    size: 18,
                                  ),
                            label: Text(
                              provider.isLoading
                                  ? 'Calculating...'
                                  : 'Calculate Attendance',
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              textStyle: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ), // Less rounded than pill
                            onPressed: canCalculate ? _handleCalculate : null,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- Loading / Error / Results ---
                        if (provider.isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.0),
                            child: Center(
                              child: Text(
                                "Processing...",
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ),
                          ),
                        if (!provider.isLoading &&
                            provider.errorMessage != null)
                          Padding(
                            /* ... Error Message Box ... */
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                border: Border.all(
                                  color: Colors.red.shade300.withOpacity(0.5),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "⚠️ Error: ${provider.errorMessage!}",
                                style: TextStyle(
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.red.shade200
                                      : Colors.red.shade800,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        // Results Section (Uses Awesome helper)
                        if (!provider.isLoading &&
                            provider.errorMessage == null &&
                            provider.result.dataParsedSuccessfully &&
                            provider.result.totalConducted > 0)
                          Column(
                            // Wrap results in Column to attach key
                            key: _resultsKey, // Assign the GlobalKey HERE
                            children: [
                              const Divider(
                                height: 24,
                                thickness: 0.5,
                              ), // Add divider above results
                              _buildResultsAwesomeSection(context, provider),
                            ],
                          ),

                        const SizedBox(height: 20), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                // Use SafeArea to avoid intrusions
                top: false, // Only apply padding to bottom/sides if needed
                child: BannerAdWidget(
                  adUnitId: AdService.instance.homeBannerAdUnitId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Helper Widgets ---

  Widget _buildRawDataInput(AttendanceProvider provider) {
    /* ... same as before ... */
    return TextField(
      controller: _rawDataController,
      maxLines: 8,
      minLines: 5,
      keyboardType: TextInputType.multiline,
      decoration: InputDecoration(
        hintText:
            'Paste or type attendance data...\n(e.g., Subject, Present, Absent OR Subject, Date, Hours, Marked)',
        hintStyle: TextStyle(
          fontSize: 13,
          color: Theme.of(context).hintColor.withOpacity(0.7),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
      onChanged: provider.updateRawDataWithoutCalc,
    );
  }

  Widget _buildTargetInput(BuildContext context, AttendanceProvider provider) {
    /* ... same as before ... */
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎯 Target Attendance',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _targetPercentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 3,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            hintText: '65',
            counterText: "",
            suffixText: '%',
            suffixStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.hintColor,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.0),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          // onChanged: (value) {
          //   /* ... immediate update logic ... */
          //   final int? newTarget = int.tryParse(value);
          //   if (newTarget != null && newTarget >= 0 && newTarget <= 100) {
          //     if (newTarget != provider.targetPercentage)
          //       provider.setTargetPercentage(newTarget);
          //   }
          // },
        ),
      ],
    );
  }

  // --- AWESOME Results Section (v3 - Integrated Message Box) ---
  Widget _buildResultsAwesomeSection(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final result = provider.result;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final target = provider.targetPercentage.toDouble();
    final currentPercent = result.currentPercentage.clamp(0.0, 100.0);
    final bool isAboveTarget = currentPercent >= target;
    final int skips = result.maxDroppableHours;
    final int required = result.requiredToAttend;
    final classesPerWeek = provider.projectionClassesPerWeek;

    // Calculate weeks context for skips
    String skipsWeeksContext = "";
    if (skips > 0 && classesPerWeek > 0 && required <= 0) {
      final weeks = (skips / classesPerWeek);
      skipsWeeksContext =
          " (~${weeks.toStringAsFixed(1)} week${weeks == 1.0 ? '' : 's'})";
    }

    // Determine Status, Colors, Icons & Message
    String statusText;
    Color statusColor;
    IconData statusIcon;
    Color gradientStart, gradientEnd;
    String statusMessage; // Dedicated message variable
    IconData messageIcon; // Dedicated message icon

    String primaryValue;
    String primaryLabel;
    IconData primaryIcon;
    String? primarySubText;

    if (required > 0) {
      // Below Target State
      statusText = "Below Target";
      statusColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
      statusIcon = Icons.warning_amber_rounded;
      gradientStart = isDarkMode ? Colors.red.shade400 : Colors.red.shade200;
      gradientEnd = isDarkMode ? Colors.red.shade800 : Colors.red.shade500;
      messageIcon = Icons.unpublished_outlined; // Use relevant icon
      statusMessage =
          'Attend ${required} more consecutive class(es) to reach ${target.toStringAsFixed(0)}%.';

      primaryValue = required.toString();
      primaryLabel = "Need to Attend";
      primaryIcon = messageIcon; // Match primary icon
      primarySubText = "consecutively";
    } else {
      // Above Target State
      primaryValue = skips.toString();
      primaryLabel = "Max Future Skips";
      primaryIcon = Icons.directions_run_outlined;
      primarySubText = skipsWeeksContext;

      if (skips < 5) {
        statusText = "Caution Zone";
        statusColor = isDarkMode
            ? Colors.orange.shade300
            : Colors.orange.shade700;
        statusIcon = Icons.error_outline_rounded;
        gradientStart = isDarkMode
            ? Colors.orange.shade400
            : Colors.orange.shade200;
        gradientEnd = isDarkMode
            ? Colors.orange.shade800
            : Colors.orange.shade500;
        messageIcon = Icons.shield_outlined; // Icon suggesting caution/buffer
        statusMessage =
            "You're close! Only ${skips} more skip${skips == 1 ? '' : 's'} allowed.";
      } else {
        statusText = "Safe!";
        statusColor = isDarkMode
            ? Colors.green.shade300
            : Colors.green.shade600;
        statusIcon = Icons.verified_user_outlined;
        gradientStart = isDarkMode
            ? Colors.green.shade400
            : Colors.green.shade200;
        gradientEnd = isDarkMode
            ? Colors.green.shade800
            : Colors.green.shade500;
        messageIcon = Icons.verified_user; // Icon suggesting safety
        statusMessage = "Plenty of buffer! You can skip ${skips} more hour(s).";
      }
    }

    // --- Card Build ---
    return Card(
      elevation: isDarkMode ? 2 : 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          /* ... Gradient background ... */
          gradient: LinearGradient(
            colors: [
              gradientStart.withOpacity(0.3),
              gradientEnd.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // --- Header with Status ---
            Container(
              /* ... Status header setup ... */
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientStart.withOpacity(0.5),
                    gradientEnd.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            // --- Main Content Padding ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
              child: Column(
                children: [
                  // --- PRIMARY METRIC DISPLAY ---
                  Icon(
                    primaryIcon,
                    size: 36,
                    color: statusColor.withOpacity(0.9),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    /* ... Primary value text ... */
                    fit: BoxFit.scaleDown,
                    child: Text(
                      primaryValue,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: statusColor.withOpacity(0.3),
                            offset: const Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    primaryLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (primarySubText != null && primarySubText.isNotEmpty)
                    Padding(
                      /* ... Subtext ... */
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        primarySubText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24), // Space after primary metric
                  // --- ** NEW INTEGRATED MESSAGE BOX ** ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(isDarkMode ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    // --- Use a Column inside the message box ---
                    child: Column(
                      children: [
                        Row(
                          // Original message row
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Align items vertically
                          children: [
                            Icon(messageIcon, color: statusColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              // Allow text to wrap
                              child: Text(
                                statusMessage,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        // --- Conditionally Add "Show Path" Button HERE ---
                        if (required > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 10.0,
                            ), // Space above button
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 16,
                              ), // Slightly smaller icon
                              label: const Text('Show Recovery Path'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme
                                    .colorScheme
                                    .secondary, // Or use statusColor
                                side: BorderSide(
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ), // Adjust padding
                                textStyle: theme
                                    .textTheme
                                    .labelMedium, // Adjust text style if needed
                                visualDensity: VisualDensity
                                    .compact, // Make button tighter
                              ),
                              onPressed: () {
                                FocusScope.of(
                                  context,
                                ).requestFocus(FocusNode());
                                showDialog(
                                  context: context,
                                  builder: (_) => PathToTargetDialog(
                                    requiredClasses: required,
                                    currentAttended: result.totalAttended,
                                    currentConducted: result.totalConducted,
                                    targetPercentage: target / 100.0,
                                    classesPerWeek:
                                        provider.projectionClassesPerWeek,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ), // --- END INTEGRATED MESSAGE BOX ---

                  const SizedBox(height: 24), // Space after message box
                  // --- Secondary Metrics Row ---
                  IntrinsicHeight(
                    child: Row(
                      /* ... Secondary metrics setup ... */
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Current %",
                            '${currentPercent.toStringAsFixed(2)}%',
                            isAboveTarget
                                ? Icons.trending_up
                                : Icons.trending_down,
                            isAboveTarget
                                ? (isDarkMode
                                      ? Colors.green.shade300
                                      : Colors.green.shade700)
                                : (isDarkMode
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 0.5),
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Attended",
                            result.totalAttended.toStringAsFixed(0),
                            Icons.how_to_reg_outlined,
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 0.5),
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Conducted",
                            result.totalConducted.toStringAsFixed(0),
                            Icons.event_available_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Progress Bar (Optional - could be removed if message box is enough) ---
                  // Keep it for now, as it provides visual context for the 'buffer'
                  if (required <= 0) ...[
                    // Use collection-if
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Text(
                          "Buffer Until Target (${target.toStringAsFixed(0)}%)",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearPercentIndicator(
                          /* ... Same setup as before ... */
                          percent:
                              ((currentPercent - target) / (100.0 - target))
                                  .clamp(0.0, 1.0),
                          lineHeight: 12.0,
                          progressColor: statusColor,
                          backgroundColor: statusColor.withOpacity(0.2),
                          barRadius: const Radius.circular(6),
                          animateFromLastPercent: true,
                          animation: true,
                          animationDuration: 800,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          /* ... Target/100% labels ... */
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${target.toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              Text(
                                '100%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper for SECONDARY metric items (Simplified from _buildMetricItem)
  Widget _buildSecondaryMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon, [
    Color? valueColor,
  ]) {
    /* ... same as before ... */
    final theme = Theme.of(context);
    final color = valueColor ?? theme.textTheme.bodyLarge?.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color?.withOpacity(0.7) ?? theme.hintColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
} // End _HomePageState
