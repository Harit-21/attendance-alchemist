// lib/widgets/subject_bar_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart'; // To access models
import 'package:collection/collection.dart'; // For mapIndexed

class SubjectBarChart extends StatelessWidget {
  final Map<String, SubjectStatsDetailed> subjectStats;
  final double targetPercentage;

  const SubjectBarChart({
    super.key,
    required this.subjectStats,
    required this.targetPercentage,
  });

  // Helper to format/abbreviate subject names for axis labels
  // (You can adjust maxLength, maxWordsForAbbr, abbrMaxLength based on testing)
  String _formatSubjectNameForAxis(
    String fullName, {
    int maxLength = 10,
    int maxWordsForAbbr = 4,
    int abbrMaxLength = 5,
  }) {
    if (fullName.length <= maxLength) return fullName;

    // Try abbreviation
    var words = fullName.split(RegExp(r'\s+')); // Split by any whitespace
    if (words.length > 1 && words.length <= maxWordsForAbbr) {
      var abbr = words.map((w) => w.isNotEmpty ? w[0] : '').join('');
      // Use abbreviation only if significantly shorter and reasonable length
      if (abbr.length > 1 &&
          abbr.length < fullName.length / 1.5 &&
          abbr.length <= abbrMaxLength) {
        return abbr.toUpperCase();
      }
    }
    // Fallback to truncation
    return '${fullName.substring(0, maxLength - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sortedEntries = subjectStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    // Define colors using theme for better adaptability
    final Color belowTargetColor = theme.colorScheme.error.withOpacity(
      0.85,
    ); // Use theme error color
    final Color aboveTargetColor =
        (isDarkMode ? Colors.green.shade300 : Colors.green.shade600)
            .withOpacity(0.9); // Keep green distinct
    final Color gridColor = theme.dividerColor.withOpacity(
      0.3,
    ); // Use divider color for grid
    final Color textColor =
        theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;
    final Color targetLineColor = Colors.blueAccent.shade100;
    final Color tooltipBg = isDarkMode
        ? Colors.grey.shade800.withOpacity(0.9)
        : Colors.white.withOpacity(0.9);
    final Color tooltipText = isDarkMode ? Colors.white : Colors.black87;
    final Color backgroundRodColor = theme.scaffoldBackgroundColor.withOpacity(
      isDarkMode ? 0.6 : 0.8,
    ); // Subtle background bar

    // Gradient function for bars
    LinearGradient _barGradient(Color baseColor) {
      return LinearGradient(
        colors: [
          baseColor.withOpacity(0.7),
          baseColor,
        ], // Fade slightly top to bottom
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    // Determine if labels should be angled
    final bool angleLabels =
        sortedEntries.length > 7; // Angle if more than 7 subjects

    return Padding(
      // Adjust padding around the chart area
      padding: const EdgeInsets.only(
        top: 16.0,
        right: 16.0,
        bottom: 8.0,
        left: 8.0,
      ),
      child: BarChart(
        // Animation properties
        swapAnimationDuration: const Duration(
          milliseconds: 500,
        ), // Slightly longer animation
        swapAnimationCurve: Curves.easeInOutCubic, // Smoother curve
        // --- BarChartData ---
        BarChartData(
          alignment: BarChartAlignment.spaceAround, // Distribute bars evenly
          maxY: 105, // Y-axis slightly above 100%
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false, // Hide vertical lines
            horizontalInterval: 25, // Grid lines every 25%
            // Style horizontal grid lines
            getDrawingHorizontalLine: (value) =>
                FlLine(color: gridColor, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false), // Hide outer chart border
          titlesData: FlTitlesData(
            show: true,
            // --- Bottom Titles (Subject Names) ---
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: angleLabels ? 45 : 35, // More space if angled
                interval: 1, // Title for every bar
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedEntries.length) {
                    final name = _formatSubjectNameForAxis(
                      sortedEntries[index].key,
                    );
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6, // Space from axis
                      angle: angleLabels
                          ? -0.785
                          : 0, // Approx 45 degrees if angled (radians)
                      child: Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            // --- Left Titles (Percentage) ---
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35, // Space for labels like "100%"
                interval: 25, // Labels every 25%
                getTitlesWidget: (value, meta) {
                  // Only show major percentage labels
                  if (value == 0 ||
                      value == 25 ||
                      value == 50 ||
                      value == 75 ||
                      value == 100) {
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(color: textColor, fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            // Hide Top and Right Titles
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          // --- Bar Data ---
          barGroups: sortedEntries.mapIndexed((index, entry) {
            final stats = entry.value; // Access SubjectStatsDetailed
            final percentage = stats.percentage.clamp(
              0.0,
              100.0,
            ); // Use percentage from stats
            final color = percentage < targetPercentage
                ? belowTargetColor
                : aboveTargetColor;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: percentage,
                  gradient: _barGradient(color), // Apply gradient
                  width: 18, // Slightly wider bars
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ), // Rounded top corners
                  // Background rod for context
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100, // Background goes up to 100%
                    color: backgroundRodColor,
                  ),
                ),
              ],
            );
          }).toList(),
          // --- Target Line ---
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetPercentage,
                color: targetLineColor,
                strokeWidth: 2, // Slightly thicker line
                dashArray: [6, 4], // Adjust dash pattern
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight, // Position label better
                  padding: const EdgeInsets.only(
                    right: 5,
                    top: 2,
                  ), // Adjust padding
                  style: TextStyle(
                    color: targetLineColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (line) => 'Target', // Label for the line
                ),
              ),
            ],
          ),
          // --- Tooltip ---
          barTouchData: BarTouchData(
            enabled: true, // Enable touch interactions
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ), // More vertical padding
              tooltipMargin: 10, // Margin from bar
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final subjectName = sortedEntries[group.x.toInt()]
                    .key; // Use full name for tooltip
                final percentage = rod.toY;
                final statusColor = percentage < targetPercentage
                    ? belowTargetColor
                    : aboveTargetColor;
                return BarTooltipItem(
                  '$subjectName\n', // Subject name on first line
                  TextStyle(
                    color: tooltipText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.4,
                  ), // Larger font
                  children: [
                    // Percentage on second line
                    TextSpan(
                      text: '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ), // Larger font
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
