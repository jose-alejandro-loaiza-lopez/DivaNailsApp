import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService instance = ThemeService._();
  ThemeService._();

  Color _seedColor = Colors.pink;
  bool _darkMode = false;
  String _exportPath = '';

  Color get seedColor => _seedColor;
  bool get darkMode => _darkMode;
  Brightness get brightness => _darkMode ? Brightness.dark : Brightness.light;
  String get exportPath => _exportPath;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final hex = prefs.getString('seedColor') ?? '';
    if (hex.isNotEmpty) {
      _seedColor = Color(int.parse(hex, radix: 16) + 0xFF000000);
    }
    _darkMode = prefs.getBool('darkMode') ?? false;
    _exportPath = prefs.getString('exportPath') ?? '';
    notifyListeners();
  }

  String get effectiveExportPath {
    if (_exportPath.isNotEmpty) return _exportPath;
    final home = Platform.environment['USERPROFILE'] ?? '.';
    final path = '$home\\Desktop\\DivaNails';
    final dir = Directory(path);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<void> setColor(Color color) async {
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seedColor', (color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0'));
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _darkMode = !_darkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    notifyListeners();
  }

  Future<void> setExportPath(String path) async {
    final clean = path.trim().replaceAll('"', '');
    _exportPath = clean;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exportPath', clean);
    notifyListeners();
  }
}
