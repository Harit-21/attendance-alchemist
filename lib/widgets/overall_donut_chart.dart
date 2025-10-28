import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart'; // To access result

class OverallDonutChart extends StatelessWidget {
  final CalculationResult result;

  const OverallDonutChart({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors (ensure consistency with theme if possible)
    final Color presentColor = isDarkMode
        ? Colors.green.shade400
        : Colors.green.shade600;
    final Color odColor = isDarkMode
        ? Colors.orange.shade400
        : Colors.orange.shade600;
    final Color absentColor = isDarkMode
        ? Colors.red.shade400
        : Colors.red.shade600;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.white;

    // Calculate total for percentages if needed, but FLChart handles it
    final double totalHours = result.totalConducted;
    if (totalHours <= 0) {
      return const Center(
        child: Text("No data for chart."),
      ); // Handle no data case
    }

    // Prepare chart sections
    final List<PieChartSectionData> sections = [];
    if (result.totalPresent > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalPresent,
          title:
              '${(result.totalPresent / totalHours * 100).toStringAsFixed(0)}%',
          color: presentColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (result.totalOD > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalOD,
          title: '${(result.totalOD / totalHours * 100).toStringAsFixed(0)}%',
          color: odColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (result.totalAbsent > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalAbsent,
          title:
              '${(result.totalAbsent / totalHours * 100).toStringAsFixed(0)}%',
          color: absentColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200, // Height for the chart itself
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50, // Creates the donut hole
              sectionsSpace: 2, // Space between sections
              // Optional: Animate the chart appearance
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  // Optional: Handle touch events here (e.g., highlighting sections)
                },
              ),
              startDegreeOffset: -90, // Start from the top
            ),
            swapAnimationDuration: const Duration(
              milliseconds: 250,
            ), // Optional animation
            swapAnimationCurve: Curves.linear,
          ),
        ),
        const SizedBox(height: 16),
        // --- Legend ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            // Use Wrap for better responsiveness
            spacing: 16.0, // Horizontal space between items
            runSpacing: 8.0, // Vertical space between lines
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(
                color: presentColor,
                text: 'Present (${result.totalPresent.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
              _buildLegendItem(
                color: odColor,
                text: 'OD (${result.totalOD.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
              _buildLegendItem(
                color: absentColor,
                text: 'Absent (${result.totalAbsent.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper widget for legend items
  Widget _buildLegendItem({
    required Color color,
    required String text,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min, // Keep items compact
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}
