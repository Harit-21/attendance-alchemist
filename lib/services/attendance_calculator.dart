import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:attendance_alchemist/providers/attendance_provider.dart'; // We need this for CalculationResult, etc.

/// Helper class to pass input data to the compute isolate
class ComputeInput {
  final String rawData;
  final int targetPercentage;

  ComputeInput({required this.rawData, required this.targetPercentage});
}

/// Helper class to return multiple values from the compute isolate
class CalculationOutput {
  final CalculationResult result;
  final String? errorMessage;
  final String? fileName;

  CalculationOutput(this.result, this.errorMessage, {this.fileName});
}

/// Top-level function to intelligently detect format and parse data.
/// Throws an Exception if parsing fails or format is unknown.
Map<String, SubjectStatsDetailed> parseDataTopLevel(String textData) {
  final lines = textData
      .split('\n')
      .map((line) => line.trim().replaceAll('\r', ''))
      .where((line) => line.isNotEmpty)
      .toList();
  final headerRowIndex = lines.indexWhere(
    (line) => line.toLowerCase().contains('subject'),
  );

  if (headerRowIndex == -1) {
    throw Exception("Could not find a header row containing 'Subject'.");
  }

  final relevantLines = lines.sublist(headerRowIndex);
  if (relevantLines.length < 2) {
    // Need header + at least one data row
    throw Exception(
      "Data must contain at least one data row below the identified header.",
    );
  }
  // Now, the header is guaranteed to be at index 0 within relevantLines
  final headerLine = relevantLines[0];
  final headerLower = headerLine.toLowerCase();

  final bool isRawLog =
      headerLower.contains('date') && headerLower.contains('marked');
  final bool isAggregated =
      headerLower.contains('present') && headerLower.contains('absent');

  Map<String, SubjectStatsDetailed>? parsedStats;

  if (isRawLog) {
    debugPrint("Top-Level: Raw log data detected.");
    // --- MODIFICATION: Pass relevantLines and header index 0 ---
    parsedStats = parseRawLogDataTopLevel(relevantLines, 0);
  } else if (isAggregated) {
    debugPrint("Top-Level: Aggregated report detected.");
    // --- MODIFICATION: Pass relevantLines and header index 0 ---
    parsedStats = parseAggregatedDataTopLevel(relevantLines, 0);
  } else {
    // Fallback logic also needs modification
    if (headerLower.contains('subject')) {
      debugPrint("Top-Level: Ambiguous headers, attempting aggregated parse.");
      try {
        // --- MODIFICATION: Pass relevantLines and header index 0 ---
        parsedStats = parseAggregatedDataTopLevel(relevantLines, 0);
      } catch (aggError) {
        debugPrint(
          "Top-Level: Aggregated parse failed ($aggError), attempting raw log parse as fallback.",
        );
        try {
          // --- MODIFICATION: Pass relevantLines and header index 0 ---
          parsedStats = parseRawLogDataTopLevel(relevantLines, 0);
        } catch (rawError) {
          throw Exception(
            "Could not determine data format after attempting both parses. Aggregated Error: $aggError, Raw Error: $rawError",
          );
        }
      }
    } else {
      throw Exception(
        "Could not determine data format. No 'Subject' header found and specific keywords missing.",
      );
    }
  }

  // Check result after parsing attempts
  if (parsedStats == null || parsedStats.isEmpty) {
    throw Exception("Parsing completed but yielded no valid subject data.");
  }

  return parsedStats;
}

/// Top-level function to find header index. Returns -1 if not found.
int findHeaderIndexTopLevel(
  List<String> headers,
  List<String> primaryTerms, {
  List<String> secondaryTerms = const [],
  List<String> exclusionTerms = const [],
}) {
  // 1. Exact primary match (case-insensitive, trimmed)
  for (final term in primaryTerms) {
    final exactIndex = headers.indexWhere(
      (h) => h.trim().toLowerCase() == term.toLowerCase(),
    );
    if (exactIndex > -1) return exactIndex;
  }
  // 2. Partial match containing primary term (excluding exclusions)
  final potentialPrimaryMatches = <int>[];
  for (int i = 0; i < headers.length; i++) {
    final header = headers[i].trim().toLowerCase();
    final bool hasPrimary = primaryTerms.any(
      (pTerm) => header.contains(pTerm.toLowerCase()),
    );
    final bool hasExclusion = exclusionTerms.any(
      (term) => header.contains(term.toLowerCase()),
    );
    if (hasPrimary && !hasExclusion) potentialPrimaryMatches.add(i);
  }
  if (potentialPrimaryMatches.isNotEmpty) {
    potentialPrimaryMatches.sort(
      (a, b) => headers[a].length.compareTo(headers[b].length),
    );
    return potentialPrimaryMatches.first;
  }
  // 3. Fallback: Broad secondary term match (excluding exclusions)
  if (secondaryTerms.isNotEmpty) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].trim().toLowerCase();
      final bool hasSecondary = secondaryTerms.any(
        (term) => header.contains(term.toLowerCase()),
      );
      final bool hasExclusion = exclusionTerms.any(
        (term) => header.contains(term.toLowerCase()),
      );
      if (hasSecondary && !hasExclusion) return i;
    }
  }
  return -1;
}

/// Top-level function to parse Raw Log Data. Throws Exception on critical errors.
Map<String, SubjectStatsDetailed> parseRawLogDataTopLevel(
  List<String> lines,
  int headerRowIndex,
) {
  final splitter = RegExp(r'\t| {2,}|,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
  final headers = lines[headerRowIndex]
      .split(splitter)
      .map((h) => h.trim().replaceAll('"', ''))
      .toList();

  final subjectIndex = findHeaderIndexTopLevel(
    headers,
    ['subject name', 'subject'],
    secondaryTerms: ['subject'],
    exclusionTerms: ['code'],
  );
  final dateIndex = findHeaderIndexTopLevel(
    headers,
    ['date'],
    secondaryTerms: ['date'],
  );
  final hoursIndex = findHeaderIndexTopLevel(
    headers,
    ['number of hours', 'hours'],
    secondaryTerms: ['hour'],
  );
  final markedIndex = findHeaderIndexTopLevel(
    headers,
    ['marked'],
    secondaryTerms: ['marked', 'status'],
  );

  if ([subjectIndex, dateIndex, hoursIndex, markedIndex].contains(-1)) {
    throw Exception(
      "Raw Log Parse Error: Could not find required columns. Subject(${subjectIndex != -1}), Date(${dateIndex != -1}), Hours(${hoursIndex != -1}), Marked(${markedIndex != -1}). Headers: ${headers.join(', ')}",
    );
  }

  final subjectStats = <String, SubjectStatsDetailed>{};
  final dataLines = lines.sublist(headerRowIndex + 1);
  final dateFormats = [
    // Prioritize common formats first
    DateFormat("dd-MM-yyyy"), DateFormat("d-M-yyyy"),
    DateFormat("MM/dd/yyyy"), DateFormat("M/d/yyyy"),
    DateFormat("yyyy-MM-dd"),
  ];

  for (final line in dataLines) {
    final values = line
        .split(splitter)
        .map((v) => v.trim().replaceAll('"', ''))
        .toList();
    final maxIndex = [
      subjectIndex,
      dateIndex,
      hoursIndex,
      markedIndex,
    ].reduce((a, b) => a > b ? a : b);
    if (values.length <= maxIndex) continue;

    final subject = values[subjectIndex];
    if (subject.isEmpty ||
        subject.toLowerCase() == 'subject' ||
        subject.toLowerCase() == 'subject name')
      continue;

    final stats = subjectStats.putIfAbsent(
      subject,
      () => SubjectStatsDetailed(name: subject),
    );
    final hours = double.tryParse(values[hoursIndex]) ?? 0.0;
    if (hours < 0) continue; // Skip negative hours

    final marked = values[markedIndex].toUpperCase();
    final dateString = values[dateIndex].split(' ')[0]; // Take only date part
    DateTime? absenceDate;
    for (final format in dateFormats) {
      try {
        // Be more lenient with separators
        final cleanedDateString = dateString.replaceAll(RegExp(r'[./]'), '-');
        if (cleanedDateString.isNotEmpty) {
          absenceDate = format.parseStrict(cleanedDateString);
          break; // Stop if parsing is successful
        }
      } catch (_) {
        /* Try next format */
      }
    }
    if (absenceDate == null && marked == 'A')
      debugPrint("Could not parse date for absence: $dateString");

    stats.conducted += hours;
    if (marked == 'P' || marked == 'PRESENT') {
      stats.present += hours;
      stats.attended += hours;
    } else if (marked == 'OD' || marked == 'ON DUTY') {
      stats.od += hours;
      stats.attended += hours;
    } else if (marked == 'A' || marked == 'ABSENT') {
      stats.absent += hours;
      if (absenceDate != null)
        stats.absences.add(AbsenceRecord(date: absenceDate, hours: hours));
    } else {
      debugPrint("Unknown 'marked' status: '$marked' for subject: '$subject'");
    }
  }
  if (subjectStats.isEmpty) {
    throw Exception("Raw Log Parse Error: No valid subject data rows found.");
  }
  return subjectStats;
}

/// Top-level function to parse Aggregated Data. Throws Exception on critical errors.
Map<String, SubjectStatsDetailed> parseAggregatedDataTopLevel(
  List<String> lines,
  int headerRowIndex,
) {
  final splitter = RegExp(r'\t| {2,}|,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
  final headers = lines[headerRowIndex]
      .split(splitter)
      .map((h) => h.trim().replaceAll('"', ''))
      .toList();

  final subjectIndex = findHeaderIndexTopLevel(
    headers,
    ['subject name', 'subject'],
    secondaryTerms: ['subject'],
    exclusionTerms: ['code'],
  );
  final presentIndex = findHeaderIndexTopLevel(
    headers,
    ['present'],
    secondaryTerms: ['present'],
  );
  final odIndex = findHeaderIndexTopLevel(
    headers,
    ['od', 'on duty'],
    secondaryTerms: ['od', 'on duty'],
  );
  final absentIndex = findHeaderIndexTopLevel(
    headers,
    ['absent'],
    secondaryTerms: ['absent'],
  );

  if (subjectIndex == -1 || presentIndex == -1 || absentIndex == -1) {
    throw Exception(
      "Aggregated Parse Error: Could not find required columns. Subject(${subjectIndex != -1}), Present(${presentIndex != -1}), Absent(${absentIndex != -1}). Headers: ${headers.join(', ')}",
    );
  }
  final odIndexIsValid = odIndex != -1;

  final subjectStats = <String, SubjectStatsDetailed>{};
  final dataLines = lines.sublist(headerRowIndex + 1);

  for (final line in dataLines) {
    final values = line
        .split(splitter)
        .map((v) => v.trim().replaceAll('"', ''))
        .toList();
    final requiredIndices = [subjectIndex, presentIndex, absentIndex];
    if (odIndexIsValid) requiredIndices.add(odIndex);
    // Ensure maxIndex calculation doesn't fail if odIndex is -1 but valid
    final validIndices = requiredIndices.where((i) => i != -1).toList();
    if (validIndices.isEmpty)
      continue; // Should not happen if required cols are found
    final maxIndex = validIndices.reduce((a, b) => a > b ? a : b);

    if (values.length <= maxIndex) continue;

    final subject = values[subjectIndex];
    if (subject.isEmpty ||
        subject.toLowerCase() == 'subject' ||
        subject.toLowerCase() == 'subject name')
      continue;

    final stats = subjectStats.putIfAbsent(
      subject,
      () => SubjectStatsDetailed(name: subject),
    );
    final presentVal = double.tryParse(values[presentIndex]) ?? 0.0;
    final odVal = odIndexIsValid
        ? (double.tryParse(values[odIndex]) ?? 0.0)
        : 0.0;
    final absentVal = double.tryParse(values[absentIndex]) ?? 0.0;

    if (presentVal < 0 || odVal < 0 || absentVal < 0)
      continue; // Skip negative values

    stats.present += presentVal;
    stats.od += odVal;
    stats.absent += absentVal;
    stats.attended += (presentVal + odVal);
    stats.conducted += (presentVal + odVal + absentVal);
  }
  if (subjectStats.isEmpty) {
    throw Exception(
      "Aggregated Parse Error: No valid subject data rows found.",
    );
  }
  return subjectStats;
}

/// Static function designed to be run in a separate isolate via compute.
CalculationOutput performCalculation(ComputeInput input) {
  String? errorMessage;
  CalculationResult result =
      CalculationResult.empty(); // Start with empty result
  Map<String, SubjectStatsDetailed>? parsedStats;

  if (input.rawData.trim().isEmpty) {
    return CalculationOutput(
      CalculationResult.empty(),
      "Please provide attendance data to begin.",
    );
  }

  try {
    // Call the top-level parsing function
    parsedStats = parseDataTopLevel(input.rawData);
    // parseDataTopLevel will throw if parsing fails or returns empty/null

    // --- Calculate Totals ---
    double totalAttended = 0.0,
        totalConducted = 0.0,
        totalPresent = 0.0,
        totalOD = 0.0,
        totalAbsent = 0.0;
    parsedStats.forEach((key, stats) {
      totalAttended += stats.attended;
      totalConducted += stats.conducted;
      totalPresent += stats.present;
      totalOD += stats.od;
      totalAbsent += stats.absent;
    });

    if (totalConducted <= 0) {
      throw Exception(
        "Total conducted hours must be positive after parsing. Check data.",
      );
    }

    // --- Calculate Percentage and Max Drop ---
    final double targetDecimal =
        input.targetPercentage / 100.0; // Use target from input
    if (targetDecimal <= 0 || targetDecimal >= 1)
      throw Exception("Target % must be between 1 and 99.");

    final double currentPercentage = (totalAttended / totalConducted) * 100;
    final numerator = totalAttended - (targetDecimal * totalConducted);
    int maxDrop = (numerator / targetDecimal).floor();
    int requiredClasses = 0;

    if (maxDrop < 0) {
      final deficit = (targetDecimal * totalConducted) - totalAttended;
      if (1 - targetDecimal > 0) {
        requiredClasses = (deficit / (1 - targetDecimal)).ceil();
      } else {
        requiredClasses =
            99999; // Indicate practically unreachable if target is 100%
      }
      maxDrop = 0;
    }

    // --- Create Result ---
    result = CalculationResult(
      totalAttended: totalAttended,
      totalConducted: totalConducted,
      totalPresent: totalPresent,
      totalOD: totalOD,
      totalAbsent: totalAbsent,
      currentPercentage: currentPercentage.isNaN ? 0.0 : currentPercentage,
      maxDroppableHours: maxDrop,
      requiredToAttend: requiredClasses,
      subjectStats: parsedStats, // Use the successfully parsed stats
      dataParsedSuccessfully: true, // Mark as successful
    );
    errorMessage = null; // Clear error on success
  } catch (e) {
    // Catch exceptions from parsing or calculation
    errorMessage = e.toString().replaceFirst(
      'Exception: ',
      '',
    ); // Clean up error message
    result = CalculationResult.empty(); // Ensure result is empty on error
    debugPrint("Static Calculation Error: $errorMessage");
  }
  return CalculationOutput(result, errorMessage);
}
