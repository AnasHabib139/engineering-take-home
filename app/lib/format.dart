const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

DateTime dayOf(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

String formatTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// "Tuesday, 13 October"
String formatLongDate(DateTime day) =>
    '${_weekdays[day.weekday - 1]}, ${day.day} ${_months[day.month - 1]}';

/// "Today", "Yesterday" or "Sat 10 Oct"
String formatDayHeading(DateTime day, DateTime today) {
  final daysAgo = dayOf(today).difference(day).inDays;
  if (daysAgo == 0) return 'Today';
  if (daysAgo == 1) return 'Yesterday';
  return '${_weekdays[day.weekday - 1].substring(0, 3)} ${day.day} '
      '${_months[day.month - 1].substring(0, 3)}';
}

/// "2026-10-07", the format the API expects for calendar days.
String formatApiDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// "7 Oct", with the year only when it isn't this year.
String formatShortDate(DateTime day) {
  final text = '${day.day} ${_months[day.month - 1].substring(0, 3)}';
  return day.year == DateTime.now().year ? text : '$text ${day.year}';
}

/// "1 Oct – 7 Oct", or just "7 Oct" for a single day.
String formatPeriod(DateTime from, DateTime to) =>
    from == to ? formatShortDate(from) : '${formatShortDate(from)} – ${formatShortDate(to)}';

/// "8 Oct, 10:03"
String formatDateTime(DateTime value) => '${formatShortDate(dayOf(value))}, ${formatTime(value)}';
