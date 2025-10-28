import 'package:flutter/material.dart';
import 'package:attendance_alchemist/models/schedule_entry.dart';
import 'package:attendance_alchemist/services/hive_service.dart';
import 'package:attendance_alchemist/widgets/custom_card.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';
import 'package:provider/provider.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:attendance_alchemist/widgets/banner_ad_widget.dart';
import 'package:attendance_alchemist/services/ad_service.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  List<ScheduleEntry> _schedule = [];
  final Map<int, String> _dayMap = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  void _loadSchedule() {
    setState(() {
      _schedule = HiveService.getSchedule();
    });
  }

  Future<void> _deleteEntry(BuildContext context, ScheduleEntry entry) async {
    FocusScope.of(context).requestFocus(FocusNode());
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
          'Are you sure you want to delete the schedule entry for "${entry.subjectName}"?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(false), // Return false
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(ctx).pop(true), // Return true
          ),
        ],
      ),
    );

    // Only delete if the dialog returned true
    if (confirmed == true) {
      await HiveService.deleteEntry(entry.key);
      _loadSchedule(); // Reload the list after deletion
      showTopToast('Entry deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).requestFocus(FocusNode());
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Class Schedule'),
          // Optional: Add a custom back button that also unfocuses if needed,
          // but WillPopScope usually handles the AppBar back button too.
          // leading: IconButton(
          //   icon: Icon(Icons.arrow_back),
          //   onPressed: () {
          //     FocusScope.of(context).unfocus();
          //     Navigator.of(context).pop();
          //   },
          // ),
        ),
        body: Column(
          // 1. Wrap body content in a Column
          children: [
            Expanded(
              // 2. Make the list/placeholder expand
              child: _schedule.isEmpty
                  ? _buildPlaceholder(context, theme)
                  : _buildScheduleList(context, theme),
            ),
            // 3. Add the Banner Ad at the bottom
            SafeArea(
              // Use SafeArea to avoid system intrusions
              top: false, // Only apply padding to bottom/sides if needed
              child: BannerAdWidget(
                // Use the appropriate Ad Unit ID from your AdService
                adUnitId: AdService
                    .instance
                    .scheduleBannerAdUnitId, // Assuming you have one defined
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showScheduleEntryDialog(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildScheduleList(BuildContext context, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _schedule.length,
      itemBuilder: (context, index) {
        final entry = _schedule[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: CustomCard(
            child: ListTile(
              title: Text(
                entry.subjectName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_dayMap[entry.dayOfWeek]} at ${entry.startTime}',
              ),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                onPressed: () => _deleteEntry(context, entry),
              ),
              onTap: () => _showScheduleEntryDialog(context, entry: entry),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: theme.hintColor),
          const SizedBox(height: 16),
          Text('No Classes Scheduled', style: theme.textTheme.headlineSmall),
          Text(
            'Tap the \'+\' button to add your first class.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  // --- Add/Edit Dialog ---
  Future<void> _showScheduleEntryDialog(
    BuildContext context, {
    ScheduleEntry? entry,
  }) async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final subjectNames = provider.result.subjectStats.keys.toList()..sort();
    final theme = Theme.of(context);
    final formKey = GlobalKey<FormState>();
    final subjectController = TextEditingController(text: entry?.subjectName);
    int selectedDay = entry?.dayOfWeek ?? 1; // Default to Monday
    TimeOfDay? selectedTime = entry != null
        ? TimeOfDay(
            hour: int.parse(entry.startTime.split(':')[0]),
            minute: int.parse(entry.startTime.split(':')[1]),
          )
        : null;
    FocusScope.of(context).requestFocus(FocusNode());

    return showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(entry == null ? 'Add Class' : 'Edit Class'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<String>(
                        initialValue: TextEditingValue(
                          text: entry?.subjectName ?? '',
                        ),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          return subjectNames.where((String option) {
                            return option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            );
                          });
                        },
                        onSelected: (String selection) {
                          subjectController.text = selection;
                          print('Selected: $selection');
                        },
                        // This builds the text field
                        fieldViewBuilder:
                            (
                              BuildContext context,
                              TextEditingController fieldController,
                              FocusNode fieldFocusNode,
                              VoidCallback onFieldSubmitted,
                            ) {
                              // We link our *external* controller here
                              subjectController.text = fieldController.text;

                              return TextFormField(
                                controller: fieldController,
                                focusNode: fieldFocusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Subject Name',
                                  hintText: 'Type to search subjects...',
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a subject name';
                                  }
                                  return null;
                                },
                              );
                            },
                        // This builds the list of suggestions
                        optionsViewBuilder:
                            (
                              BuildContext context,
                              AutocompleteOnSelected<String> onSelected,
                              Iterable<String> options,
                            ) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxHeight: 200,
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: options.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final String option = options
                                                .elementAt(index);
                                            return ListTile(
                                              title: Text(option),
                                              onTap: () {
                                                onSelected(option);
                                              },
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              );
                            },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedDay,
                        decoration: const InputDecoration(
                          labelText: 'Day of Week',
                        ),
                        items: _dayMap.entries
                            .map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedDay = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Start Time'),
                        subtitle: Text(
                          selectedTime == null
                              ? 'Tap to select'
                              : selectedTime!.format(context),
                        ),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (time != null) {
                            setDialogState(() => selectedTime = time);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                FilledButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    FocusScope.of(context).unfocus();
                    if (selectedTime == null) {
                      showErrorToast('Please select a time');
                      return;
                    }
                    if (formKey.currentState!.validate()) {
                      final newEntry = ScheduleEntry()
                        ..subjectName = subjectController.text.trim()
                        ..dayOfWeek = selectedDay
                        ..startTime =
                            '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

                      if (entry == null) {
                        await HiveService.addEntry(newEntry);
                        showTopToast('Class added');
                      } else {
                        await HiveService.updateEntry(entry.key, newEntry);
                        showTopToast('Class updated');
                      }

                      _loadSchedule();
                      Navigator.of(ctx).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
