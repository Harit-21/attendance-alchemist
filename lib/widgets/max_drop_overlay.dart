import 'dart:async';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart'; // Adjust path if needed

class MaxDropOverlay extends StatefulWidget {
  final CalculationResult result;
  const MaxDropOverlay({super.key, required this.result});
  @override
  State<MaxDropOverlay> createState() => _MaxDropOverlayState();
}

class _MaxDropOverlayState extends State<MaxDropOverlay> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _tiltAngleX =
      0.0; // Rotation around X-axis (forward/backward) in radians
  double _tiltAngleY = 0.0; // Rotation around Y-axis (left/right) in radians

  // --- Configuration ---
  final double _maxTiltDegrees =
      16.0; // Max tilt in degrees (slightly reduced for combined effect)
  final double _sensitivity = 2.5; // Adjust sensitivity
  final double _perspective = 0.0045; // Amount of perspective distortion

  Timer? _idleTimer;

  @override
  void initState() {
    super.initState();
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod:
              SensorInterval.uiInterval, // Use UI interval for smoother updates
        ).listen(
          (AccelerometerEvent event) {
            // --- Calculate Tilt for BOTH axes ---
            double rawX =
                event.x; // Left/Right motion -> Rotation around Y-axis
            double rawY =
                event.y; // Forward/Backward motion -> Rotation around X-axis

            // Map raw values (-9.8 to 9.8) to degrees (-maxTilt to +maxTilt)
            double targetDegreesY =
                (rawX / 9.8) * _maxTiltDegrees * _sensitivity;
            // Invert Y mapping: pushing top away (positive Y) should rotate *down* around X-axis (negative angle)
            double targetDegreesX =
                -(rawY / 9.8) * _maxTiltDegrees * _sensitivity;

            // Clamp the degrees
            targetDegreesX = targetDegreesX.clamp(
              -_maxTiltDegrees,
              _maxTiltDegrees,
            );
            targetDegreesY = targetDegreesY.clamp(
              -_maxTiltDegrees,
              _maxTiltDegrees,
            );

            // Convert degrees to radians
            double targetRadiansX = targetDegreesX * (pi / 180.0);
            double targetRadiansY = targetDegreesY * (pi / 180.0);

            if (mounted) {
              setState(() {
                // Apply simple low-pass filter for smoothing
                _tiltAngleX = lerpDouble(_tiltAngleX, targetRadiansX, 0.35)!;
                _tiltAngleY = lerpDouble(_tiltAngleY, targetRadiansY, 0.35)!;
              });
            }
          },
          onError: (error) {
            print("Error listening to accelerometer: $error");
            // Handle error, e.g., stop listening
            _stopListeningToSensors();
          },
          cancelOnError: true, // Stop listening on error
        );

    _idleTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_accelerometerSubscription == null) return;
      setState(() {
        // Gentle breathing motion (amplitude & speed can be tuned)
        _tiltAngleX +=
            sin(DateTime.now().millisecondsSinceEpoch * 0.002) * 0.002;
        _tiltAngleY +=
            cos(DateTime.now().millisecondsSinceEpoch * 0.002) * 0.002;
      });
    });
  }

  void _stopListeningToSensors() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  @override
  void dispose() {
    _stopListeningToSensors(); // Important: Cancel subscription
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final int maxDropValue = widget.result.maxDroppableHours;
    final int requiredClasses = widget.result.requiredToAttend;

    String messageTitle = '';
    String messageDetails = '';
    String lottieAsset = '';
    Color glowColor;
    Gradient textGradient;

    // Determine state based on results
    if (requiredClasses > 0) {
      // Danger state
      messageTitle = "No More Skips! ❌";
      messageDetails =
          'You must attend the next <strong>$requiredClasses</strong> classes consecutively to recover.';
      lottieAsset = 'assets/doomd.json'; // Replace with your Lottie file path
      glowColor = Colors.red.withOpacity(0.3);
      textGradient = LinearGradient(
        colors: [Colors.red.shade400, Colors.pink.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (maxDropValue < 5) {
      // Warning state (Adjust threshold if needed)
      messageTitle = "Heads Up ⚠️";
      messageDetails =
          'You only have <strong>$maxDropValue</strong> skip(s) left. Plan wisely.';
      lottieAsset = 'assets/warn.json'; // Replace with your Lottie file path
      glowColor = Colors.orange.withOpacity(0.3);
      textGradient = LinearGradient(
        colors: [Colors.orange.shade400, Colors.amber.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      // Success state
      messageTitle = "Great News! 🎉";
      messageDetails =
          'You can afford to miss <strong>$maxDropValue</strong> classes. Keep it up!';
      lottieAsset = 'assets/success.json'; // Replace with your Lottie file path
      glowColor = Colors.green.withOpacity(0.3);
      textGradient = LinearGradient(
        colors: [Colors.green.shade400, Colors.teal.shade600],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    // Simple HTML-like parsing for bold tags
    List<TextSpan> buildRichText(String text) {
      final List<TextSpan> spans = [];
      final RegExp regex = RegExp(r'<strong>(.*?)<\/strong>');
      int currentPos = 0;

      regex.allMatches(text).forEach((match) {
        // Add text before the match
        if (match.start > currentPos) {
          spans.add(TextSpan(text: text.substring(currentPos, match.start)));
        }
        // Add the bold text
        spans.add(
          TextSpan(
            text: match.group(1), // Content inside <strong> tags
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ), // Make numbers pop
          ),
        );
        currentPos = match.end;
      });

      // Add any remaining text after the last match
      if (currentPos < text.length) {
        spans.add(TextSpan(text: text.substring(currentPos)));
      }
      return spans;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: 5,
      backgroundColor: Colors.transparent, // Make dialog background transparent
      child: Transform(
        // Use the general Transform widget
        alignment: FractionalOffset.center, // Rotate around the center
        // --- Create a Matrix4 for 3D rotation and perspective ---
        transform: Matrix4.identity()
          ..setEntry(3, 2, _perspective) // Add perspective
          ..rotateX(_tiltAngleX) // Rotate around X-axis (forward/backward)
          ..rotateY(_tiltAngleY) // Rotate around Y-axis (left/right)
          ..scale(
            1.0 + (max((_tiltAngleX.abs() + _tiltAngleY.abs()) * 0.08, 0.0)),
          ),

        // ---
        child: Container(
          padding: const EdgeInsets.only(
            top: 20,
            bottom: 20,
            left: 20,
            right: 20,
          ),
          decoration: BoxDecoration(
            color: theme.cardColor, // Use theme card color
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(
                  0.3 +
                      ((_tiltAngleX.abs() + _tiltAngleY.abs()) * 0.3).clamp(
                        0,
                        0.7,
                      ),
                ),
                blurRadius: 20.0,
                spreadRadius: 2.0,
                offset: Offset(_tiltAngleY * 20, _tiltAngleX * 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content
            children: <Widget>[
              // Lottie Animation
              SizedBox(
                width: 100,
                height: 100,
                child: Lottie.asset(
                  lottieAsset,
                  repeat: true, // Loop animation
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.grey,
                    ); // Fallback icon
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Title with Gradient
              ShaderMask(
                shaderCallback: (bounds) => textGradient.createShader(
                  Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                ),
                child: Text(
                  messageTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    // The color must be white for ShaderMask to work
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Details Text (using RichText for bold)
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    height: 1.4, // Line spacing
                  ),
                  children: buildRichText(messageDetails),
                ),
              ),
              const SizedBox(height: 24),
              // Dismiss Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text('Got it!'),
                onPressed: () {
                  Navigator.of(context).pop(); // Close the dialog
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
