/// Timezone utilities for centralized IST (Indian Standard Time) handling
/// All datetime operations should use IST timezone consistently across the application

import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// IST timezone location
late tz.Location istLocation;

/// Initialize timezone data (call this once at app startup)
void initializeTimezone() {
  tz.initializeTimeZones();
  istLocation = tz.getLocation('Asia/Kolkata');
}

/// Get current datetime in IST timezone
DateTime getISTNow() {
  return tz.TZDateTime.now(istLocation);
}

/// Convert UTC DateTime to IST
DateTime utcToIST(DateTime utcDateTime) {
  final utcTZ = tz.TZDateTime.from(utcDateTime, tz.UTC);
  return utcTZ.toLocal();
}

/// Convert IST DateTime to UTC
DateTime istToUTC(DateTime istDateTime) {
  final istTZ = tz.TZDateTime.from(istDateTime, istLocation);
  return istTZ.toUtc();
}

/// Parse ISO date string and convert to IST DateTime
/// If the string doesn't have timezone info, it's assumed to be in IST
DateTime parseToIST(String dateString) {
  if (dateString.isEmpty) {
    throw ArgumentError('Invalid date string');
  }

  DateTime dateTime;
  
  // Try parsing as ISO format
  try {
    dateTime = DateTime.parse(dateString);
  } catch (e) {
    throw FormatException('Invalid date format: $dateString');
  }

  // If the date string has timezone info (Z or +/-), convert to IST
  if (dateString.contains('Z') || dateString.contains('+') || 
      (dateString.contains('-') && dateString.split('-').length > 3)) {
    // Has timezone info, convert UTC to IST
    final utcTZ = tz.TZDateTime.from(dateTime, tz.UTC);
    return tz.TZDateTime.from(utcTZ, istLocation);
  } else {
    // No timezone info, assume it's already in IST
    // Create TZDateTime in IST timezone
    return tz.TZDateTime(
      istLocation,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    );
  }
}

/// Format DateTime in IST to ISO string
String formatISTISO(DateTime dateTime) {
  tz.TZDateTime istTZ;
  if (dateTime is tz.TZDateTime) {
    istTZ = tz.TZDateTime.from(dateTime, istLocation);
  } else {
    istTZ = tz.TZDateTime(
      istLocation,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    );
  }
  return istTZ.toIso8601String();
}

/// Format DateTime in IST for display
/// [locale] - locale string (e.g., 'en', 'te')
/// [format] - date format string (e.g., 'dd MMM yyyy, hh:mm a')
String formatISTForDisplay(DateTime dateTime, {String? locale, String? format}) {
  tz.TZDateTime istTZ;
  if (dateTime is tz.TZDateTime) {
    istTZ = tz.TZDateTime.from(dateTime, istLocation);
  } else {
    istTZ = tz.TZDateTime(
      istLocation,
      dateTime.year,
      dateTime.month,
      dateTime.day,
      dateTime.hour,
      dateTime.minute,
      dateTime.second,
      dateTime.millisecond,
      dateTime.microsecond,
    );
  }
  
  if (format != null) {
    final formatter = DateFormat(format, locale ?? 'en');
    return formatter.format(istTZ);
  }
  
  // Default format
  final formatter = DateFormat('dd MMM yyyy, hh:mm a', locale ?? 'en');
  return formatter.format(istTZ);
}

/// Get IST timezone identifier
String getISTTimezone() {
  return 'Asia/Kolkata';
}

/// Ensure DateTime is in IST timezone
/// If the DateTime is naive (no timezone), it's assumed to be in IST
tz.TZDateTime ensureIST(DateTime dateTime) {
  if (dateTime is tz.TZDateTime) {
    return dateTime.toLocal();
  }
  return tz.TZDateTime.from(dateTime, istLocation);
}

