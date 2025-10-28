import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';

class SavesModal extends StatefulWidget {
  const SavesModal({super.key});

  @override
  State<SavesModal> createState() => _SavesModalState();
}

class _SavesModalState extends State<SavesModal> {
  late Future<Map<String, SaveSlot>> _savesFuture;
  Map<String, TextEditingController> _nameControllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  @override
  void initState() {
    super.initState();
    _loadSaves();
  }

  void _loadSaves() {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    _savesFuture = provider.getAllSaves().then((saves) {
      _nameControllers.values.forEach((controller) => controller.dispose());
      _focusNodes.values.forEach((node) => node.dispose());
      _nameControllers.clear();
      _focusNodes.clear();

      // Create new ones
      for (var i = 1; i <= provider.maxSaves; i++) {
        final slotId = 'slot$i';
        final initialName = saves[slotId]?.name ?? 'Save Slot $i';
        _nameControllers[slotId] = TextEditingController(text: initialName);
        _focusNodes[slotId] = FocusNode();

        // --- Add listener to save name on focus loss ---
        _focusNodes[slotId]?.addListener(() {
          final node = _focusNodes[slotId];
          final controller = _nameControllers[slotId];
          if (node != null && !node.hasFocus && controller != null) {
            // Only save if focus is lost
            provider.updateSlotName(slotId, controller.text);
            // Note: We don't call _refreshSavesList here unless the timestamp needs updating visually on name save
          }
        });
        // --- End listener ---
      }
      return saves;
    });
  }

  @override
  void dispose() {
    // Dispose all text controllers when the modal is closed
    _nameControllers.values.forEach((controller) => controller.dispose());
    _focusNodes.values.forEach((node) => node.dispose());
    super.dispose();
  }

  void _refreshSavesList() {
    setState(() {
      _loadSaves(); // Re-trigger the future builder
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>(); // Watch for changes
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Padding(
      // Padding for safe area and content
      padding: EdgeInsets.only(
        top: 20,
        left: 16,
        right: 16,
        bottom:
            MediaQuery.of(context).viewInsets.bottom +
            16, // Adjust for keyboard
      ),
      child: SingleChildScrollView(
        // Allow scrolling if content overflows
        child: Column(
          mainAxisSize: MainAxisSize.min, // Take only needed height
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🗂️ Manage Saves', style: theme.textTheme.headlineSmall),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // FutureBuilder to load and display saves
            FutureBuilder<Map<String, SaveSlot>>(
              future: _savesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading saves: ${snapshot.error}'),
                  );
                }

                final saves = snapshot.data ?? {};

                // Build list of save slots
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.maxSaves,
                  itemBuilder: (context, index) {
                    final slotId = 'slot${index + 1}';
                    final savedSlot = saves[slotId];
                    final nameController = _nameControllers[slotId];
                    //  ??
                    // TextEditingController(text: 'Save Slot ${index + 1}');
                    final focusNode = _focusNodes[slotId];
                    final bool hasDataInSlot = savedSlot != null;
                    final String lastSaved = hasDataInSlot
                        ? DateFormat.yMd().add_jm().format(
                            savedSlot.timestamp.toLocal(),
                          ) // Format timestamp nicely
                        : 'Empty';

                    if (nameController == null || focusNode == null) {
                      return const SizedBox.shrink(); // Or some error widget
                    }

                    return Card(
                      // Use Card for better visual separation
                      margin: const EdgeInsets.symmetric(vertical: 6.0),
                      elevation: hasDataInSlot ? 2 : 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Name and Timestamp
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: nameController,
                                    focusNode: focusNode,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Slot Name',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    // Optionally save name on focus loss or via a dedicated button
                                  ),
                                  Text(
                                    'Last Saved: $lastSaved',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Action Buttons
                            Row(
                              mainAxisSize:
                                  MainAxisSize.min, // Take minimal space
                              children: [
                                // Save Button
                                IconButton(
                                  icon: const Icon(Icons.save_alt_rounded),
                                  tooltip: 'Save Current Data Here',
                                  color: theme.colorScheme.primary,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: provider.rawData.trim().isEmpty
                                      ? null
                                      : () async {
                                          // Disable if no current data
                                          final currentName =
                                              nameController.text;
                                          await provider.saveToSlot(
                                            slotId,
                                            currentName,
                                          );
                                          showTopToast(
                                            '💾 Saved to "$currentName"',
                                            backgroundColor: Colors
                                                .green
                                                .shade600
                                                .withOpacity(0.9),
                                          );
                                          _refreshSavesList(); // Refresh list to show new timestamp/buttons
                                        },
                                ),
                                // Load Button
                                IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  tooltip: 'Load Data From Here',
                                  color: hasDataInSlot
                                      ? Colors.green.shade600
                                      : theme.disabledColor,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !hasDataInSlot
                                      ? null
                                      : () async {
                                          // Disable if slot is empty
                                          bool loaded = await provider
                                              .loadFromSlot(slotId);
                                          Navigator.pop(
                                            context,
                                          ); // Close modal after loading
                                          if (loaded) {
                                            showTopToast(
                                              '📂 Loaded "${savedSlot?.name ?? slotId}"',
                                              backgroundColor: Colors
                                                  .green
                                                  .shade600
                                                  .withOpacity(0.9),
                                            );
                                          } else {
                                            showTopToast(
                                              '❌ Failed to load data from slot.',
                                              backgroundColor:
                                                  Colors.red.shade700,
                                            );
                                          }
                                        },
                                ),
                                // Delete Button
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  tooltip: 'Delete This Save',
                                  color: hasDataInSlot
                                      ? Colors.red.shade400
                                      : theme.disabledColor,
                                  iconSize: 20,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: !hasDataInSlot
                                      ? null
                                      : () async {
                                          // Disable if slot is empty
                                          bool?
                                          confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text(
                                                'Confirm Delete',
                                              ),
                                              content: Text(
                                                'Delete save slot "${nameController.text}"?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(ctx, true),
                                                  child: const Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await provider.deleteSlot(slotId);
                                            showTopToast(
                                              '🗑️ Deleted "${nameController.text}"',
                                              backgroundColor: Colors
                                                  .red
                                                  .shade600
                                                  .withOpacity(0.9),
                                            );
                                            _refreshSavesList(); // Refresh list
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            // --- Premium Upsell (Optional) ---
            // if (!isPremium) ... [
            //   const SizedBox(height: 16),
            //   Text(
            //     '👑 Upgrade to Premium to unlock ${provider.maxSaves - 1} more save slots!',
            //     textAlign: TextAlign.center,
            //     style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            //   ),
            //   // Add Upgrade Button here if desired
            // ],
          ],
        ),
      ),
    );
  }
}
