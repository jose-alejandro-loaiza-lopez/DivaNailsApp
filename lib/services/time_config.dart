class TimeConfig {
  static int offsetHours() => DateTime.now().timeZoneOffset.inHours;

  static DateTime now() =>
      DateTime.now().toUtc().add(Duration(hours: offsetHours()));

  static DateTime today() {
    final n = now();
    final utcMidnight = DateTime.utc(n.year, n.month, n.day);
    return utcMidnight.add(Duration(hours: -offsetHours()));
  }
}
