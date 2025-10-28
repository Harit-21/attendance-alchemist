import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';

class PathToTargetDialog extends StatefulWidget {
  final int requiredClasses;
  final double currentAttended;
  final double currentConducted;
  final double targetPercentage;
  final int classesPerWeek;

  const PathToTargetDialog({
    super.key,
    required this.requiredClasses,
    required this.currentAttended,
    required this.currentConducted,
    required this.targetPercentage,
    required this.classesPerWeek,
  });

  @override
  State<PathToTargetDialog> createState() => _PathToTargetDialogState();
}

class _PathToTargetDialogState extends State<PathToTargetDialog> {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _tiltAngleX = 0.0;
  double _tiltAngleY = 0.0;
  final double _maxTiltDegrees = 10.0;
  final double _sensitivity = 1.1;
  final double _perspective = 0.001;

  @override
  void initState() {
    super.initState();
    _startListeningToSensors();
  }

  void _startListeningToSensors() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen(
          (AccelerometerEvent event) {
            double rawX = event.x;
            double rawY = event.y;
            double targetDegreesY =
                (rawX / 9.8) * _maxTiltDegrees * _sensitivity;
            double targetDegreesX =
                -(rawY / 9.8) * _maxTiltDegrees * _sensitivity;
            targetDegreesX = targetDegreesX.clamp(
              -_maxTiltDegrees,
              _maxTiltDegrees,
            );
            targetDegreesY = targetDegreesY.clamp(
              -_maxTiltDegrees,
              _maxTiltDegrees,
            );
            double targetRadiansX = targetDegreesX * (pi / 180.0);
            double targetRadiansY = targetDegreesY * (pi / 180.0);

            if (mounted) {
              setState(() {
                _tiltAngleX =
                    (_tiltAngleX * 0.8) +
                    (targetRadiansX * 0.2); // Slightly faster smoothing
                _tiltAngleY = (_tiltAngleY * 0.8) + (targetRadiansY * 0.2);
              });
            }
          },
          onError: (e) {
            print("Sensor Error: $e");
            _stopListeningToSensors();
          },
          cancelOnError: true,
        );
  }

  void _stopListeningToSensors() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  @override
  void dispose() {
    _stopListeningToSensors();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    int balancedAttend =
        widget.requiredClasses + 10; // Attend required + 10 buffer
    double newAttended = widget.currentAttended + balancedAttend;
    double newConducted = widget.currentConducted + balancedAttend;
    int allowedSkipsAfterBalanced = 0;
    if (widget.targetPercentage > 0 && widget.targetPercentage < 1) {
      final numerator = newAttended - (widget.targetPercentage * newConducted);
      allowedSkipsAfterBalanced = (numerator / widget.targetPercentage).floor();
      if (allowedSkipsAfterBalanced < 0)
        allowedSkipsAfterBalanced = 0; // Ensure non-negative
    }

    String paceSuggestion = "";
    if (widget.classesPerWeek > 0 && widget.requiredClasses > 0) {
      double weeksNeeded = widget.requiredClasses / widget.classesPerWeek;
      paceSuggestion =
          "(Approx. ${weeksNeeded.toStringAsFixed(1)} weeks at your current average)";
    }
    // Calendar Info
    final String eventTitle =
        'ATTENDANCE RECOVERY (${widget.requiredClasses} classes)';
    final String eventDesc =
        'Prioritize attending the next ${widget.requiredClasses} classes consecutively to meet your target attendance. Stay focused!';
    final DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
    final String suggestedDate =
        "${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}";
    final String calendarInfo =
        "Title: $eventTitle\nDate: Tomorrow ($suggestedDate)\nDescription: $eventDesc";

    // Build RichText for bold numbers
    List<TextSpan> buildRichPathText(
      String text,
      int value, {
      Color? valueColor,
    }) {
      // Added {Color? valueColor}
      final parts = text.split('{value}');
      return [
        TextSpan(text: parts[0]),
        TextSpan(
          text: value.toString(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * 1.15,
            // Use the passed valueColor or default to primary
            color: valueColor ?? theme.colorScheme.primary,
          ),
        ),
        if (parts.length > 1) TextSpan(text: parts[1]),
      ];
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: SizedBox(
        // Make it, for example, 90% of screen width, up to a max
        width: min(
          screenWidth * 0.9,
          495,
        ), // Adjust 0.9 (90%) and 450 (max width) as needed
        child: Transform(
          // Apply 3D tilt
          alignment: FractionalOffset.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, _perspective)
            ..rotateX(_tiltAngleX)
            ..rotateY(_tiltAngleY),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 20.0,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  blurRadius: 15.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🗺️ Your Path to Target',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // --- Option 1 Card ---
                  _buildPathOptionCard(
                    context: context,
                    icon: Icons.rocket_launch_outlined,
                    title: "Option 1: Express Lane",
                    descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    descriptionSpans: [
                      ...buildRichPathText(
                        'Attend the next {value} classes consecutively.',
                        widget.requiredClasses,
                        valueColor: Colors.red.shade600,
                      ),
                      // Add pace suggestion here
                      if (paceSuggestion.isNotEmpty)
                        TextSpan(
                          text: "\n$paceSuggestion",
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: theme.hintColor,
                          ),
                        ),
                    ],
                    tagText: "Fastest Recovery",
                    tagColor: Colors.red.shade100,
                    tagTextColor: Colors.red.shade800,
                    iconColor: Colors.red.shade600,
                    actionButton: TextButton.icon(
                      icon: const Icon(Icons.calendar_month_outlined, size: 16),
                      label: const Text("Copy Reminder Info"),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        textStyle: theme.textTheme.labelSmall,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: calendarInfo),
                        );
                        showTopToast(
                          '📋 Reminder details copied! Paste into your calendar app.',
                          backgroundColor: Colors.blue.shade600.withOpacity(
                            0.9,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (allowedSkipsAfterBalanced >=
                      0) // Only show if calculation is valid
                    _buildPathOptionCard(
                      context: context,
                      icon: Icons.shield_outlined,
                      title: "Option 2: Balanced Buffer",
                      descriptionStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      descriptionSpans: [
                        ...buildRichPathText(
                          'Attend the next {value} classes, ',
                          balancedAttend,
                        ),
                        ...buildRichPathText(
                          'then you can skip {value} later.',
                          allowedSkipsAfterBalanced,
                          valueColor: Colors.green.shade700,
                        ), // Highlight skips in green
                      ],
                      tagText: "Builds Safety Net",
                      tagColor: Colors.green.shade100,
                      tagTextColor: Colors.green.shade800,
                      iconColor: Colors.green.shade700,
                    ),
                  const SizedBox(height: 16), // Space before motivational tip
                  // --- Motivational Tip ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Stay consistent! Each class attended brings you closer.",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Okay, Plan Acquired!'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widget for Path Option Cards ---
  Widget _buildPathOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required List<TextSpan> descriptionSpans,
    required TextStyle? descriptionStyle,
    required String tagText,
    required Color tagColor,
    required Color tagTextColor,
    required Color iconColor,
    Widget? actionButton,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
      decoration: BoxDecoration(
        border: Border.all(color: iconColor.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12.0),
        color: theme.brightness == Brightness.dark
            ? iconColor.withOpacity(0.1)
            : tagColor.withOpacity(0.5), // Use tag color lightly for background
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            // text: TextSpan(style: descriptionStyle, children: descriptionSpans),
            text: TextSpan(
              style: descriptionStyle?.copyWith(fontSize: 13.5),
              children: descriptionSpans,
            ),
          ),
          if (actionButton != null)
            Padding(
              padding: const EdgeInsets.only(top: 10.0), // Space above button
              child: actionButton,
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Chip(
              label: Text(tagText),
              labelStyle: TextStyle(
                fontSize: 10,
                color: tagTextColor,
                fontWeight: FontWeight.w500,
              ),
              backgroundColor: tagColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              side: BorderSide.none,
            ),
          ),
        ],
      ),
    );
  }
} // End State
