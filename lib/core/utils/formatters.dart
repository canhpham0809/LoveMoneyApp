/// Simple VND currency formatter (no external package needed).
String formatVnd(num amount) {
  final str = amount.toStringAsFixed(0);
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write('.');
    buf.write(str[i]);
    count++;
  }
  return '${buf.toString().split('').reversed.join()}đ';
}

/// Format date as dd/MM/yyyy.
String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

/// Format date-time as dd/MM/yyyy HH:mm.
String formatDateTime(DateTime dateTime) {
  return '${formatDate(dateTime)} '
      '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
}

/// Convert a DateTime value to UTC+7 for consistent display.
DateTime toUtcPlus7(DateTime value) {
  final utcValue = value.isUtc ? value : value.toUtc();
  return utcValue.add(const Duration(hours: 7));
}

/// Format only the time part (HH:mm) in UTC+7.
String formatTimeUtcPlus7(DateTime value) {
  return formatDateTime(toUtcPlus7(value)).split(' ').last;
}
