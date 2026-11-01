import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static final DateFormat _dateFormat = DateFormat('dd-MM-yyyy', 'id_ID');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy HH:mm', 'id_ID');
  static final DateFormat _timeFormat = DateFormat('HH:mm', 'id_ID');
  static final DateFormat _dayDateFormat = DateFormat('EEEE, dd-MM-yyyy', 'id_ID');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy', 'id_ID');

  static String formatDate(DateTime? date) {
    if (date == null) return '-';
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${_dateTimeFormat.format(dateTime)} WIB';
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return '${_timeFormat.format(dateTime)} WIB';
  }

  static String formatDayDate(DateTime? date) {
    if (date == null) return '-';
    return _dayDateFormat.format(date);
  }

  static String formatMonthYear(DateTime? date) {
    if (date == null) return '-';
    return _monthYearFormat.format(date);
  }

  static String toIsoDateOnly(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
