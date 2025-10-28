import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/providers/settings_provider.dart';
import 'package:attendance_alchemist/providers/theme_provider.dart';

// --- Imports for Pages and Toast ---
import 'package:attendance_alchemist/screens/home_page.dart';
import 'package:attendance_alchemist/screens/analysis_page.dart';
import 'package:attendance_alchemist/screens/planner_page.dart';
import 'package:attendance_alchemist/screens/settings_page.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool _launchActionCompleted = false;

  final GlobalKey<HomePageState> _homeKey = GlobalKey<HomePageState>();
  final GlobalKey<AnalysisPageState> _analysisKey =
      GlobalKey<AnalysisPageState>();
  final GlobalKey<PlannerPageState> _plannerKey = GlobalKey<PlannerPageState>();
  final GlobalKey<SettingsPageState> _settingsKey =
      GlobalKey<SettingsPageState>();

  // --- UPDATE THIS LIST (and use IndexedStack) ---

  // --- NEW: List of pages (no longer static) ---
  // late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // --- NEW: Initialize pages with their keys ---
    // _pages = [
    //   HomePage(key: _homeKey),
    //   AnalysisPage(key: _analysisKey),
    //   PlannerPage(key: _plannerKey),
    //   SettingsPage(key: _settingsKey), // Use the key for settings too
    // ];
    // ---
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initAndPerformLaunchAction();
    });
  }

  // (This function remains the same)
  Future<void> _initAndPerformLaunchAction() async {
    if (_launchActionCompleted || !mounted) return;
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    await settingsProvider.initializationComplete;
    if (!mounted) return;
    await _performLaunchAction();
    _launchActionCompleted = true;
  }

  // (This function remains the same, but now `showTopToast` will work)
  Future<void> _performLaunchAction() async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final attendanceProvider = Provider.of<AttendanceProvider>(
      context,
      listen: false,
    );
    debugPrint(
      "Attempting Launch Action based on Setting: ${settingsProvider.launchOption}",
    );

    switch (settingsProvider.launchOption) {
      case AppLaunchOption.resume:
        debugPrint("Launch Action: Resuming last save...");
        bool loaded = await attendanceProvider.loadSavedData();
        if (!loaded && mounted) {
          showTopToast(
            // This will now work
            '⚠️ No saved data found to resume.',
            backgroundColor: Colors.orange.shade700,
          );
        }
        break;
      case AppLaunchOption.clipboard:
        debugPrint("Launch Action: Pasting from clipboard...");
        ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty && mounted) {
          attendanceProvider.setRawData(
            data.text!,
            newFileName: "Pasted from Clipboard",
          );
        } else if (mounted) {
          showTopToast(
            // This will now work
            '⚠️ Clipboard is empty or contains no text.',
            backgroundColor: Colors.orange.shade700,
          );
        }
        break;
      case AppLaunchOption.none:
      default:
        debugPrint("Launch Action: Doing nothing.");
        break;
    }
  }

  // --- MODIFIED: Handles both navigation and tap-to-top ---
  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // Tapped the same icon
      HapticFeedback.mediumImpact();
      switch (index) {
        case 0: // Home
          _homeKey.currentState?.scrollToTop();
          break;
        case 1: // Analysis
          _analysisKey.currentState?.scrollToTop();
          break;
        case 2: // Planner
          _plannerKey.currentState?.scrollToTop();
          break;
        case 3: // Settings
          _settingsKey.currentState?.scrollToTop();
          break;
      }
    } else {
      // Tapped a new icon
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final List<Widget> pages = [
      HomePage(
        key: _homeKey,
        isActive: _selectedIndex == 0,
      ),
      AnalysisPage(key: _analysisKey),
      PlannerPage(key: _plannerKey),
      SettingsPage(key: _settingsKey),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      // ---
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_outlined),
            activeIcon: Icon(Icons.analytics),
            label: 'Analysis',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit_calendar_outlined),
            activeIcon: Icon(Icons.edit_calendar),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Your existing type
        onTap: _onItemTapped, // Points to our new function
        // --- Add your existing styling here ---
        // (e.g., selectedItemColor, unselectedItemColor, etc.)
      ),
    );
  }
}
