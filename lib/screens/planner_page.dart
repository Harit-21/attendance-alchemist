import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/widgets/custom_card.dart'; // Still using CustomCard
import 'package:attendance_alchemist/helpers/toast_helper.dart';
import 'package:attendance_alchemist/mixins/scroll_to_top_mixin.dart';
import 'package:attendance_alchemist/services/hive_service.dart';
import 'package:attendance_alchemist/models/schedule_entry.dart';
import 'package:attendance_alchemist/widgets/banner_ad_widget.dart';
import 'package:attendance_alchemist/services/ad_service.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => PlannerPageState();
}

class PlannerPageState extends State<PlannerPage> with ScrollToTopMixin {
  final _customAttendController = TextEditingController();
  final _remainingTimeController = TextEditingController();
  final _classesPerWeekController = TextEditingController();
  final _whatIfClassesController = TextEditingController();
  final _holidayAttendBeforeController = TextEditingController();
  final _holidayDaysController = TextEditingController();
  final _holidayTotalClassesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeControllers();
      _addListeners();
    });
  }

  void _initializeControllers() {
    if (!mounted) return;
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    _customAttendController.text = provider.plannerFutureClassesToAttend > 0
        ? provider.plannerFutureClassesToAttend.toString()
        : '';
    _remainingTimeController.text = provider.projectionRemainingTime.toString();
    _classesPerWeekController.text = provider.projectionClassesPerWeek
        .toString();
    _whatIfClassesController.text = provider.whatIfNumClasses.toString();
    _holidayAttendBeforeController.text = provider.holidayAttendBefore >= 0
        ? provider.holidayAttendBefore.toString()
        : '0'; // Handle >=0
    _holidayDaysController.text = provider.holidayDays.toString();
    _holidayTotalClassesController.text = provider.holidayTotalClassesToMiss
        .toString();
  }

  void _onAnalyzeSkip(AttendanceProvider provider, String subjectName) {
    // Check if subject exists in attendance data
    if (!provider.result.subjectStats.containsKey(subjectName)) {
      showErrorToast(
        "Subject '$subjectName' not found in your attendance data. Please ensure names match exactly.",
      );
      return;
    }

    // Set provider values
    provider.setWhatIfSubject(subjectName);
    provider.setWhatIfAction('miss');
    provider.setWhatIfNumClasses(1);

    // Run simulation
    provider.runWhatIfSimulation();

    showTopToast(
      "Running simulation for skipping 1 class of '$subjectName'...",
    );

    // You might want to scroll to the "Advanced What-If" card
    // but this requires another controller. For now, the toast is good.
  }

  void _addListeners() {
    _customAttendController.addListener(_updateCustomAttend);
    _remainingTimeController.addListener(_updateRemainingTime);
    _classesPerWeekController.addListener(_updateClassesPerWeek);
    _whatIfClassesController.addListener(_updateWhatIfClasses);
    _holidayAttendBeforeController.addListener(_updateHolidayAttendBefore);
    _holidayDaysController.addListener(_updateHolidayDays);
    _holidayTotalClassesController.addListener(_updateHolidayTotalClasses);
  }

  @override
  void dispose() {
    /* ... same ... */
    _customAttendController.removeListener(_updateCustomAttend);
    _remainingTimeController.removeListener(_updateRemainingTime);
    _classesPerWeekController.removeListener(_updateClassesPerWeek);
    _whatIfClassesController.removeListener(_updateWhatIfClasses);
    _holidayAttendBeforeController.removeListener(_updateHolidayAttendBefore);
    _holidayDaysController.removeListener(_updateHolidayDays);
    _holidayTotalClassesController.removeListener(_updateHolidayTotalClasses);
    _customAttendController.dispose();
    _remainingTimeController.dispose();
    _classesPerWeekController.dispose();
    _whatIfClassesController.dispose();
    _holidayAttendBeforeController.dispose();
    _holidayDaysController.dispose();
    _holidayTotalClassesController.dispose();
    super.dispose();
  }

  void _updateCustomAttend() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_customAttendController.text) ?? 0;
    if (v != p.plannerFutureClassesToAttend) p.setPlannerFutureClasses(v);
  }

  void _updateRemainingTime() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_remainingTimeController.text) ?? 1;
    if (v != p.projectionRemainingTime) p.setProjectionRemainingTime(v);
  }

  void _updateClassesPerWeek() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_classesPerWeekController.text) ?? 1;
    if (v != p.projectionClassesPerWeek) p.setProjectionClassesPerWeek(v);
  }

  void _updateWhatIfClasses() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_whatIfClassesController.text) ?? 1;
    if (v != p.whatIfNumClasses) p.setWhatIfNumClasses(v);
  }

  void _updateHolidayAttendBefore() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_holidayAttendBeforeController.text) ?? 0;
    if (v != p.holidayAttendBefore) p.setHolidayAttendBefore(v);
  }

  void _updateHolidayDays() {
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_holidayDaysController.text) ?? 1;
    if (v != p.holidayDays) p.setHolidayDays(v);
  }

  void _updateHolidayTotalClasses() {
    /* ... same ... */
    final p = Provider.of<AttendanceProvider>(context, listen: false);
    final v = int.tryParse(_holidayTotalClassesController.text) ?? 1;
    if (v != p.holidayTotalClassesToMiss) p.setHolidayTotalClassesToMiss(v);
  }

  void _syncControllers(AttendanceProvider provider) {
    /* ... same ... */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Schedule update
      if (!mounted) return;
      if (_remainingTimeController.text !=
          provider.projectionRemainingTime.toString())
        _remainingTimeController.text = provider.projectionRemainingTime
            .toString();
      if (_classesPerWeekController.text !=
          provider.projectionClassesPerWeek.toString())
        _classesPerWeekController.text = provider.projectionClassesPerWeek
            .toString();
      final cAT =
          _customAttendController.text !=
          (provider.plannerFutureClassesToAttend > 0
              ? provider.plannerFutureClassesToAttend.toString()
              : '');
      if (cAT)
        _customAttendController.text =
            (provider.plannerFutureClassesToAttend > 0
            ? provider.plannerFutureClassesToAttend.toString()
            : '');
      if (_whatIfClassesController.text != provider.whatIfNumClasses.toString())
        _whatIfClassesController.text = provider.whatIfNumClasses.toString();
      final hABT =
          _holidayAttendBeforeController.text !=
          (provider.holidayAttendBefore >= 0
              ? provider.holidayAttendBefore.toString()
              : '0');
      if (hABT)
        _holidayAttendBeforeController.text = (provider.holidayAttendBefore >= 0
            ? provider.holidayAttendBefore.toString()
            : '0');
      if (_holidayDaysController.text != provider.holidayDays.toString())
        _holidayDaysController.text = provider.holidayDays.toString();

      if (_holidayTotalClassesController.text !=
          provider.holidayTotalClassesToMiss.toString())
        _holidayTotalClassesController.text = provider.holidayTotalClassesToMiss
            .toString();
      // Move cursor if needed (less intrusive)
      if (cAT || hABT /* add other relevant conditions */ ) {
        final controller = cAT
            ? _customAttendController
            : _holidayAttendBeforeController;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
      }
    });
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final bool hasBaseData = provider.result.dataParsedSuccessfully;

        _syncControllers(provider); // Sync controllers

        return Scaffold(
          appBar: AppBar(
            title: const Text('Future Planner 🚀'), // Added emoji
            elevation: 0, // Flat AppBar
            backgroundColor: theme.scaffoldBackgroundColor, // Match background
            foregroundColor:
                theme.textTheme.titleLarge?.color, // Match text color
            automaticallyImplyLeading: false,
          ),
          body: Column(
            // Use a Column as the main body
            children: [
              Expanded(
                // Make the primary content take available space
                child: GestureDetector(
                  // Keep GestureDetector for unfocus
                  behavior:
                      HitTestBehavior.opaque, // Recommended for GestureDetector
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: !hasBaseData
                      ? _buildPlaceholder(context, theme)
                      : _buildPlannerContent(
                          context,
                          provider,
                          theme,
                        ), // This contains your ListView
                ),
              ),
              SafeArea(
                top: false,
                child: BannerAdWidget(
                  adUnitId: AdService.instance.plannerBannerAdUnitId,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Placeholder Widget ---
  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    /* ... same ... */
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_calendar_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Base Data Calculated',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.hintColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Home page, input your data, and calculate first to unlock the planner!',
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

  // --- Main Planner Content ---
  Widget _buildPlannerContent(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final customCalcResult = provider.calculateCustomMissable();

    return ListView(
      controller: scrollController,
      // Use ListView for scrolling sections
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildTodaysClassesSection(context, provider, theme),
        _buildDivider(),
        // --- Custom Scenario Section ---
        _buildCustomScenarioSection(context, provider, theme, customCalcResult),
        _buildDivider(), // Use helper for dividers
        // --- Advanced What-If Section ---
        _buildAdvancedWhatIfSection(context, provider, theme),
        _buildDivider(),
        // --- Projection Section ---
        _buildProjectionSection(context, provider, theme),
        _buildDivider(),
        // --- Holiday Planner Section ---
        _buildHolidayPlannerSection(context, provider, theme),
        const SizedBox(height: 20), // Bottom padding
      ],
    );
  }

  Widget _buildTodaysClassesSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final schedule = HiveService.getSchedule();
    final today = DateTime.now().weekday;
    final todaysClasses = schedule.where((e) => e.dayOfWeek == today).toList();

    final now = TimeOfDay.now();
    final upcomingClasses = todaysClasses.where((e) {
      final timeParts = e.startTime.split(':');
      final classTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      return (classTime.hour > now.hour) ||
          (classTime.hour == now.hour && classTime.minute >= now.minute);
    }).toList();

    upcomingClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🔮 Today\'s Upcoming Classes',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Analyze the impact of skipping an upcoming class.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          if (upcomingClasses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'No upcoming classes found for today.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ),
          if (upcomingClasses.isNotEmpty)
            // --- 1. THE HORIZONTAL LIST ---
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: upcomingClasses.length,
                itemBuilder: (context, index) {
                  final entry = upcomingClasses[index];
                  // --- 2. THE COMPACT CARD ---
                  // return Container(
                  //   width: 180, // Give each card a fixed width
                  //   margin: const EdgeInsets.only(right: 10),
                  //   child: OutlinedButton(
                  //     clipBehavior: Clip.antiAlias,
                  //     style: OutlinedButton.styleFrom(
                  //       padding: const EdgeInsets.all(12),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //     ),
                  //     onPressed: () =>
                  //         _onAnalyzeSkip(provider, entry.subjectName),
                  //     child: FittedBox(
                  //       // Added FittedBox
                  //       fit: BoxFit.scaleDown,
                  //       child: Column(
                  //         crossAxisAlignment: CrossAxisAlignment.start,
                  //         // mainAxisAlignment: MainAxisAlignment.center,
                  //         children: [
                  //           Text(
                  //             entry.startTime,
                  //             style: theme.textTheme.titleSmall?.copyWith(
                  //               fontWeight: FontWeight.bold,
                  //               color: theme.colorScheme.primary,
                  //             ),
                  //             maxLines: 1,
                  //           ),
                  //           const SizedBox(height: 4),
                  //           Text(
                  //             entry.subjectName,
                  //             style: theme.textTheme.bodyMedium?.copyWith(
                  //               fontWeight: FontWeight.bold,
                  //             ),
                  //             maxLines: 2,
                  //             overflow: TextOverflow.ellipsis,
                  //           ),
                  //           const SizedBox(height: 6),
                  //           Text(
                  //             'Tap to Analyze Skip',
                  //             style: theme.textTheme.labelSmall?.copyWith(
                  //               color: theme.hintColor,
                  //               fontSize: 10,
                  //             ),
                  //             maxLines: 1,
                  //             overflow: TextOverflow.ellipsis,
                  //           ),
                  //         ],
                  //       ),
                  //     ),
                  //   ),
                  // );
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight:
                            125, // Minimum height for consistent button size
                        maxHeight:
                            127, // Optional: prevents it from getting too tall
                      ),
                      child: OutlinedButton(
                        clipBehavior: Clip.antiAlias,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () =>
                            _onAnalyzeSkip(provider, entry.subjectName),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              entry.startTime,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              entry.subjectName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap to Analyze Skip',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.hintColor,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // --- Divider Helper --- (Consistent styled divider)
  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20.0), // Adjust spacing
    child: Divider(height: 1, thickness: 0.5),
  );

  // --- SECTION BUILDER: Custom Scenario ---
  Widget _buildCustomScenarioSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    Map<String, dynamic> customCalcResult,
  ) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '✨ Custom Scenario',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('What if I attend...', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _customAttendController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(
              theme,
              hint: 'e.g., 10 classes',
            ), // Use helper
          ),
          const SizedBox(height: 16),
          // Result Display (uses helper)
          AnimatedSize(
            // Animate size change when result appears/disappears
            duration: const Duration(milliseconds: 200),
            child: (customCalcResult['canCalculate'] == true)
                ? _buildCustomCalcResult(context, customCalcResult)
                : (provider.plannerFutureClassesToAttend > 0
                      ? _buildResultPlaceholder(
                          theme,
                          customCalcResult['error'] ?? 'Calculation error.',
                        )
                      : const SizedBox.shrink()), // Show nothing if input is 0
          ),
        ],
      ),
    );
  }

  // --- SECTION BUILDER: Advanced What-If ---
  Widget _buildAdvancedWhatIfSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final subjectNames = provider.result.subjectStats.keys.toList()..sort();
    if (provider.whatIfSelectedSubject != null &&
        !subjectNames.contains(provider.whatIfSelectedSubject)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.setWhatIfSubject(null);
      });
    }

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🧪 Advanced What-If',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simulate missing/attending specific classes.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          // Subject Dropdown
          DropdownButtonFormField<String>(
            value: provider.whatIfSelectedSubject,
            hint: const Text('-- Select Subject --'),
            isExpanded: true,
            items: subjectNames
                .map(
                  (name) => DropdownMenuItem(
                    value: name,
                    child: Text(name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (value) => provider.setWhatIfSubject(value),
            decoration: _inputDecoration(theme, label: 'Subject'), // Use helper
          ),
          const SizedBox(height: 12),
          // Action & Classes Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                // Action
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: provider.whatIfAction,
                  items: const [
                    DropdownMenuItem(value: 'attend', child: Text('Attend')),
                    DropdownMenuItem(value: 'miss', child: Text('Miss')),
                  ],
                  onChanged: (value) {
                    if (value != null) provider.setWhatIfAction(value);
                  },
                  decoration: _inputDecoration(
                    theme,
                    label: 'Action',
                  ), // Use helper
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                // Classes
                flex: 2,
                child: TextField(
                  controller: _whatIfClassesController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    theme,
                    label: 'Classes',
                  ), // Use helper
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simulate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.science_outlined, size: 18),
              label: const Text('Run Simulation'),
              onPressed:
                  provider.isLoading || provider.whatIfSelectedSubject == null
                  ? null
                  : provider.runWhatIfSimulation,
              style: _elevatedButtonStyle(theme), // Use helper
            ),
          ),
          // Result Display
          if (provider.whatIfResult != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildWhatIfResult(context, provider.whatIfResult!),
            ),
        ],
      ),
    );
  }

  // --- SECTION BUILDER: Projection ---
  Widget _buildProjectionSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    bool isWeeksMode = provider.projectionMode == 'weeks';
    bool isDarkMode = theme.brightness == Brightness.dark;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🗓️ Future Projection',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          // --- Mode Toggle ---
          Text(
            'Project Using:',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            /* ... segments ... */
            segments: const [
              ButtonSegment(
                value: 'weeks',
                label: Text('Weeks'),
                icon: Icon(Icons.calendar_view_week, size: 18),
              ),
              ButtonSegment(
                value: 'days',
                label: Text('Days'),
                icon: Icon(Icons.calendar_view_day, size: 18),
              ),
            ],
            selected: {provider.projectionMode},
            onSelectionChanged: (s) => provider.setProjectionMode(s.first),
            style: _segmentedButtonStyle(theme), // Use helper
          ),
          const SizedBox(height: 16),
          // --- Input Fields Row ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* ... inputs ... */
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isWeeksMode ? 'Remaining Weeks' : 'Remaining Days',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _remainingTimeController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(
                        theme,
                        hint: isWeeksMode ? 'e.g., 5' : 'e.g., 35',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Avg Classes / Week',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _classesPerWeekController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(theme, hint: 'e.g., 30'),
                    ),
                    if (!isWeeksMode) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Class Days / Week',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<int>(
                        value: provider.projectionDaysPerWeek,
                        items: List.generate(6, (i) => 6 - i)
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text('$d day${d > 1 ? 's' : ''}'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) provider.setProjectionDaysPerWeek(v);
                        },
                        decoration: _inputDecoration(theme, isDropdown: true),
                      ),
                    ],
                  ],
                ),
              ), // Added isDropdown flag
            ],
          ),
          const Divider(height: 32, thickness: 0.5),
          // --- Projection Results ---
          Text(
            '📈 Your Projection',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          (provider.projectionTotalRemainingClasses <= 0 ||
                  !provider.result.dataParsedSuccessfully)
              ? _buildResultPlaceholder(
                  theme,
                  "Enter valid timeline details above.",
                )
              : GridView.count(
                  /* ... GridView setup ... */
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.7, // Adjusted ratio slightly
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    /* ... _buildProjectionStatBox calls ... */
                    _buildProjectionStatBox(
                      context,
                      'Remaining Classes',
                      provider.projectionTotalRemainingClasses.toString(),
                      isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      Icons.hourglass_bottom_outlined,
                    ),
                    _buildProjectionStatBox(
                      context,
                      'Must Attend',
                      provider.projectionRequiredAttendance.toString(),
                      isDarkMode
                          ? Colors.green.shade300
                          : Colors.green.shade700,
                      Icons.check_circle_outline,
                    ),
                    _buildProjectionStatBox(
                      context,
                      'Can Skip',
                      provider.projectionAllowedSkips.toString(),
                      isDarkMode
                          ? Colors.orange.shade300
                          : Colors.orange.shade800,
                      Icons.directions_run_outlined,
                    ),
                    _buildProjectionStatBox(
                      context,
                      'Projected Final %',
                      '${provider.projectionFinalPercentage.toStringAsFixed(2)}%',
                      provider.projectionFinalPercentage >=
                              provider.targetPercentage
                          ? (isDarkMode
                                ? Colors.green.shade300
                                : Colors.green.shade700)
                          : (isDarkMode
                                ? Colors.red.shade300
                                : Colors.red.shade700),
                      Icons.trending_up,
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  // --- SECTION BUILDER: Holiday Planner ---
  Widget _buildHolidayPlannerSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    bool isDaysMode = provider.holidayInputMode == 'days';
    double avgClassesPerDay = provider.calculatedAvgClassesPerDay;

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏖️ Holiday & Leave Planner',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Simulate the impact of upcoming time off.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          // Attend Before
          TextField(
            controller: _holidayAttendBeforeController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(
              theme,
              label: 'Classes to Attend Before Leave?',
              hint: 'Enter 0 if none',
            ),
          ),
          const Divider(height: 32),
          // Mode Toggle
          Text(
            'Measure Leave By:',
            style: theme.textTheme.labelLarge?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            /* ... segments ... */
            segments: const [
              ButtonSegment(
                value: 'days',
                label: Text('Days'),
                icon: Icon(Icons.date_range, size: 18),
              ),
              ButtonSegment(
                value: 'classes',
                label: Text('Classes'),
                icon: Icon(Icons.class_outlined, size: 18),
              ),
            ],
            selected: {provider.holidayInputMode},
            onSelectionChanged: (s) => provider.setHolidayInputMode(s.first),
            style: _segmentedButtonStyle(theme),
          ),
          const SizedBox(height: 16),
          // Conditional Inputs (Animated)
          AnimatedCrossFade(
            firstChild: _buildHolidayDaysInput(theme, provider),
            secondChild: _buildHolidayClassesInput(theme),
            crossFadeState: isDaysMode
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
          const SizedBox(height: 20),
          // Analyze Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('Analyze Holiday Impact'),
              onPressed: provider.isLoading
                  ? null
                  : provider.calculateHolidayImpact,
              style: _elevatedButtonStyle(theme),
            ),
          ),
          // Result Display (Animated)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: provider.holidayImpactResult != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: _buildHolidayResult(
                      context,
                      provider.holidayImpactResult!,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // --- Helper for Holiday Days Input Row ---
  Widget _buildHolidayDaysInput(ThemeData theme, AttendanceProvider provider) {
    // double avgClasses = provider.calculatedAvgClassesPerDay;
    // String avgClassesText = avgClasses > 0
    //     ? avgClasses.toStringAsFixed(1)
    //     : 'N/A';
    // bool showWarning = avgClasses <= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Days Input
        Expanded(
          child: TextField(
            controller: _holidayDaysController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _inputDecoration(theme, label: 'Days of Leave'),
          ),
        ),
        // const SizedBox(width: 12),
        // // Display Calculated Average Classes/Day (Read-Only)
        // Expanded(
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Text(
        //         'Avg Classes / Day',
        //         style: theme.textTheme.labelMedium?.copyWith(
        //           color: theme.hintColor,
        //         ),
        //       ),
        //       const SizedBox(height: 4),
        //       Container(
        //         width: double.infinity,
        //         padding: const EdgeInsets.symmetric(
        //           horizontal: 16,
        //           vertical: 14,
        //         ),
        //         decoration: BoxDecoration(
        //           color: theme.colorScheme.surface.withOpacity(0.5),
        //           borderRadius: BorderRadius.circular(12),
        //           // Optional: Add a subtle border if needed
        //           // border: Border.all(color: theme.hintColor.withOpacity(0.3))
        //         ),
        //         child: Text(
        //           avgClassesText,
        //           style: theme.textTheme.bodyLarge?.copyWith(
        //             color: showWarning
        //                 ? theme.colorScheme.error
        //                 : theme.textTheme.bodyLarge?.color, // Highlight if N/A
        //             fontWeight: FontWeight.w500,
        //           ),
        //         ),
        //       ),
        //       if (showWarning)
        //         Padding(
        //           padding: const EdgeInsets.only(top: 4.0),
        //           child: Text(
        //             "Set Projection Avg/Week & Days/Week first.",
        //             style: theme.textTheme.labelSmall?.copyWith(
        //               color: theme.colorScheme.error,
        //             ),
        //             maxLines: 2,
        //           ),
        //         ),
        //     ],
        //   ),
        // ),
      ],
    );
  }

  // --- Helper for Holiday Classes Input ---
  Widget _buildHolidayClassesInput(ThemeData theme) {
    return TextField(
      controller: _holidayTotalClassesController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: _inputDecoration(theme, label: 'Total Classes to Miss'),
    );
  }

  // --- RESULT DISPLAY HELPERS (Keep as before, with minor style tweaks) ---
  Widget _buildCustomCalcResult(
    BuildContext context,
    Map<String, dynamic> calcResult,
  ) {
    /* ... same structure ... */
    final theme = Theme.of(context);
    final isSafe = calcResult['isSafe'] ?? false;
    final color = isSafe
        ? (theme.brightness == Brightness.dark
              ? Colors.green.shade300
              : Colors.green.shade800)
        : (theme.brightness == Brightness.dark
              ? Colors.red.shade300
              : Colors.red.shade900);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: isSafe
          ? RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
                children: [
                  const TextSpan(text: '✅ Attend '),
                  TextSpan(
                    text:
                        '${Provider.of<AttendanceProvider>(context, listen: false).plannerFutureClassesToAttend}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' classes, then you can miss '),
                  TextSpan(
                    text: '${calcResult['skipsAllowed']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' (vs ${calcResult['originalSkips']}).\n'),
                  const TextSpan(text: '📊 Projected: '),
                  TextSpan(
                    text:
                        '${(calcResult['projectedPercent'] as double).toStringAsFixed(2)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(
                    text:
                        ' (${calcResult['projectedAttended']}/${calcResult['projectedConducted']}).',
                  ),
                ],
              ),
            )
          : Text(
              calcResult['message'],
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
    );
  }

  Widget _buildWhatIfResult(
    BuildContext context,
    Map<String, dynamic> simResult,
  ) {
    /* ... same structure ... */
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.blue.shade200 : Colors.blue.shade800;
    final successColor = isDarkMode
        ? Colors.green.shade300
        : Colors.green.shade700;
    final errorColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
    if (simResult['error'] != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          simResult['error'],
          style: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
        ),
      );
    }
    final newOverall = simResult['newOverallPercent'] as double;
    final oldOverall = simResult['originalOverallPercent'] as double;
    final newSubject = simResult['newSubjectPercent'] as double;
    final oldSubject = simResult['originalSubjectPercent'] as double;
    final isAboveTarget = simResult['isAboveTarget'] as bool;
    TextSpan formatChangeSpan(double nV, double oV) {
      final d = nV - oV;
      final c = d >= 0 ? successColor : errorColor;
      final s = d >= 0 ? '+' : '';
      return TextSpan(
        text: ' (${s}${d.toStringAsFixed(2)}%)',
        style: TextStyle(
          color: c,
          fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulation Result:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'After you ${simResult['action']} ${simResult['numClasses']} class(es) of "${simResult['subjectName']}":',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: '• Subject: '),
                TextSpan(
                  text:
                      '${oldSubject.toStringAsFixed(2)}% → ${newSubject.toStringAsFixed(2)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                formatChangeSpan(newSubject, oldSubject),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: '• Overall: '),
                TextSpan(
                  text:
                      '${oldOverall.toStringAsFixed(2)}% → ${newOverall.toStringAsFixed(2)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                formatChangeSpan(newOverall, oldOverall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAboveTarget ? '✅ Still above target.' : '🚨 Below target!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isAboveTarget ? successColor : errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHolidayResult(
    BuildContext context,
    Map<String, dynamic> impactResult,
  ) {
    /* ... same structure ... */
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.teal.shade200 : Colors.teal.shade800;
    final successColor = isDarkMode
        ? Colors.green.shade300
        : Colors.green.shade700;
    final errorColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
    if (impactResult['error'] != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          impactResult['error'],
          style: TextStyle(color: errorColor, fontWeight: FontWeight.w500),
        ),
      );
    }
    final isSafe = impactResult['isSafe'] as bool;
    final percentageAfter = impactResult['percentageAfter'] as double;
    final resultColor = isSafe ? successColor : errorColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Holiday Impact Analysis:',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: 'Attend '),
                TextSpan(
                  text: '${impactResult['attendBefore']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: ', take '),
                TextSpan(
                  text: '${impactResult['leaveDescription']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: '• Final State: '),
                TextSpan(
                  text:
                      '${impactResult['attendedAfter']}/${impactResult['conductedAfter']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                const TextSpan(text: '• Projected %: '),
                TextSpan(
                  text: '${percentageAfter.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSafe ? '✅ Plan looks safe!' : '⚠️ Plan drops you below target!',
            style: TextStyle(fontWeight: FontWeight.bold, color: resultColor),
          ),
          if (!isSafe)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                'Need ~${impactResult['requiredRecovery']} consecutive classes after leave to recover.',
                style: theme.textTheme.bodySmall?.copyWith(color: errorColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProjectionStatBox(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
    IconData icon,
  ) {
    /* ... same as before (with overflow fix) ... */
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: valueColor.withOpacity(0.8), size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                      height: 1.1,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper for placeholder/error text in result areas
  Widget _buildResultPlaceholder(ThemeData theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(fontStyle: FontStyle.italic, color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // --- STYLING HELPERS ---
  InputDecoration _inputDecoration(
    ThemeData theme, {
    String? label,
    String? hint,
    bool isDropdown = false,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: isDarkMode
          ? theme.colorScheme.surface.withOpacity(0.5) // Your dark mode fill
          : Colors.black.withOpacity(0.04), // Subtle grey for light mode
      floatingLabelBehavior: label != null
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.never,
      alignLabelWithHint: true, // Helps align label better when always floating

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        // Add subtle border in light mode, none in dark
        borderSide: isDarkMode
            ? BorderSide.none
            : BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        // Add subtle border in light mode, none in dark
        borderSide: isDarkMode
            ? BorderSide.none
            : BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        // Add subtle indicator on focus
        borderRadius: BorderRadius.circular(12),
        // Keep borderSide none if you prefer fully borderless,
        // or add a subtle primary color border:
        borderSide: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.5),
          width: 1.0,
        ),
      ),
      contentPadding: EdgeInsets.fromLTRB(
        16,
        (label != null ? 20 : 14),
        16,
        (label != null ? 8 : 14),
      ), // Adjust padding based on label presence
    );
  }

  // Consistent styling for main action buttons
  ButtonStyle _elevatedButtonStyle(ThemeData theme) {
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      textStyle: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  // Consistent styling for SegmentedButton
  ButtonStyle _segmentedButtonStyle(ThemeData theme) {
    return SegmentedButton.styleFrom(
      selectedBackgroundColor: theme.colorScheme.primary.withOpacity(0.2),
      selectedForegroundColor: theme.colorScheme.primary,
      // side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)), // Subtle border
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
} // End _PlannerPageState
