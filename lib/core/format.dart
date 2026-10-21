/// Formats 27737 as "27.7k", 1919 as "1.92k", 28577260 as "28.6M".
String compactNumber(num? value) {
  if (value == null) return '0';
  final v = value.toDouble();
  if (v < 1000) return v.toInt().toString();
  const units = ['k', 'M', 'B', 'T'];
  var n = v;
  var i = -1;
  while (n >= 1000 && i < units.length - 1) {
    n /= 1000;
    i++;
  }
  final digits = n >= 100 ? 0 : (n >= 10 ? 1 : 2);
  var s = n.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return '$s${units[i]}';
}

/// Formats a byte count as "3.31 kB", "971 MB".
String fileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'kB', 'MB', 'GB', 'TB'];
  var n = bytes.toDouble();
  var i = 0;
  while (n >= 1000 && i < units.length - 1) {
    n /= 1000;
    i++;
  }
  final digits = i == 0 || n >= 100 ? 0 : (n >= 10 ? 1 : 2);
  return '${n.toStringAsFixed(digits)} ${units[i]}';
}

/// Formats parameter counts like 763205315794 as "763B".
String paramCount(int? n) {
  if (n == null || n <= 0) return '';
  return compactNumber(n).replaceAll('k', 'K');
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

String shortDate(DateTime? d) {
  if (d == null) return '';
  final l = d.toLocal();
  return '${_months[l.month - 1]} ${l.day}, ${l.year}';
}

String dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Turns a pipeline tag such as "image-text-to-text" into "Image-Text-to-Text".
String humanizeTag(String? tag) {
  if (tag == null || tag.isEmpty) return '';
  const lower = {'to', 'and', 'of'};
  return tag
      .split('-')
      .map(
        (w) => lower.contains(w) || w.isEmpty
            ? w
            : w[0].toUpperCase() + w.substring(1),
      )
      .join('-')
      .replaceAll('-To-', '-to-');
}

/// Two-letter initials for an avatar fallback: "deepseek-ai" -> "DE".
String initialsFor(String name) {
  final parts = name
      .split(RegExp(r'[-_ .]'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first
        .substring(0, parts.first.length.clamp(0, 2))
        .toUpperCase();
  }
  return (parts[0][0] + parts[1][0]).toUpperCase();
}
