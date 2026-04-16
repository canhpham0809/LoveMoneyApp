/// Simple VND currency formatter (no external package needed).
String formatVnd(num amount) {
  final str = amount.toStringAsFixed(0);
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write(',');
    buf.write(str[i]);
    count++;
  }
  return '${buf.toString().split('').reversed.join()} ₫';
}

/// Format date as dd/MM/yyyy.
String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
