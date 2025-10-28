import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:attendance_alchemist/screens/main_screen.dart'; // Import your main screen

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationFinished = false;
  bool _minimumTimePassed = false;

  // Adjust duration as needed (e.g., 2-3 seconds total)
  final int _minSplashTimeMs = 2000; // Minimum time splash is visible
  final int _lottieDurationMs = 1500; // Expected duration of Lottie animation

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _lottieDurationMs),
    );

    // Start minimum display timer
    Timer(Duration(milliseconds: _minSplashTimeMs), () {
      _minimumTimePassed = true;
      _navigateToHome();
    });

    // _controller.addStatusListener((status) {
    //   if (status == AnimationStatus.completed) {
    //     _animationFinished = true;
    //     _navigateToHome();
    //   }
    // });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    // Navigate only if BOTH animation is done (or controller ready) AND minimum time passed
    if (_minimumTimePassed && mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainScreen(),
          transitionDuration: const Duration(
            milliseconds: 600,
          ), // Adjust fade duration
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current theme brightness for potential color adjustments
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      // Use Scaffold for background color matching theme
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Your Lottie Animation ---
            Lottie.asset(
              'assets/animations/splash_animation.json', // Your animation file
              controller: _controller,
              height: 200, // Adjust size
              width: 200, // Adjust size
              repeat: true,
              onLoaded: (composition) {
                // Configure the AnimationController with the Lottie file's duration
                // Ensure controller duration matches Lottie duration
                _controller
                  ..duration = composition.duration
                  ..forward(); // Start animation when loaded
              },
              // Optional: Handle errors if animation fails to load
              errorBuilder: (context, error, stackTrace) {
                print("Error loading Lottie animation: $error");
                // Fallback: Show logo or simple indicator if animation fails
                // Make sure you have your logo asset declared
                // return Image.asset('assets/icon/icon.png', height: 150);
                _animationFinished =
                    true; // Mark as finished to allow navigation
                _navigateToHome(); // Try navigating even if animation fails
                return const SizedBox(height: 200); // Placeholder size
              },
            ),
            // const SizedBox(height: 20),
            // // --- Optional: App Name ---
            // Text(
            //   'Attendance Alchemist',
            //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            //     fontWeight: FontWeight.bold,
            //     color: Theme.of(context).colorScheme.primary,
            //   ),
            // ),
            // const SizedBox(height: 80), // Space at the bottom
          ],
        ),
      ),
    );
  }
}
