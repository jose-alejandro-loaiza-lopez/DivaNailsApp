class TimeConfig {
  static DateTime now() => DateTime.now();

  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }
}
