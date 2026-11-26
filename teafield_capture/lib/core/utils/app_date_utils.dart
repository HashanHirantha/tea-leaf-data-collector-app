import 'package:intl/intl.dart';

/// Date/time formatting helpers for the app.
class AppDateUtils {
  AppDateUtils._();

  /// Return the current UTC time as an ISO 8601 string.
  static String nowUtcIso() => DateTime.now().toUtc().toIso8601String();

  /// Format an ISO date string for display (date only).
  static String formatDisplayDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd').format(dt.toLocal());
    } catch (_) {
      return isoDate;
    }
  }

  /// Format an ISO date-time string for display.
  static String formatDisplayDateTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd HH:mm').format(dt.toLocal());
    } catch (_) {
      return isoDate;
    }
  }

  /// Format an ISO date-time string with seconds.
  static String formatDisplayDateTimeFull(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());
    } catch (_) {
      return isoDate;
    }
  }
}
