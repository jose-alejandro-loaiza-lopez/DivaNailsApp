String formatPrice(double v) {
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(2);
  if (s.endsWith('0')) return s.substring(0, s.length - 1);
  return s;
}

String formatPriceWithDots(double v) {
  final s = formatPrice(v);
  final parts = s.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  if (parts.length == 1) return intPart;
  return '$intPart,${parts[1]}';
}
