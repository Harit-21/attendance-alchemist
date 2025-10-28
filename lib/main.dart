import 'dart:io'; // Needed for Platform check in AdService if used directly here (though unlikely)
import 'package:flutter/foundation.dart'; // Import for kDebugMode
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import Ad SDK
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:hive_flutter/hive_flutter.dart';
// Providers
import 'package:attendance_alchemist/providers/ad_provider.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/providers/settings_provider.dart';
import 'package:attendance_alchemist/providers/theme_provider.dart';

// Screens
import 'package:attendance_alchemist/screens/main_screen.dart';

// Services
import 'package:attendance_alchemist/services/ad_service.dart';
import 'package:attendance_alchemist/services/attendance_calculator.dart'; // Needed for background task types
import 'package:attendance_alchemist/services/hive_service.dart';
import 'package:attendance_alchemist/services/notification_service.dart';
import 'package:attendance_alchemist/services/remote_config_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:attendance_alchemist/firebase_options.dart';
import 'package:attendance_alchemist/screens/splash_screen.dart';

// Models (if needed by background task)
import 'package:attendance_alchemist/models/schedule_entry.dart';

// --- Background Task ---
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == "dailyAttendanceCheck") {
      print("--- Background Task: dailyAttendanceCheck running ---");
      try {
        // --- Initialize services (MANDATORY in background) ---
        final appDocumentDir = await getApplicationDocumentsDirectory();
        await HiveService.init(
          appDocumentDir.path,
        ); // Ensure HiveService handles potential re-init
        await NotificationService.init(); // Ensure NotificationService handles potential re-init
        await NotificationService.showNotification(
          id: 99,
          title: "Background Task Started",
          body: "Task is running!",
        );

        // --- Load Data ---
        final prefs = await SharedPreferences.getInstance();
        final schedule =
            HiveService.getSchedule(); // Assuming HiveService is now safe to use
        final rawData = prefs.getString('lastRawData');
        final target = prefs.getInt('lastTargetPercentage');

        // --- Check for classes today ---
        final today = DateTime.now().weekday;
        final todayHasClasses = schedule.any((e) => e.dayOfWeek == today);

        if (!todayHasClasses) {
          print("--- Background Task: No classes today. Exiting. ---");
          await Hive.close();
          return Future.value(true);
        }

        // --- Run Calculation ---
        if (rawData == null || rawData.isEmpty || target == null) {
          print(
            "--- Background Task: No data/target found in SharedPreferences. Exiting. ---",
          );
          await Hive.close();
          return Future.value(true);
        }

        final input = ComputeInput(rawData: rawData, targetPercentage: target);
        final CalculationOutput output = performCalculation(
          input,
        ); // Runs synchronously here

        // --- Decision Logic & Notification ---
        if (output.result.dataParsedSuccessfully) {
          final int buffer = output.result.maxDroppableHours;
          final int required =
              output.result.requiredToAttend; // Get required classes

          if (required > 0) {
            // BELOW TARGET
            await NotificationService.showNotification(
              id: 1,
              title: '🚨 Attendance Alert!',
              body:
                  "Danger Zone! You need to attend ~$required classes consecutively. Attending today is crucial.",
            );
          } else if (buffer <= 2) {
            // DANGER ZONE (but above target)
            await NotificationService.showNotification(
              id: 1,
              title: '🚨 Attendance Alert!',
              body:
                  "Heads up! You only have $buffer skip(s) left and you have classes today. Attending is highly recommended.",
            );
          } else if (buffer <= 5) {
            // CAUTION ZONE
            await NotificationService.showNotification(
              id: 1,
              title: '⚠️ Attendance Check',
              body:
                  "You're in the Caution Zone with $buffer skip(s) left. Don't forget about class today!",
            );
          } else {
            print(
              "--- Background Task: User is in Safe Zone ($buffer skips). No notification sent. ---",
            );
          }
        } else {
          print(
            "--- Background Task: Calculation failed. ${output.errorMessage} ---",
          );
        }

        print("--- Background Task: Finished successfully ---");
        await Hive.close();
        return Future.value(true);
      } catch (e, stacktrace) {
        print("--- Background Task: FAILED ---");
        print(e.toString());
        print(stacktrace.toString());
        await Hive.close(); // Attempt close on error
        return Future.value(false); // Task failed
      }
    }
    return Future.value(false);
  });
}
// --- End Background Task ---

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- Initialize Remote Config SECOND ---
  await RemoteConfigService.instance.init();

  await MobileAds.instance.initialize();

  final appDocumentDir = await getApplicationDocumentsDirectory();
  await HiveService.init(appDocumentDir.path);
  await NotificationService.init();
  await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);

  final prefs = await SharedPreferences.getInstance();

  AdService.instance.createInterstitialAd();
  AdService.instance.createRewardedAd();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RemoteConfigService.instance),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs: prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs: prefs)),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => AdProvider()),
      ],
      child: const AttendanceAlchemistApp(),
    ),
  );
}

class AttendanceAlchemistApp extends StatelessWidget {
  const AttendanceAlchemistApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch ThemeProvider here to get themeMode for MaterialApp
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Define themes (could be moved to a separate file)
    final ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB), // bg-gray-50
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Or Color(0xFFF9FAFB)
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.black54), // Subtle icons
        actionsIconTheme: IconThemeData(color: Colors.black54),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white, // Clearer distinction
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        elevation: 4.0, // Standard elevation
        type: BottomNavigationBarType.fixed, // Ensure all items are visible
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        surfaceTintColor: Colors.transparent, // Prevent M3 tinting
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
        margin: EdgeInsets.zero, // Default margin for consistency
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          // Add other styles like background, foreground if needed
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );

    final ThemeData darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.blue, // Keep seed consistent
      scaffoldBackgroundColor: const Color(0xFF0D1117), // Darker background
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent, // Or Color(0xFF0D1117)
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white70), // Brighter icons
        actionsIconTheme: IconThemeData(color: Colors.white70),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(
          0xFF161B22,
        ), // Slightly lighter than scaffold
        selectedItemColor: Colors.blue.shade300,
        unselectedItemColor: Colors.grey.shade500,
        elevation: 4.0,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        elevation: 0, // Flat design in dark mode often looks better
        color: Colors.white.withOpacity(0.05), // Subtle card color
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.white.withOpacity(0.15), width: 0.8),
        ),
        margin: EdgeInsets.zero,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          // Define selected/unselected colors for dark mode
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withOpacity(0.04), // Darker fill
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );

    return MaterialApp(
      title: 'Attendance Alchemist',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode, // Controlled by ThemeProvider
      theme: lightTheme, // Pass the defined light theme
      darkTheme: darkTheme, // Pass the defined dark theme
      // --- ADD THE BUILDER FOR ANIMATED THEME ---
      builder: (context, child) {
        // Get the ThemeData that MaterialApp decided to apply
        final currentActualTheme = Theme.of(context);

        return AnimatedTheme(
          data: currentActualTheme,
          duration: const Duration(milliseconds: 74), // Adjust as needed
          curve: Curves.easeInOut, // Optional: Add an animation curve
          child: child!, // Apply animation to the rest of the app
        );
      },

      // --- End of builder ---
      home: const SplashScreen(),
      // home: const MainScreen(),
    );
    // Remove the Consumer wrapper from here as it's not needed now
    // }, // End Consumer builder
    // ); // End Consumer
  }
}
