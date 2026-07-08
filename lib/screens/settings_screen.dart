import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:restart_app/restart_app.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/theme_service.dart';
import '../services/app_data.dart';
import '../database/database_helper.dart';
import '../utils/error_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _defaultDbDir = '';
  String _appVersion = '';
  final _dbDirCtrl = TextEditingController();
  final _exportCtrl = TextEditingController();
  final _konamiBuffer = <LogicalKeyboardKey>[];
  final _focusNode = FocusNode();

  static const _konamiCode = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _exportCtrl.text = ThemeService.instance.exportPath;
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    }
  }

  @override
  void dispose() {
    _dbDirCtrl.dispose();
    _exportCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString('customDbDir') ?? '';
    _dbDirCtrl.text = customDir;
    final appDir = await getApplicationSupportDirectory();
    if (mounted) {
      setState(() {
        _defaultDbDir = appDir.path;
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (!_konamiCode.contains(key)) {
      _konamiBuffer.clear();
      return;
    }
    _konamiBuffer.add(key);
    final len = _konamiBuffer.length;
    if (len > _konamiCode.length) {
      _konamiBuffer.removeAt(0);
    }
    if (_konamiBuffer.length == _konamiCode.length) {
      bool match = true;
      for (int i = 0; i < _konamiCode.length; i++) {
        if (_konamiBuffer[i] != _konamiCode[i]) {
          match = false;
          break;
        }
      }
      if (match) {
        _konamiBuffer.clear();
        _toggleDevMode();
      }
    }
  }

  void _toggleDevMode() {
    AppData.instance.toggleDevMode();
    if (AppData.instance.devMode) {
      ErrorHandler.showMessage('Modo desarrollador activado');
    } else {
      ErrorHandler.showMessage('Modo desarrollador desactivado', isError: true);
    }
  }

  Future<void> _browseDbDir() async {
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir != null) {
      _dbDirCtrl.text = dir;
    }
  }

  Future<void> _applyDbDir() async {
    final newDir = _dbDirCtrl.text.trim();
    if (newDir.isNotEmpty && !Directory(newDir).existsSync()) {
      ErrorHandler.showMessage('La ruta no existe');
      return;
    }
    final isReset = newDir.isEmpty;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar ruta de base de datos'),
        content: Text(isReset
            ? 'Se usará la ruta por defecto. La aplicación se reiniciará para aplicar los cambios. ¿Desea continuar?'
            : 'La aplicación se reiniciará para aplicar los cambios. ¿Desea continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (confirm != true) return;
    await DatabaseHelper.prepareMigration(newDir);
    if (mounted) Restart.restartApp();
  }

  Future<void> _resetColumnWidths() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer anchos'),
        content: const Text('Se borrarán los anchos guardados y se usarán los valores predeterminados. ¿Desea continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar')),
        ],
      ),
    );
    if (confirm != true) return;
    final prefs = await SharedPreferences.getInstance();
    const keys = ['horaW', 'clienteW', 'telW', 'serviciosW', 'descW', 'manW', 'adicW', 'pagoW', 'totalW'];
    for (final k in keys) { await prefs.remove(k); }
    if (mounted) Restart.restartApp();
  }

  static const _colors = [
    ('Rosa', Color(0xFFE91E63)),
    ('Rojo', Color(0xFFF44336)),
    ('Naranja', Color(0xFFFF9800)),
    ('Ámbar', Color(0xFFFFC107)),
    ('Verde', Color(0xFF4CAF50)),
    ('Teal', Color(0xFF009688)),
    ('Azul', Color(0xFF2196F3)),
    ('Indigo', Color(0xFF3F51B5)),
    ('Morado', Color(0xFF9C27B0)),
    ('Gris', Color(0xFF607D8B)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final svc = ThemeService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final currentColor = svc.seedColor;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ajustes'),
            centerTitle: true,
          ),
          body: KeyboardListener(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Modo oscuro',
                          style: theme.textTheme.titleMedium),
                      SwitchListTile(
                        title: const Text('Activar modo oscuro'),
                        value: svc.darkMode,
                        onChanged: (_) => svc.toggleDarkMode(),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Color de la aplicación',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _colors.map((c) {
                          final (label, color) = c;
                          final selected =
                              color.toARGB32() == currentColor.toARGB32();
                          return GestureDetector(
                            onTap: () => svc.setColor(color),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: selected
                                        ? Border.all(
                                            color: theme
                                                .colorScheme.onSurface,
                                            width: 3)
                                        : null,
                                  ),
                                  child: selected
                                      ? Icon(Icons.check,
                                          color: color
                                                      .computeLuminance() >
                                                  0.5
                                              ? Colors.black
                                              : Colors.white)
                                      : null,
                                ),
                                const SizedBox(height: 4),
                                Text(label,
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rutas',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Base de datos',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('sqflite_common_ffi',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dbDirCtrl,
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: const OutlineInputBorder(),
                                hintText: _defaultDbDir,
                                hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.folder_open),
                            tooltip: 'Examinar',
                            onPressed: _browseDbDir,
                          ),
                          IconButton(
                            icon: const Icon(Icons.check),
                            tooltip: 'Aplicar',
                            onPressed: _applyDbDir,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('Exportar Excel',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Desktop / Downloads',
                                style: TextStyle(fontSize: 11, color: theme.colorScheme.onPrimaryContainer)),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _exportCtrl,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: const OutlineInputBorder(),
                                  hintText: ThemeService.instance.effectiveExportPath,
                                  hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                                ),
                                style: const TextStyle(fontSize: 13),
                                onChanged: (v) => svc.setExportPath(v.trim()),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.folder_open),
                              tooltip: 'Examinar',
                              onPressed: () async {
                                final dir = await FilePicker.platform.getDirectoryPath();
                                if (dir != null) {
                                  _exportCtrl.text = dir;
                                  svc.setExportPath(dir);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Columnas de registros',
                            style: theme.textTheme.titleMedium),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.restore),
                        label: const Text('Restablecer anchos predeterminados'),
                        onPressed: _resetColumnWidths,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acerca de',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      const _InfoRow(
                          label: 'Nombre', value: 'Diva Nails'),
                      _InfoRow(
                          label: 'Versión', value: _appVersion.isNotEmpty ? _appVersion : 'Cargando...'),
                      const _InfoRow(
                          label: 'Propósito',
                          value: 'Gestión de servicios para spa de uñas'),
                      const _InfoRow(
                          label: 'Desarrollado con',
                          value: 'Flutter + SQLite'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
