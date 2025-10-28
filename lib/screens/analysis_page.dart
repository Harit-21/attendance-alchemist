import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:fl_chart/fl_chart.dart'; // For Trend Analysis Chart
import 'package:percent_indicator/percent_indicator.dart';
import 'package:collection/collection.dart'; // For groupBy and sortedBy
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/widgets/custom_card.dart'; // Keep CustomCard for flexibility
import 'package:attendance_alchemist/widgets/subject_bar_chart.dart';
import 'package:attendance_alchemist/widgets/overall_donut_chart.dart';
import 'package:attendance_alchemist/mixins/scroll_to_top_mixin.dart';
import 'package:attendance_alchemist/providers/ad_provider.dart';
import 'package:attendance_alchemist/helpers/ad_helper.dart';
import 'package:attendance_alchemist/widgets/banner_ad_widget.dart';
import 'package:attendance_alchemist/services/ad_service.dart';
import 'dart:math';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => AnalysisPageState();
}

class AnalysisPageState extends State<AnalysisPage> with ScrollToTopMixin {
  bool _showSubjectTable = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _showRewardedAdDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onReward,
  }) {
    FocusScope.of(context).requestFocus(FocusNode());
    showRewardedAdDialog(
      context: context,
      title: title,
      content: content,
      onReward: onReward,
    );
  }

  @override
  Widget build(BuildContext context) {
    final adProvider = Provider.of<AdProvider>(context);
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final results = provider.result;
        final bool hasData =
            results.dataParsedSuccessfully && results.subjectStats.isNotEmpty;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('📊 Attendance Analysis'),
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor,
            foregroundColor: theme.textTheme.titleLarge?.color,
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasData
                    ? _buildAnalysisContent(context, provider, theme)
                    : _buildPlaceholder(context, theme, provider.errorMessage),
              ),
              SafeArea(
                top: false,
                child: BannerAdWidget(
                  adUnitId: AdService.instance.analysisBannerAdUnitId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    ThemeData theme,
    String? errorMessage,
  ) {
    String title = 'No Data Analyzed';
    String message =
        'Go to the Home page, input your data, and calculate first to unlock the analysis!';
    IconData icon = Icons.analytics_outlined;
    Color iconColor = Colors.grey[400]!;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      title = 'Analysis Unavailable';
      message =
          'Error: $errorMessage\nPlease check your data format on the Home page.';
      icon = Icons.error_outline;
      iconColor = theme.colorScheme.error; // Use theme color
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Analysis Content --- (Enhanced and Reordered)
  Widget _buildAnalysisContent(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final sortedSubjects = provider.result.subjectStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final bool canShowTrend = provider.result.subjectStats.values.any(
      (s) => s.absences.isNotEmpty,
    );

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. Smart Advisor ---
          _buildSmartAdvisorSection(context, provider, theme),
          const SizedBox(height: 20),

          // --- 2. Trend Analysis ---
          _buildTrendAnalysisSection(context, provider, theme, canShowTrend),
          const SizedBox(height: 20),

          // --- 3. Subject Breakdown (Awesome List) ---
          Row(
            // Title and Toggle Button
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment:
                CrossAxisAlignment.center, // Align items vertically
            children: [
              // *** Wrap Title in Expanded ***
              Expanded(
                child: Text(
                  '📚 Subject Breakdown',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow:
                      TextOverflow.ellipsis, // Prevent title text overflow
                  maxLines: 1,
                ),
              ),
              const SizedBox(
                width: 8,
              ), // Add some space between title and button
              // Toggle Button (Keep it sized intrinsically)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.list_alt_rounded, size: 18),
                    label: Text("List"),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.table_chart_outlined, size: 18),
                    label: Text("Table"),
                  ),
                ],
                selected: {_showSubjectTable},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() {
                    _showSubjectTable = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity
                      .compact, // Make button slightly smaller vertically
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                  ), // Adjust padding if needed
                  textStyle: theme.textTheme.labelSmall,
                ),
                showSelectedIcon: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Conditional View based on _showSubjectTable
          AnimatedCrossFade(
            firstChild: _buildSubjectList(
              context,
              provider,
              theme,
              sortedSubjects,
            ),
            secondChild: _buildSubjectDataTable(
              context,
              provider,
              theme,
              sortedSubjects,
            ),
            crossFadeState: _showSubjectTable
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 24),

          // --- Subject Bar Chart (Enhanced Card) ---
          _buildSectionCard(
            context: context,
            title: '📊 Comparison Chart',
            gradient: LinearGradient(
              // Add gradient to card background
              colors: [
                theme.colorScheme.primary.withOpacity(0.05),
                theme.colorScheme.surface.withOpacity(
                  0.0,
                ), // Fade to transparent/surface
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16), // Custom padding
            child: SizedBox(
              height:
                  (sortedSubjects.length * 35.0 +
                          60) // 1. Reduced multiplier from 40 to 35
                      .clamp(160.0, 350.0),
              child: SubjectBarChart(
                subjectStats: provider.result.subjectStats,
                targetPercentage: provider.targetPercentage.toDouble(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // --- 5. Overall Donut Chart ---
          _buildSectionCard(
            context: context,
            title: '🍩 Overall Breakdown',
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: OverallDonutChart(result: provider.result),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Helper: Section Card Wrapper --- (Adds Title/Divider to CustomCard)
  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(16.0),
    Gradient? gradient, // Optional Gradient
  }) {
    final theme = Theme.of(context);
    return CustomCard(
      padding: EdgeInsets.zero,
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          if (padding != null)
            Padding(padding: padding, child: child)
          else
            child,
        ],
      ),
    );
  }

  // --- Helper: Build Subject List View ---
  Widget _buildSubjectList(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    List<MapEntry<String, SubjectStatsDetailed>> sortedSubjects,
  ) {
    return Column(
      // Use mapIndexed for consistent key generation if needed, but simple map is fine here
      children: sortedSubjects
          .mapIndexed(
            (index, entry) => Padding(
              padding: EdgeInsets.only(
                bottom: index == sortedSubjects.length - 1 ? 0 : 10,
              ),
              child: _buildSubjectAnalysisItem(
                context,
                entry.key,
                entry.value,
                provider.targetPercentage.toDouble(),
                theme,
              ),
            ),
          )
          .toList(),
    );
  }

  // --- NEW Helper: Build Subject Data Table View ---
  Widget _buildSubjectDataTable(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    List<MapEntry<String, SubjectStatsDetailed>> sortedSubjects,
  ) {
    return CustomCard(
      // Wrap table in a card for consistency
      padding: EdgeInsets.zero, // DataTable handles internal padding
      child: SingleChildScrollView(
        // Allow horizontal scrolling
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 40, // Adjust heading height
          dataRowMinHeight: 48, // Minimum row height
          dataRowMaxHeight: 52, // Maximum row height
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.primary.withOpacity(0.1),
          ),
          headingTextStyle: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          columns: const [
            DataColumn(label: Text('Subject')),
            DataColumn(label: Text('Att'), numeric: true, tooltip: "Attended"),
            DataColumn(label: Text('Con'), numeric: true, tooltip: "Conducted"),
            DataColumn(label: Text('%'), numeric: true, tooltip: "Percentage"),
          ],
          rows: sortedSubjects.map((entry) {
            final subjectStats = entry.value;
            final bool isAboveTarget =
                subjectStats.percentage >= provider.targetPercentage;
            final Color percentageColor = isAboveTarget
                ? (theme.brightness == Brightness.dark
                      ? Colors.green.shade300
                      : Colors.green.shade700)
                : (theme.brightness == Brightness.dark
                      ? Colors.red.shade300
                      : Colors.red.shade700);

            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    // Constrain width and allow wrapping/ellipsis
                    constraints: const BoxConstraints(
                      maxWidth: 180,
                    ), // Max width for subject name
                    child: Text(
                      subjectStats.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(subjectStats.attended.toStringAsFixed(0))),
                DataCell(Text(subjectStats.conducted.toStringAsFixed(0))),
                DataCell(
                  Text(
                    '${subjectStats.percentage.toStringAsFixed(1)}%', // Use 1 decimal place for table
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: percentageColor,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- Helper: Awesome Subject List Item --- (Enhanced Styling)
  Widget _buildSubjectAnalysisItem(
    BuildContext context,
    String name,
    SubjectStatsDetailed stats,
    double target,
    ThemeData theme,
  ) {
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final double percentage = stats.percentage;
    final bool isAboveTarget = percentage >= target;
    Color statusColor;
    if (percentage < target) {
      statusColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
    } else if (percentage < target + 5.0) {
      statusColor = isDarkMode
          ? Colors.orange.shade300
          : Colors.orange.shade700;
    } else {
      statusColor = isDarkMode ? Colors.green.shade300 : Colors.green.shade600;
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: isDarkMode ? 1 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.5), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        // Reduce horizontal padding slightly
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        child: Row(
          children: [
            Expanded(
              // Text column takes available space
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${stats.attended.toStringAsFixed(0)} / ${stats.conducted.toStringAsFixed(0)} Attended',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // Further reduced space
            // Right Side: Percentage Ring - Slightly smaller
            CircularPercentIndicator(
              radius: 24.0,
              lineWidth: 5.0,
              percent: (percentage / 100.0).clamp(0.0, 1.0),
              center: FittedBox(
                // <-- WRAP HERE
                fit: BoxFit.scaleDown, // Scale down only if needed
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ), // <-- END FittedBox
              progressColor: statusColor,
              backgroundColor: statusColor.withOpacity(0.2),
              circularStrokeCap: CircularStrokeCap.round,
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper: Smart Advisor Section --- (Enhanced Insights & Categories)
  Widget _buildSmartAdvisorSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final result = provider.result;
    final target = provider.targetPercentage.toDouble();
    final isDarkMode = theme.brightness == Brightness.dark;
    List<Widget> adviceItems = [];

    // --- Define Colors ---
    final criticalColor = isDarkMode
        ? Colors.red.shade300
        : Colors.red.shade700;
    final cautionColor = isDarkMode
        ? Colors.orange.shade300
        : Colors.orange.shade700;
    final safeColor = isDarkMode
        ? Colors.blue.shade300
        : Colors.blue.shade700; // Blue for suggestions/info
    final goodColor = isDarkMode
        ? Colors.green.shade300
        : Colors.green.shade600; // Green for positive

    // --- Categorize Subjects ---
    final subjects = result.subjectStats.values
        .where((s) => s.conducted > 0)
        .toList();
    final criticalSubjects = subjects
        .where((s) => s.percentage < target)
        .sortedBy<num>((s) => s.percentage);
    final cautionSubjects = subjects
        .where((s) => s.percentage >= target && s.percentage < (target + 5.0))
        .sortedBy<num>((s) => s.percentage);
    final safeSubjects = subjects
        .where((s) => s.percentage >= (target + 5.0))
        .sortedBy<num>((s) => -s.percentage); // Sorted highest first

    // --- Generate Advice ---

    bool hasCritical = criticalSubjects.isNotEmpty;
    bool hasCaution = cautionSubjects.isNotEmpty;

    // 1. Overall Status Header (More Direct)
    if (result.requiredToAttend > 0) {
      adviceItems.add(
        _buildAdviceItem(
          theme,
          Icons.warning_amber_rounded,
          'Overall attendance is BELOW target. Immediate action needed!',
          criticalColor,
          fontWeight: FontWeight.bold,
          isHighlighted: true,
        ),
      );
    } else if (result.maxDroppableHours < 5) {
      adviceItems.add(
        _buildAdviceItem(
          theme,
          Icons.error_outline_rounded,
          'Overall attendance is just above target (${result.currentPercentage.toStringAsFixed(1)}%). Be careful with skips.',
          cautionColor,
          fontWeight: FontWeight.bold,
          isHighlighted: true,
        ),
      );
    } else {
      adviceItems.add(
        _buildAdviceItem(
          theme,
          Icons.check_circle_outline_rounded,
          'Overall attendance is SAFE (${result.currentPercentage.toStringAsFixed(1)}%). Good job!',
          goodColor,
          fontWeight: FontWeight.bold,
          isHighlighted: true,
        ),
      );
    }
    adviceItems.add(const SizedBox(height: 12)); // Spacer after overall status

    // 2. Critical Subjects (Red Warnings - More Actionable)
    if (hasCritical) {
      adviceItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            "🚨 Attention Required:",
            style: theme.textTheme.titleMedium?.copyWith(
              color: criticalColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      for (var subj in criticalSubjects.take(3)) {
        // Calculate how many needed JUST for this subject (approximate)
        // Note: This is a simplified calculation and doesn't account for interactions
        double needed = (target / 100.0 * subj.conducted) - subj.attended;
        int consecutiveNeeded = (needed > 0 && (1 - target / 100.0) > 0)
            ? (needed / (1 - target / 100.0)).ceil()
            : 0;

        String adviceText =
            '${subj.name} (${subj.percentage.toStringAsFixed(1)}%) is CRITICAL. Avoid ALL skips.';
        if (consecutiveNeeded > 0) {
          adviceText +=
              ' Attend the next ~$consecutiveNeeded classes consecutively.';
        }

        adviceItems.add(
          _buildAdviceItem(
            theme,
            Icons.priority_high_rounded,
            adviceText,
            criticalColor,
            fontWeight: FontWeight.w600,
          ),
        ); // Slightly bolder text
      }
      if (criticalSubjects.length > 3) {
        adviceItems.add(
          _buildAdviceItem(
            theme,
            Icons.more_horiz,
            '...plus ${criticalSubjects.length - 3} other(s) below target.',
            criticalColor,
          ),
        );
      }
      adviceItems.add(const SizedBox(height: 12));
    }

    // 3. Caution Subjects (Yellow/Orange Warnings - Quantify Buffer)
    if (hasCaution) {
      adviceItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            "⚠️ Caution Zone:",
            style: theme.textTheme.titleMedium?.copyWith(
              color: cautionColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      for (var subj in cautionSubjects.take(3)) {
        // Calculate approx skips allowed JUST for this subject
        double allowed =
            (subj.attended - (target / 100.0 * subj.conducted)) /
            (target / 100.0);
        int skipsAllowed = allowed > 0 ? allowed.floor() : 0;

        adviceItems.add(
          _buildAdviceItem(
            theme,
            Icons.error_outline_rounded,
            '${subj.name} (${subj.percentage.toStringAsFixed(1)}%) has little buffer. Allows ~${skipsAllowed} skip(s).',
            cautionColor,
          ),
        );
      }
      adviceItems.add(const SizedBox(height: 12));
    }

    // 4. Top Performers / Safest to Skip (Green/Blue Info)
    if (safeSubjects.isNotEmpty) {
      adviceItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Text(
            "✅ Safe Subjects:",
            style: theme.textTheme.titleMedium?.copyWith(
              color: goodColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      final safest = safeSubjects.first;
      // Calculate approx skips allowed for the safest subject
      double safestAllowed =
          (safest.attended - (target / 100.0 * safest.conducted)) /
          (target / 100.0);
      int safestSkips = safestAllowed > 0 ? safestAllowed.floor() : 0;

      adviceItems.add(
        _buildAdviceItem(
          theme,
          Icons.verified_user, // Use specific safe icon
          '${safest.name} (${safest.percentage.toStringAsFixed(1)}%) is your highest performer (allows ~${safestSkips} skips).',
          goodColor,
          isHighlighted: true,
        ),
      ); // Highlight the best one

      if (safeSubjects.length > 1) {
        final nextSafest = safeSubjects
            .skip(1)
            .take(2)
            .map((s) => '${s.name} (${s.percentage.toStringAsFixed(1)}%)')
            .join(', ');
        adviceItems.add(
          _buildAdviceItem(
            theme,
            Icons.thumb_up_alt_outlined,
            'Also performing well: $nextSafest.',
            goodColor.withOpacity(0.8), // Slightly less prominent
          ),
        );
      }

      // Only add the "Safest to Skip" explicit suggestion if there are NO critical subjects
      if (!hasCritical) {
        adviceItems.add(const SizedBox(height: 8));
        adviceItems.add(
          _buildAdviceItem(
            theme,
            Icons.info_outline_rounded,
            'If skipping is necessary, ${safest.name} is currently your safest bet.',
            safeColor,
          ),
        ); // Use blue for informational suggestion
      }
    } else if (!hasCritical && !hasCaution) {
      // Fallback if NO subjects are safe (unlikely if overall is safe, but possible)
      adviceItems.add(
        _buildAdviceItem(
          theme,
          Icons.check_circle_outline_rounded,
          'All subjects are meeting the target or data is limited.',
          goodColor,
        ),
      );
    }

    // --- UI ---
    return _buildSectionCard(
      context: context,
      title: '🤖 Smart Advisor',
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: adviceItems.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "No specific advice generated.",
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: adviceItems,
            ),
    );
  }

  // --- Helper: Individual Advice Item --- (Enhanced Styling & Flexibility)
  Widget _buildAdviceItem(
    ThemeData theme,
    IconData icon,
    String text,
    Color color, {
    FontWeight fontWeight = FontWeight.normal,
    bool isHighlighted = false,
  }) {
    final bool isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(
        horizontal: 14.0,
        vertical: 12.0,
      ), // Slightly more padding
      decoration: BoxDecoration(
        color: color.withOpacity(
          isDarkMode ? 0.2 : 0.12,
        ), // Slightly adjust opacity
        borderRadius: BorderRadius.circular(10), // More rounded
        border: Border(
          left: BorderSide(color: color, width: 5),
        ), // Thicker accent border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24), // Slightly larger icon
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(
                  isHighlighted ? 1.0 : 0.9,
                ), // Full opacity if highlighted
                fontWeight: fontWeight,
                height: 1.3, // Slightly more line spacing
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW Helper: Trend Insight Item ---
  Widget _buildTrendInsightItem(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    final bool isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(
          isDarkMode ? 0.4 : 0.6,
        ), // Use surface color
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ), // Accent border
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium, // Default style
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: TextStyle(color: theme.hintColor),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper: Trend Analysis Section --- (Corrected Variable Scope)
  Widget _buildTrendAnalysisSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    bool canShowTrend,
  ) {
    // --- Initialize placeholder widgets ---
    Widget insightsWidget = const SizedBox.shrink();
    Widget dayOfWeekChartWidget = const SizedBox.shrink();
    // We will build the actual monthly chart widget separately
    Widget theActualMonthlyChart = const SizedBox.shrink();

    // --- Chart Setup Variables ---
    final isDarkMode = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;
    final List<Color> dayChartColors = [
      Colors.blue.shade300,
      Colors.cyan.shade300,
      Colors.teal.shade300,
      Colors.green.shade300,
      Colors.lightGreen.shade300,
      Colors.lime.shade300,
      Colors.amber.shade300,
    ];

    // --- Data Calculation ---
    List<AbsenceRecord> allAbsences = []; // Define here for broader scope
    Map<String, double> monthlyAbsences = {};

    if (canShowTrend) {
      // Collect all absences and sort
      allAbsences =
          provider.result.subjectStats.values.expand((s) => s.absences).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      if (allAbsences.isNotEmpty) {
        // --- Calculate Insights ---
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

        final absencesToday = allAbsences
            .where((a) => !a.date.isBefore(todayStart))
            .length;
        final absencesYesterday = allAbsences
            .where(
              (a) =>
                  !a.date.isBefore(yesterdayStart) &&
                  a.date.isBefore(todayStart),
            )
            .length;
        final absencesLast7Days = allAbsences
            .where((a) => a.date.isAfter(sevenDaysAgo))
            .length;
        final absencesLast30Days = allAbsences
            .where((a) => a.date.isAfter(thirtyDaysAgo))
            .length;

        Map<int, int> dayCounts = {};
        allAbsences.forEach((a) {
          dayCounts[a.date.weekday] = (dayCounts[a.date.weekday] ?? 0) + 1;
        });
        var sortedDays = dayCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        String mostMissedDay = sortedDays.isNotEmpty
            ? DateFormat(
                'EEEE',
              ).format(DateTime(2023, 1, sortedDays.first.key + 1))
            : "N/A";

        int longestStreak = 0;
        int currentStreak = 0;
        DateTime? lastAbsenceDate;
        for (var a in allAbsences) {
          if (lastAbsenceDate != null) {
            if (a.date.difference(lastAbsenceDate).inDays == 1) {
              currentStreak++;
            } else if (a.date.difference(lastAbsenceDate).inDays > 1) {
              currentStreak = 1;
            }
          } else {
            currentStreak = 1;
          }
          if (currentStreak > longestStreak) {
            longestStreak = currentStreak;
          }
          lastAbsenceDate = a.date;
        }

        String avgTimeBetween = "N/A";
        if (allAbsences.length > 1) {
          Duration totalTimeBetween = Duration.zero;
          for (int i = 1; i < allAbsences.length; i++) {
            if (!DateUtils.isSameDay(
              allAbsences[i].date,
              allAbsences[i - 1].date,
            )) {
              totalTimeBetween += allAbsences[i].date.difference(
                allAbsences[i - 1].date,
              );
            }
          }
          int numGaps =
              allAbsences
                  .map((a) => DateUtils.dateOnly(a.date))
                  .toSet()
                  .length -
              1;
          if (numGaps > 0) {
            double avgDays = totalTimeBetween.inDays / numGaps;
            avgTimeBetween = "${avgDays.toStringAsFixed(1)} days";
          }
        }

        // Build the Insights Grid
        insightsWidget = Column(
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _buildRecencyInsight(theme, "Today", absencesToday, errorColor),
                _buildRecencyInsight(
                  theme,
                  "Yesterday",
                  absencesYesterday,
                  errorColor.withOpacity(0.8),
                ),
                _buildRecencyInsight(
                  theme,
                  "Last 7 Days",
                  absencesLast7Days,
                  errorColor.withOpacity(0.6),
                ),
                _buildRecencyInsight(
                  theme,
                  "Last 30 Days",
                  absencesLast30Days,
                  primaryColor.withOpacity(0.8),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildTrendInsightItem(
              theme,
              Icons.calendar_view_week_outlined,
              "Most Absences On",
              mostMissedDay,
              primaryColor,
            ),
            _buildTrendInsightItem(
              theme,
              Icons.hourglass_empty_rounded,
              "Avg. Time Between",
              avgTimeBetween,
              primaryColor,
            ),
            if (longestStreak > 1)
              _buildTrendInsightItem(
                theme,
                Icons.sync_alt_rounded,
                "Longest Absence Streak",
                "$longestStreak days",
                errorColor.withOpacity(0.8),
              ),
            const SizedBox(height: 20),
          ],
        );

        // --- Calculate Day of Week Data ---
        Map<int, double> dayOfWeekHours = {
          1: 0,
          2: 0,
          3: 0,
          4: 0,
          5: 0,
          6: 0,
          7: 0,
        };
        allAbsences.forEach((absence) {
          dayOfWeekHours[absence.date.weekday] =
              (dayOfWeekHours[absence.date.weekday] ?? 0) + absence.hours;
        });
        final maxDayHours = dayOfWeekHours.values.isEmpty
            ? 1.0
            : dayOfWeekHours.values.reduce(max);
        final intervalDayY = (maxDayHours / 4).clamp(
          1.0,
          maxDayHours > 0 ? maxDayHours : 1.0,
        );

        // Build the Day of Week Chart
        dayOfWeekChartWidget = SizedBox(
          height: 180,
          child: BarChart(
            /* ... Your BarChartData configuration ... */
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: (maxDayHours * 1.1).ceilToDouble().clamp(
                5.0,
                double.infinity,
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: intervalDayY,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: theme.hintColor.withOpacity(0.1),
                  strokeWidth: 0.5,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: intervalDayY,
                    getTitlesWidget: (v, m) => Text(
                      '${v.toInt()}h',
                      style: TextStyle(color: theme.hintColor, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 25,
                    getTitlesWidget: (value, meta) {
                      const days = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      final index = value.toInt();
                      if (index >= 0 && index < days.length) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            days[index],
                            style: TextStyle(
                              color: theme.hintColor,
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
              ),
              barGroups: dayOfWeekHours.entries.mapIndexed((index, entry) {
                final dayIndex = entry.key - 1;
                final hours = entry.value;
                return BarChartGroupData(
                  x: dayIndex,
                  barRods: [
                    BarChartRodData(
                      toY: hours,
                      gradient: LinearGradient(
                        colors: [
                          dayChartColors[dayIndex % dayChartColors.length]
                              .withOpacity(0.9),
                          dayChartColors[dayIndex % dayChartColors.length]
                              .withOpacity(0.5),
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      width: 16,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }).toList(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    const days = [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ];
                    final dayName = days[group.x.toInt()];
                    final hours = rod.toY;
                    return BarTooltipItem(
                      '$dayName\n',
                      TextStyle(color: theme.hintColor, fontSize: 12),
                      children: [
                        TextSpan(
                          text: '${hours.toStringAsFixed(1)} hours',
                          style: TextStyle(
                            color:
                                dayChartColors[group.x.toInt() %
                                    dayChartColors.length],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // --- Calculate Monthly Data ---
        var groupedByMonth = groupBy(
          allAbsences,
          (AbsenceRecord r) => DateFormat('yyyy-MM').format(r.date),
        );
        groupedByMonth.forEach((month, records) {
          monthlyAbsences[month] = records.map((r) => r.hours).sum;
        });

        // --- Build the Monthly Chart OR Placeholder ---
        if (monthlyAbsences.length >= 2) {
          final spots = monthlyAbsences.entries
              .mapIndexed(
                (index, entry) => FlSpot(index.toDouble(), entry.value),
              )
              .toList();
          final maxY = monthlyAbsences.isEmpty
              ? 10.0
              : monthlyAbsences.values.reduce(max);
          final intervalY = (maxY / 4).clamp(1.0, maxY > 0 ? maxY : 1.0);

          // Define the actual chart widget
          theActualMonthlyChart = SizedBox(
            height: 200,
            child: LineChart(
              /* ... Your LineChartData configuration ... */
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalY,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: theme.hintColor.withOpacity(0.2),
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyAbsences.keys.length) {
                          final monthYear = monthlyAbsences.keys.elementAt(
                            index,
                          );
                          final monthAbbr = DateFormat(
                            'MMM',
                          ).format(DateFormat('yyyy-MM').parse(monthYear));
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4,
                            child: Text(
                              monthAbbr,
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: intervalY,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}h',
                        style: TextStyle(color: theme.hintColor, fontSize: 10),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (monthlyAbsences.length - 1).toDouble().clamp(
                  0.0,
                  double.infinity,
                ),
                minY: 0,
                maxY: (maxY * 1.1).ceilToDouble().clamp(5.0, double.infinity),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.3)],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          primaryColor.withOpacity(0.3),
                          primaryColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((spot) {
                            final index = spot.x.toInt();
                            if (index < 0 ||
                                index >= monthlyAbsences.keys.length)
                              return null;
                            final monthYear = monthlyAbsences.keys.elementAt(
                              index,
                            );
                            final hours = spot.y;
                            return LineTooltipItem(
                              '${DateFormat('MMM yyyy').format(DateFormat('yyyy-MM').parse(monthYear))}\n',
                              theme.textTheme.bodySmall!.copyWith(
                                color: theme.hintColor,
                              ),
                              children: [
                                TextSpan(
                                  text:
                                      '${hours.toStringAsFixed(1)} hours absent',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          })
                          .whereNotNull()
                          .toList();
                    },
                  ),
                ),
              ),
            ),
          );
        } else {
          // Less than 2 months of data
          theActualMonthlyChart = const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                "Need at least 2 months of data for a trend chart.",
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          );
        }
      } else {
        // No absences at all
        insightsWidget = const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "No absences recorded in the data.",
              style: TextStyle(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        );
        theActualMonthlyChart = const SizedBox(height: 10);
        dayOfWeekChartWidget = const SizedBox.shrink();
      }
    } else {
      // Trend cannot be shown (e.g., aggregated data)
      insightsWidget = const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            "Trend insights & charts require raw log data with dates.",
            style: TextStyle(fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
        ),
      );
      theActualMonthlyChart = const SizedBox(height: 10);
      dayOfWeekChartWidget = const SizedBox.shrink();
    }

    // --- Combine Sections & Apply Lock ---
    // Build the complete content first
    Widget trendContent = _buildSectionCard(
      context: context,
      title: '🔍 Absence Trend',
      padding: EdgeInsets.zero, // Section card handles padding
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 0,
              ),
              child: insightsWidget, // Show calculated insights
            ),
            if (canShowTrend && allAbsences.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  "Absences by Day of Week",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 8.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                child: dayOfWeekChartWidget, // Show day of week chart
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Text(
                "Absences Over Time (Monthly)",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 8.0,
                right: 16.0,
                bottom: 16.0,
              ),
              // NOTE: Use the 'theActualMonthlyChart' variable directly here.
              // The Consumer lock for the *monthly chart itself* is removed,
              // as the whole section is now locked.
              child: theActualMonthlyChart,
            ),
          ],
        ),
      ),
    );

    // Now, wrap the whole 'trendContent' with the Consumer
    return Consumer<AdProvider>(
      builder: (context, adProvider, child) {
        // If trend isn't possible OR it's unlocked, show the content
        if (!canShowTrend || adProvider.isAbsenceTrendUnlocked) {
          return child!; // Show the actual trendContent
        }

        // --- Otherwise, show the LOCK for the entire section ---
        return Stack(
          alignment: Alignment.center,
          children: [
            // Blurred content (the whole section card)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: AbsorbPointer(child: child), // child is trendContent
            ),
            // Unlock button (placed over the blur)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40.0),
              child: FilledButton.icon(
                icon: const Icon(Icons.movie_filter_rounded),
                label: const Text('Unlock Trend Analysis'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: () {
                  _showRewardedAdDialog(
                    context: context,
                    title: 'Your own Trend Analysis',
                    content:
                        'Watch a short ad to view absence trends for this app session?',
                    onReward: () {
                      Provider.of<AdProvider>(
                        context,
                        listen: false,
                      ).unlockAbsenceTrend();
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
      child: trendContent, // Pass the fully built trend section card here
    );
  }

  // --- NEW Helper: Recency Insight Item ---
  Widget _buildRecencyInsight(
    ThemeData theme,
    String label,
    int count,
    Color baseColor,
  ) {
    final bool hasAbsences = count > 0;
    final Color color = hasAbsences
        ? baseColor
        : theme.hintColor.withOpacity(0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            // Allow FittedBox to take available vertical space
            child: FittedBox(
              fit: BoxFit.scaleDown, // Scale down text if it overflows
              child: Text(
                count.toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                  height: 1.15,
                ),
                maxLines: 1,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withOpacity(0.9),
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
} // End AnalysisPage Class
