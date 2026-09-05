/// Helpers for figuring out whether a stored appointment's scheduled date
/// and time have already passed - used so "Upcoming Appointment" reminders
/// (in the notification tray and on the Home dashboard) disappear on their
/// own once the visit is over, instead of only going away when something
/// manually flips the appointment's `status` field.
///
/// Parsing is deliberately forgiving: it accepts ISO-style dates
/// ('2026-09-16') as well as human-readable ones ('16 Sep 2026',
/// 'Sep 16, 2026'), and times either in 24-hour ('14:30') or 12-hour
/// ('2:30 PM') form. If the stored date can't be understood at all, the
/// appointment is treated as NOT past (i.e. the reminder is kept visible)
/// so a formatting mismatch can never silently hide a real appointment.
library;

const Map<String, int> _kMonthAbbreviations = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

DateTime? _parseAppointmentDate(String dateStr) {
  final trimmed = dateStr.trim();
  if (trimmed.isEmpty) return null;

  // Handles ISO-style 'yyyy-MM-dd' (and full ISO timestamps).
  final iso = DateTime.tryParse(trimmed);
  if (iso != null) return DateTime(iso.year, iso.month, iso.day);

  // Handles the app's own booking format: '${date.day}/${date.month}/${date.year}'
  // e.g. '5/9/2026' - day first, no zero-padding, matching how
  // AppointmentBookingPage actually saves it.
  final slashMatch = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
  if (slashMatch != null) {
    final day = int.tryParse(slashMatch.group(1)!);
    final month = int.tryParse(slashMatch.group(2)!);
    final year = int.tryParse(slashMatch.group(3)!);
    if (day != null && month != null && year != null) {
      return DateTime(year, month, day);
    }
  }

  // Handles '16 Sep 2026' or 'Sep 16, 2026' style strings.
  final match = RegExp(r'(\d{1,2})\D+([A-Za-z]{3,})\D+(\d{4})').firstMatch(trimmed) ??
      RegExp(r'([A-Za-z]{3,})\D+(\d{1,2})\D+(\d{4})').firstMatch(trimmed);
  if (match == null) return null;

  final groups = [match.group(1)!, match.group(2)!, match.group(3)!];
  final numericParts = groups.where((g) => int.tryParse(g) != null).toList();
  final monthPart = groups.firstWhere((g) => int.tryParse(g) == null, orElse: () => '');

  if (numericParts.length < 2 || monthPart.isEmpty) return null;

  final month = _kMonthAbbreviations[monthPart.toLowerCase().substring(0, 3)];
  if (month == null) return null;

  final year = numericParts.firstWhere((p) => p.length == 4, orElse: () => '');
  final day = numericParts.firstWhere((p) => p != year, orElse: () => '');
  final parsedYear = int.tryParse(year);
  final parsedDay = int.tryParse(day);
  if (parsedYear == null || parsedDay == null) return null;

  return DateTime(parsedYear, month, parsedDay);
}

({int hour, int minute})? _parseAppointmentTime(String timeStr) {
  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AaPp][Mm])?').firstMatch(timeStr.trim());
  if (match == null) return null;

  int hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  final meridiem = match.group(3)?.toLowerCase();

  if (meridiem == 'pm' && hour != 12) hour += 12;
  if (meridiem == 'am' && hour == 12) hour = 0;

  return (hour: hour, minute: minute);
}

/// Returns the appointment's scheduled [DateTime], combining its 'date' and
/// 'time' fields, or null if the stored strings can't be parsed.
DateTime? parseAppointmentDateTime(Map<String, dynamic> appointment) {
  final dateStr = appointment['date']?.toString() ?? '';
  final date = _parseAppointmentDate(dateStr);
  if (date == null) return null;

  final timeStr = appointment['time']?.toString() ?? '';
  final time = _parseAppointmentTime(timeStr);

  return DateTime(date.year, date.month, date.day, time?.hour ?? 23, time?.minute ?? 59);
}

/// Whether [appointment]'s scheduled date/time is already in the past.
/// Unparseable dates are treated as NOT past, so the reminder stays visible
/// rather than silently vanishing due to an unexpected date format.
bool isAppointmentPast(Map<String, dynamic> appointment) {
  final scheduled = parseAppointmentDateTime(appointment);
  if (scheduled == null) return false;
  return scheduled.isBefore(DateTime.now());
}