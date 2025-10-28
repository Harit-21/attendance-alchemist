import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'dart:convert';
import 'package:attendance_alchemist/services/attendance_calculator.dart';
import 'package:attendance_alchemist/helpers/toast_helper.dart';

// --- Helper Classes for Compute ---

class SaveSlot {
  String name;
  String attendanceData;
  int targetPercent;
  String projectionMode;
  int projectionRemainingTime;
  int projectionClassesPerWeek;
  int projectionDaysPerWeek;
  // Add WhatIf and Holiday fields if desired (can get complex)
  // String? whatIfSelectedSubject;
  // String whatIfAction;
  // int whatIfNumClasses;
  // int holidayAttendBefore;
  DateTime timestamp;

  SaveSlot({
    required this.name,
    required this.attendanceData,
    required this.targetPercent,
    required this.projectionMode,
    required this.projectionRemainingTime,
    required this.projectionClassesPerWeek,
    required this.projectionDaysPerWeek,
    required this.timestamp,
  });

  // Method to convert a SaveSlot instance to a Map
  Map<String, dynamic> toJson() => {
    'name': name,
    'attendanceData': attendanceData,
    'targetPercent': targetPercent,
    'projectionMode': projectionMode,
    'projectionRemainingTime': projectionRemainingTime,
    'projectionClassesPerWeek': projectionClassesPerWeek,
    'projectionDaysPerWeek': projectionDaysPerWeek,
    'timestamp': timestamp.toIso8601String(), // Store timestamp as ISO string
  };

  // Factory constructor to create a SaveSlot instance from a Map
  factory SaveSlot.fromJson(Map<String, dynamic> json) => SaveSlot(
    name: json['name'] as String? ?? 'Unnamed Slot', // Provide default name
    attendanceData: json['attendanceData'] as String? ?? '',
    targetPercent: json['targetPercent'] as int? ?? 65,
    projectionMode: json['projectionMode'] as String? ?? 'weeks',
    projectionRemainingTime: json['projectionRemainingTime'] as int? ?? 5,
    projectionClassesPerWeek: json['projectionClassesPerWeek'] as int? ?? 30,
    projectionDaysPerWeek: json['projectionDaysPerWeek'] as int? ?? 6,
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ??
        DateTime.now(), // Handle potential null/invalid date
  );
}

// --- Data Models (Should be top-level or in separate files) ---
class SubjectStatsDetailed {
  final String name;
  double attended; // Total Present + OD
  double conducted;
  double present;
  double od;
  double absent;
  List<AbsenceRecord> absences; // For trend analysis

  SubjectStatsDetailed({
    required this.name,
    this.attended = 0.0,
    this.conducted = 0.0,
    this.present = 0.0,
    this.od = 0.0,
    this.absent = 0.0,
    List<AbsenceRecord>? initialAbsences, // Allow initializing absences
  }) : absences = initialAbsences ?? []; // Use provided list or empty list

  double get percentage => (conducted > 0) ? (attended / conducted) * 100 : 0.0;
}

class AbsenceRecord {
  final DateTime date;
  final double hours;

  AbsenceRecord({required this.date, required this.hours});
}

class CalculationResult {
  final double totalAttended;
  final double totalConducted;
  final double totalPresent;
  final double totalOD;
  final double totalAbsent;
  final double currentPercentage;
  final int maxDroppableHours;
  final int requiredToAttend;
  final Map<String, SubjectStatsDetailed> subjectStats;
  final bool dataParsedSuccessfully;
  final int targetPercentage;
  final int projectionClassesPerWeek; // Keep if used in result display/planner
  final String? fileName;
  final DateTime? timestamp;

  CalculationResult({
    this.totalAttended = 0.0,
    this.totalConducted = 0.0,
    this.totalPresent = 0.0,
    this.totalOD = 0.0,
    this.totalAbsent = 0.0,
    this.currentPercentage = 0.0,
    this.maxDroppableHours = 0,
    this.requiredToAttend = 0,
    this.subjectStats = const {},
    this.dataParsedSuccessfully = false,
    this.targetPercentage = 0,
    this.projectionClassesPerWeek = 0, // Default or pass from provider
    this.fileName,
    this.timestamp,
  });

  // Factory constructor for an empty/error result
  factory CalculationResult.empty() => CalculationResult();

  CalculationResult copyWith({
    double? totalAttended,
    double? totalConducted,
    double? totalPresent,
    double? totalOD,
    double? totalAbsent,
    double? currentPercentage,
    int? maxDroppableHours,
    int? requiredToAttend,
    Map<String, SubjectStatsDetailed>? subjectStats,
    bool? dataParsedSuccessfully,
    int? targetPercentage,
    int? projectionClassesPerWeek,
    String? fileName,
    DateTime? timestamp,
  }) {
    return CalculationResult(
      totalAttended: totalAttended ?? this.totalAttended,
      totalConducted: totalConducted ?? this.totalConducted,
      totalPresent: totalPresent ?? this.totalPresent,
      totalOD: totalOD ?? this.totalOD,
      totalAbsent: totalAbsent ?? this.totalAbsent,
      currentPercentage: currentPercentage ?? this.currentPercentage,
      maxDroppableHours: maxDroppableHours ?? this.maxDroppableHours,
      requiredToAttend: requiredToAttend ?? this.requiredToAttend,
      subjectStats: subjectStats ?? this.subjectStats,
      dataParsedSuccessfully:
          dataParsedSuccessfully ?? this.dataParsedSuccessfully,
      targetPercentage: targetPercentage ?? this.targetPercentage,
      projectionClassesPerWeek:
          projectionClassesPerWeek ?? this.projectionClassesPerWeek,
      fileName: fileName ?? this.fileName,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

// --- AttendanceProvider Class ---
class AttendanceProvider extends ChangeNotifier {
  String _rawData = "";
  String get rawData => _rawData;

  bool _overlayShownThisSession = false;
  bool get overlayShownThisSession => _overlayShownThisSession;

  int _targetPercentage = 65;
  int get targetPercentage => _targetPercentage;

  CalculationResult _result =
      CalculationResult.empty(); // Use factory constructor
  CalculationResult get result => _result;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _fileName;
  String? get fileName => _fileName;

  // --- Planner State ---
  int _plannerFutureClassesToAttend = 0;
  int get plannerFutureClassesToAttend => _plannerFutureClassesToAttend;
  String _projectionMode = 'weeks';
  String get projectionMode => _projectionMode;
  int _projectionRemainingTime = 5;
  int get projectionRemainingTime => _projectionRemainingTime;
  int _projectionClassesPerWeek = 30;
  int get projectionClassesPerWeek => _projectionClassesPerWeek;
  int _projectionDaysPerWeek = 6;
  int get projectionDaysPerWeek => _projectionDaysPerWeek;
  String? _whatIfSelectedSubject;
  String? get whatIfSelectedSubject => _whatIfSelectedSubject;
  String _whatIfAction = 'attend';
  String get whatIfAction => _whatIfAction;
  int _whatIfNumClasses = 1;
  int get whatIfNumClasses => _whatIfNumClasses;
  Map<String, dynamic>? _whatIfResult;
  Map<String, dynamic>? get whatIfResult => _whatIfResult;
  int _holidayAttendBefore = 0;
  int get holidayAttendBefore => _holidayAttendBefore;
  String _holidayInputMode = 'days';
  String get holidayInputMode => _holidayInputMode;
  int _holidayDays = 1;
  int get holidayDays => _holidayDays;
  // int _holidayClassesPerDay = 4;
  // int get holidayClassesPerDay => _holidayClassesPerDay;
  int _holidayTotalClassesToMiss = 10;
  int get holidayTotalClassesToMiss => _holidayTotalClassesToMiss;
  Map<String, dynamic>? _holidayImpactResult;
  Map<String, dynamic>? get holidayImpactResult => _holidayImpactResult;

  static const String _savesKey =
      'attendanceAppSaves'; // Key for SharedPreferences
  static const int _maxSaves = 2; // Maximum save slots (adjust as needed)
  int get maxSaves => _maxSaves; // Getter for UI

  void markOverlayAsShown() {
    _overlayShownThisSession = true;
    // No need to notify listeners, this doesn't change the UI directly
  }

  void resetOverlayFlag() {
    _overlayShownThisSession = false;
    // No need to notify listeners
  }

  // SLOTNAME RENAME
  Future<void> updateSlotName(String slotId, String newName) async {
    await _initPrefs();
    if (_prefs == null) return;

    final currentSaves = await getAllSaves();
    final savedSlot = currentSaves[slotId];

    if (savedSlot != null) {
      // Only update the name if it has actually changed and is not empty
      final trimmedName = newName.trim();
      if (trimmedName.isNotEmpty && savedSlot.name != trimmedName) {
        savedSlot.name = trimmedName; // Update the name in the existing object
        currentSaves[slotId] =
            savedSlot; // Put the updated object back in the map

        try {
          final String savesJson = jsonEncode(
            currentSaves.map((key, value) => MapEntry(key, value.toJson())),
          );
          await _prefs!.setString(_savesKey, savesJson);
          print("Updated name for slot $slotId to '$trimmedName'");
          showTopToast("✅ Slot renamed to '$trimmedName'");
          // No need to notifyListeners unless the UI displaying the name *outside* the modal needs update
        } catch (e) {
          print("Error encoding or saving after name update: $e");
          showTopToast("❌ Failed to rename slot");
        }
      }
    } else {
      print("Cannot update name: Slot $slotId not found.");
      showTopToast("⚠️ Slot not found");
    }
  }

  // --- Save/Load Slot Logic ---

  Future<Map<String, SaveSlot>> getAllSaves() async {
    await _initPrefs(); // Ensure prefs are initialized
    if (_prefs == null) return {};

    final String? savesJson = _prefs!.getString(_savesKey);
    if (savesJson == null || savesJson.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> decodedMap = jsonDecode(savesJson);

      // --- CORRECTED LOGIC ---
      final Map<String, SaveSlot> validSaves = {};
      decodedMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          try {
            // Try creating SaveSlot, might fail if data inside is corrupted
            validSaves[key] = SaveSlot.fromJson(value);
          } catch (e) {
            print(
              "Warning: Error creating SaveSlot from JSON for key '$key'. Skipping. Error: $e",
            );
          }
        } else {
          // Handle potential data corruption if value is not a map
          print(
            "Warning: Invalid data type found for save slot '$key' (expected Map). Skipping.",
          );
        }
      });
      return validSaves;
      // --- END CORRECTION ---
    } catch (e) {
      print("Error decoding saved slots JSON: $e");
      // await _prefs!.remove(_savesKey); // Optional: clear corrupted data
      return {};
    }
  }

  Future<void> saveToSlot(String slotId, String slotName) async {
    await _initPrefs();
    if (_prefs == null || _rawData.trim().isEmpty) {
      print("Cannot save: Prefs not ready or no data.");
      // Optionally show a message to the user via a new state variable or callback
      return;
    }

    final currentSaves = await getAllSaves();
    final saveData = SaveSlot(
      name: slotName.trim().isNotEmpty
          ? slotName.trim()
          : slotId.replaceFirst(
              'slot',
              'Save Slot ',
            ), // Use input name or default
      attendanceData: _rawData,
      targetPercent: _targetPercentage,
      projectionMode: _projectionMode,
      projectionRemainingTime: _projectionRemainingTime,
      projectionClassesPerWeek: _projectionClassesPerWeek,
      projectionDaysPerWeek: _projectionDaysPerWeek,
      timestamp: DateTime.now(),
    );

    currentSaves[slotId] = saveData;

    try {
      final String savesJson = jsonEncode(
        currentSaves.map((key, value) => MapEntry(key, value.toJson())),
      );
      await _prefs!.setString(_savesKey, savesJson);
      print("Saved data to slot $slotId with name '$slotName'");
      notifyListeners(); // Notify UI to potentially update save list timestamps
    } catch (e) {
      print("Error encoding or saving slots: $e");
      // Optionally show an error message
    }
  }

  Future<bool> loadFromSlot(String slotId) async {
    await _initPrefs();
    if (_prefs == null) return false;

    final currentSaves = await getAllSaves();
    final savedSlot = currentSaves[slotId];

    if (savedSlot != null) {
      _targetPercentage = savedSlot.targetPercent;
      _projectionMode = savedSlot.projectionMode;
      _projectionRemainingTime = savedSlot.projectionRemainingTime;
      _projectionClassesPerWeek = savedSlot.projectionClassesPerWeek;
      _projectionDaysPerWeek = savedSlot.projectionDaysPerWeek;
      _errorMessage = null;
      _whatIfResult = null;
      _holidayImpactResult = null;
      _result = CalculationResult.empty(); // Reset result object

      // Use setRawData to update data and trigger recalculation
      setRawData(
        savedSlot.attendanceData,
        newFileName: savedSlot.name,
      ); // Pass name as filename
      print("Loaded data from slot $slotId ('${savedSlot.name}')");
      return true;
    } else {
      print("Could not find data for slot $slotId");
      return false;
    }
  }

  Future<void> deleteSlot(String slotId) async {
    await _initPrefs();
    if (_prefs == null) return;

    final currentSaves = await getAllSaves();
    if (currentSaves.containsKey(slotId)) {
      currentSaves.remove(slotId);
      try {
        final String savesJson = jsonEncode(
          currentSaves.map((key, value) => MapEntry(key, value.toJson())),
        );
        await _prefs!.setString(_savesKey, savesJson);
        print("Deleted slot $slotId");
        notifyListeners(); // Update UI
      } catch (e) {
        print("Error encoding or saving after delete: $e");
      }
    }
  }

  // --- Planner Getters ---
  int get projectionTotalRemainingClasses {
    if (_projectionMode == 'weeks') {
      return _projectionRemainingTime * _projectionClassesPerWeek;
    } else {
      // days
      if (_projectionDaysPerWeek > 0) {
        final avgClassesPerDay =
            _projectionClassesPerWeek / _projectionDaysPerWeek;
        return (_projectionRemainingTime * avgClassesPerDay).round().clamp(
          0,
          99999,
        );
      }
      return 0;
    }
  }

  int get projectionRequiredAttendance {
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0) return 0;
    final double targetDecimal = _targetPercentage / 100.0;
    if (targetDecimal <= 0 || targetDecimal >= 1)
      return projectionTotalRemainingClasses;
    final totalFutureConducted =
        result.totalConducted + projectionTotalRemainingClasses;
    if (totalFutureConducted <= 0) return 0;
    final totalRequiredOverall = (totalFutureConducted * targetDecimal)
        .ceilToDouble();
    final needed = totalRequiredOverall - result.totalAttended;
    return needed
        .clamp(0.0, projectionTotalRemainingClasses.toDouble())
        .toInt();
  }

  int get projectionAllowedSkips {
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0) return 0;
    final remaining = projectionTotalRemainingClasses;
    final requiredToAttend = projectionRequiredAttendance;
    return (remaining - requiredToAttend).clamp(0, remaining);
  }

  double get projectionFinalPercentage {
    if (!result.dataParsedSuccessfully || result.totalConducted <= 0)
      return 0.0;
    final finalConducted =
        result.totalConducted + projectionTotalRemainingClasses;
    if (finalConducted <= 0) return result.currentPercentage;
    final finalAttended = result.totalAttended + projectionRequiredAttendance;
    return (finalAttended / finalConducted * 100).clamp(0.0, 100.0);
  }

  double get calculatedAvgClassesPerDay {
    if (_projectionDaysPerWeek > 0 && _projectionClassesPerWeek > 0) {
      return _projectionClassesPerWeek / _projectionDaysPerWeek;
    }
    return 0.0; // Return 0 if inputs are invalid
  }

  SharedPreferences? _prefs;

  AttendanceProvider() {
    // Load SharedPreferences async when provider is created
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    // Optionally load last saved data here if resume isn't handled at launch
  }

  void updateRawDataWithoutCalc(String data) {
    if (_rawData != data) {
      _rawData = data;
      // We ONLY notify listeners so the TextField reflects changes
      // if it's driven directly by the provider state (less common).
      // Usually, the controller handles TextField updates.
      // We might not even need notifyListeners() here if the TextField
      // is the primary source of truth during typing.
      // Let's keep it commented out unless needed:
      // notifyListeners();
    }
  }

  // --- Update Methods ---
  void setRawData(String data, {String? newFileName}) {
    // Trim whitespace, normalize line endings
    _rawData = data.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    _fileName =
        (newFileName != null &&
            newFileName != 'Pasted from clipboard' &&
            _rawData.isNotEmpty)
        ? newFileName
        : null; // Keep filename only if data is not empty and not pasted
    _errorMessage = null;
    _whatIfResult = null; // Clear planner results on new data
    _holidayImpactResult = null;

    // Trigger calculation immediately after setting data
    if (_rawData.isNotEmpty) {
      calculateHours();
    } else {
      // If data is cleared, reset result and notify
      _result = CalculationResult.empty();
      notifyListeners();
    }
  }

  void setTargetPercentage(int newTarget) {
    if (newTarget >= 0 && newTarget <= 100 && newTarget != _targetPercentage) {
      _targetPercentage = newTarget;
      _whatIfResult = null; // Clear planner results on target change
      _holidayImpactResult = null;
      if (_rawData.isNotEmpty && result.dataParsedSuccessfully) {
        calculateHours(); // Recalculate if valid data exists
      } else {
        saveData();
        notifyListeners(); // Just update UI for target change
      }
    }
  }

  void setPlannerFutureClasses(int value) {
    final newValue = value.clamp(0, 9999);
    if (_plannerFutureClassesToAttend != newValue) {
      _plannerFutureClassesToAttend = newValue;
      notifyListeners();
    }
  }

  void setProjectionMode(String mode) {
    if ((mode == 'weeks' || mode == 'days') && _projectionMode != mode) {
      _projectionMode = mode;
      notifyListeners();
    }
  }

  void setProjectionRemainingTime(int value) {
    final newValue = value.clamp(1, 999);
    if (_projectionRemainingTime != newValue) {
      _projectionRemainingTime = newValue;
      notifyListeners();
    }
  }

  void setProjectionClassesPerWeek(int value) {
    final newValue = value.clamp(1, 999);
    if (_projectionClassesPerWeek != newValue) {
      _projectionClassesPerWeek = newValue;
      if (_projectionMode == 'days' && _projectionDaysPerWeek > newValue) {
        _projectionDaysPerWeek = newValue.clamp(1, 7);
      }
      notifyListeners();
    }
  }

  void setProjectionDaysPerWeek(int value) {
    final newValue = value.clamp(1, 7);
    final clampedValue = newValue.clamp(1, _projectionClassesPerWeek);
    if (_projectionDaysPerWeek != clampedValue) {
      _projectionDaysPerWeek = clampedValue;
      notifyListeners();
    }
  }

  void setWhatIfSubject(String? subjectName) {
    if (_whatIfSelectedSubject != subjectName) {
      _whatIfSelectedSubject = subjectName;
      _whatIfResult = null; // Clear result
      notifyListeners();
    }
  }

  void setWhatIfAction(String action) {
    if ((action == 'attend' || action == 'miss') && _whatIfAction != action) {
      _whatIfAction = action;
      _whatIfResult = null; // Clear result
      notifyListeners();
    }
  }

  void setWhatIfNumClasses(int value) {
    final newValue = value.clamp(1, 999);
    if (_whatIfNumClasses != newValue) {
      _whatIfNumClasses = newValue;
      _whatIfResult = null; // Clear result
      notifyListeners();
    }
  }

  void setHolidayAttendBefore(int value) {
    final newValue = value.clamp(0, 9999);
    if (_holidayAttendBefore != newValue) {
      _holidayAttendBefore = newValue;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  void setHolidayInputMode(String mode) {
    if ((mode == 'days' || mode == 'classes') && _holidayInputMode != mode) {
      _holidayInputMode = mode;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  void setHolidayDays(int value) {
    final newValue = value.clamp(1, 365);
    if (_holidayDays != newValue) {
      _holidayDays = newValue;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  // void setHolidayClassesPerDay(int value) {
  //   final newValue = value.clamp(1, 99);
  //   if (_holidayClassesPerDay != newValue) {
  //     _holidayClassesPerDay = newValue;
  //     _holidayImpactResult = null;
  //     notifyListeners();
  //   }
  // }

  void setHolidayTotalClassesToMiss(int value) {
    final newValue = value.clamp(1, 9999);
    if (_holidayTotalClassesToMiss != newValue) {
      _holidayTotalClassesToMiss = newValue;
      _holidayImpactResult = null;
      notifyListeners();
    }
  }

  // --- Calculation Method using Compute ---
  Future<void> calculateHours() async {
    // Changed to Future<void>
    if (_rawData.trim().isEmpty) {
      // Don't set error if just cleared, handle gracefully
      if (_result.dataParsedSuccessfully || _errorMessage != null) {
        // Only reset if there was previous data/error
        _result = CalculationResult.empty();
        _errorMessage = null;
        notifyListeners();
      }
      return;
    }
    if (_isLoading) return; // Prevent concurrent calculations

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Show loading indicator immediately

    // Prepare input for the compute function
    final computeInput = ComputeInput(
      rawData: _rawData,
      targetPercentage: _targetPercentage,
      // Pass other relevant state if needed by _performCalculation
      // projectionClassesPerWeek: _projectionClassesPerWeek,
    );

    try {
      // Run the calculation in an isolate
      final calcOutput = await compute(performCalculation, computeInput);

      // Check if data or target changed *while* compute was running
      if (_rawData != computeInput.rawData ||
          _targetPercentage != computeInput.targetPercentage) {
        debugPrint(
          "Data/Target changed during compute. Ignoring stale result.",
        );
        // Don't update state, another calculation might be pending
        // Ensure loading is false if no new calc starts immediately
        if (_isLoading) {
          _isLoading = false;
          // Don't notify yet, let the potential new calculation handle it
        }
        return;
      }

      // Update state with the result from the isolate
      _isLoading = false;
      _result = calcOutput.result.copyWith(
        // Use copyWith if available, otherwise manual update
        targetPercentage: _targetPercentage, // Ensure result has current target
        projectionClassesPerWeek:
            _projectionClassesPerWeek, // Pass current projection
        fileName: _fileName, // Update filename in result
        timestamp: DateTime.now(),
      );
      _errorMessage = calcOutput.errorMessage;

      // Clear planner results if main calculation failed
      if (_errorMessage != null) {
        _whatIfResult = null;
        _holidayImpactResult = null;
      } else {
        // *** SAVE DATA on successful calculation ***
        await saveData(); // Call save data here
      }
      notifyListeners(); // Update UI with final result or error
    } catch (error) {
      // Catch errors thrown by compute itself (rare)
      _isLoading = false;
      _result = CalculationResult.empty();
      _errorMessage =
          "An unexpected isolate error occurred: ${error.toString()}";
      _whatIfResult = null; // Clear planner results on error
      _holidayImpactResult = null;
      debugPrint("Compute Isolate Error: $_errorMessage");
      notifyListeners();
    }
  }

  Future<void> saveData() async {
    await _initPrefs(); // Ensure prefs are initialized
    if (_prefs == null) {
      debugPrint("SharedPreferences not initialized, cannot save.");
      return;
    }
    await _prefs!.setString('lastRawData', _rawData);
    await _prefs!.setInt('lastTargetPercentage', _targetPercentage);
    debugPrint("Data Saved. Target: $_targetPercentage");
  }

  Future<bool> loadSavedData() async {
    await _initPrefs(); // Ensure prefs are initialized
    if (_prefs == null) {
      debugPrint("SharedPreferences not initialized, cannot load.");
      return false;
    }

    final savedData = _prefs!.getString('lastRawData');
    final savedTarget = _prefs!.getInt('lastTargetPercentage');

    if (savedData != null && savedData.isNotEmpty) {
      _rawData = savedData;
      _targetPercentage =
          savedTarget ??
          _targetPercentage; // Use saved target or keep current if null
      _fileName = "Last Saved Session"; // Indicate loaded data source
      _errorMessage = null; // Clear any previous errors
      _whatIfResult = null; // Clear previous planner results
      _holidayImpactResult = null;
      debugPrint("Data Loaded. Target: $_targetPercentage");
      calculateHours(); // Calculate loaded data
      return true; // Indicate success
    } else {
      debugPrint("No saved data found.");
      return false; // Indicate no data loaded
    }
  }

  // --- Clear Data Method ---
  Future<void> clearData() async {
    _rawData = "";
    _fileName = null;
    _errorMessage = null;
    _result = CalculationResult.empty();
    _whatIfResult = null;
    _holidayImpactResult = null;
    _plannerFutureClassesToAttend = 0; // Reset relevant planner state
    // Optionally reset other planner inputs?
    // _projectionRemainingTime = 5;
    // _projectionClassesPerWeek = 30;

    // Also clear saved data from storage
    await _initPrefs();
    await _prefs?.remove('lastRawData');
    await _prefs?.remove('lastTargetPercentage');
    debugPrint("Data Cleared (Provider & Storage).");

    notifyListeners();
  }

  // --- Planner Calculation Methods (Run on Main Thread - Quick Ops) ---

  /// Calculates the result for the "What If I attend..." section.
  Map<String, dynamic> calculateCustomMissable() {
    if (!result.dataParsedSuccessfully ||
        result.totalConducted <= 0 ||
        _plannerFutureClassesToAttend <= 0) {
      return {'canCalculate': false};
    }
    final double targetDecimal = _targetPercentage / 100.0;
    final tempAttended = result.totalAttended + _plannerFutureClassesToAttend;
    final tempConducted = result.totalConducted + _plannerFutureClassesToAttend;
    if (targetDecimal <= 0 || targetDecimal >= 1 || tempConducted <= 0) {
      return {'canCalculate': false, 'error': 'Invalid target or data.'};
    }
    final numerator = tempAttended - (targetDecimal * tempConducted);
    final maxSkips = (numerator / targetDecimal).floor();
    if (maxSkips < 0) {
      final finalPercent = tempConducted > 0
          ? (tempAttended / tempConducted * 100)
          : 0.0;
      return {
        'canCalculate': true,
        'isSafe': false,
        'message':
            '⚠️ Even after attending $_plannerFutureClassesToAttend more class(es) (reaching ${finalPercent.toStringAsFixed(1)}%), you still cannot reach the $_targetPercentage% target by skipping classes later.',
      };
    } else {
      final projectedConducted = tempConducted + maxSkips;
      final projectedAttended = tempAttended;
      final projectedPercent = (projectedAttended / projectedConducted) * 100;
      return {
        'canCalculate': true,
        'isSafe': true,
        'skipsAllowed': maxSkips,
        'originalSkips': result.maxDroppableHours,
        'projectedAttended': projectedAttended.round(),
        'projectedConducted': projectedConducted.round(),
        'projectedPercent': projectedPercent,
      };
    }
  }

  /// Runs the simulation for the Advanced What-If planner.
  void runWhatIfSimulation() {
    _whatIfResult = null;
    notifyListeners();

    if (!result.dataParsedSuccessfully ||
        result.totalConducted <= 0 ||
        result.subjectStats.isEmpty ||
        _whatIfSelectedSubject == null ||
        _whatIfNumClasses <= 0) {
      _whatIfResult = {
        'error': 'Select a subject and enter a valid number of classes (> 0).',
      };
      notifyListeners();
      return;
    }

    final SubjectStatsDetailed? originalSubject =
        result.subjectStats[_whatIfSelectedSubject!];
    if (originalSubject == null || originalSubject.conducted <= 0) {
      _whatIfResult = {
        'error': 'Selected subject has invalid data (conducted hours <= 0).',
      };
      notifyListeners();
      return;
    }

    final originalSubjectPercent = originalSubject.percentage;
    final originalOverallPercent = result.currentPercentage;

    double simAttended = result.totalAttended;
    double simConducted = result.totalConducted;
    double simSubjectAttended = originalSubject.attended;
    double simSubjectConducted = originalSubject.conducted;

    if (_whatIfAction == 'attend') {
      simAttended += _whatIfNumClasses;
      simConducted += _whatIfNumClasses;
      simSubjectAttended += _whatIfNumClasses;
      simSubjectConducted += _whatIfNumClasses;
    } else {
      // miss
      simConducted += _whatIfNumClasses;
      simSubjectConducted += _whatIfNumClasses;
    }

    final double newSubjectPercent = (simSubjectConducted > 0)
        ? (simSubjectAttended / simSubjectConducted * 100)
        : 0.0;
    final double newOverallPercent = (simConducted > 0)
        ? (simAttended / simConducted * 100)
        : 0.0;

    _whatIfResult = {
      'subjectName': _whatIfSelectedSubject,
      'action': _whatIfAction,
      'numClasses': _whatIfNumClasses,
      'originalSubjectPercent': originalSubjectPercent,
      'newSubjectPercent': newSubjectPercent,
      'originalOverallPercent': originalOverallPercent,
      'newOverallPercent': newOverallPercent,
      'isAboveTarget': newOverallPercent >= _targetPercentage,
    };
    notifyListeners();
  }

  /// Calculates the impact of a planned holiday/leave.
  void calculateHolidayImpact() {
    _holidayImpactResult = null;
    notifyListeners();

    if (!result.dataParsedSuccessfully || result.totalConducted <= 0) {
      _holidayImpactResult = {'error': 'Calculate current attendance first.'};
      notifyListeners();
      return;
    }

    int totalMissedClasses = 0;
    String leaveDescription = "";
    double avgClassesPerDay = calculatedAvgClassesPerDay;

    if (_holidayInputMode == 'days') {
      if (_holidayDays <= 0 || avgClassesPerDay <= 0) {
        _holidayImpactResult = {
          'error': 'Enter valid positive numbers for days and classes/day.',
        };
        notifyListeners();
        return;
      }
      totalMissedClasses = (_holidayDays * avgClassesPerDay).round();
      leaveDescription =
          "$_holidayDays-day leave (~$totalMissedClasses classes @ ${avgClassesPerDay.toStringAsFixed(1)}/day)";
    } else {
      // classes mode
      if (_holidayTotalClassesToMiss <= 0) {
        _holidayImpactResult = {
          'error': 'Enter a valid positive number for total classes to miss.',
        };
        notifyListeners();
        return;
      }
      totalMissedClasses = _holidayTotalClassesToMiss;
      leaveDescription = "a leave missing $totalMissedClasses classes";
    }

    if (_holidayAttendBefore < 0) {
      // Should be prevented by setter, but double-check
      _holidayImpactResult = {
        'error': 'Classes to attend before leave cannot be negative.',
      };
      notifyListeners();
      return;
    }

    final attendedAfterExtra = result.totalAttended + _holidayAttendBefore;
    final conductedAfterExtra = result.totalConducted + _holidayAttendBefore;
    final conductedAfterHoliday = conductedAfterExtra + totalMissedClasses;
    final attendedAfterHoliday = attendedAfterExtra;

    if (conductedAfterHoliday <= 0) {
      _holidayImpactResult = {
        'error': 'Calculation resulted in invalid conducted hours.',
      };
      notifyListeners();
      return;
    }

    final double percentageAfterHoliday =
        (attendedAfterHoliday / conductedAfterHoliday * 100);
    final bool isSafe = percentageAfterHoliday >= _targetPercentage;
    int requiredRecoveryClasses = 0;

    if (!isSafe) {
      final double targetDecimal = _targetPercentage / 100.0;
      if (targetDecimal <= 0 || targetDecimal >= 1) {
        // Safety check
        requiredRecoveryClasses = 99999;
      } else {
        final deficit =
            (targetDecimal * conductedAfterHoliday) - attendedAfterHoliday;
        if (1 - targetDecimal > 0) {
          requiredRecoveryClasses = (deficit / (1 - targetDecimal))
              .ceil()
              .clamp(0, 99999); // Clamp recovery
        } else {
          requiredRecoveryClasses = 99999; // Unreachable
        }
      }
    }

    _holidayImpactResult = {
      'attendBefore': _holidayAttendBefore,
      'leaveDescription': leaveDescription,
      'attendedAfter': attendedAfterHoliday.round(),
      'conductedAfter': conductedAfterHoliday.round(),
      'percentageAfter': percentageAfterHoliday,
      'isSafe': isSafe,
      'requiredRecovery': requiredRecoveryClasses,
    };
    notifyListeners();
  }
} // End Provider Class
