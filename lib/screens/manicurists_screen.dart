import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/manicurist.dart';
import '../services/app_data.dart';

class ManicuristsScreen extends StatefulWidget {
  const ManicuristsScreen({super.key});

  @override
  State<ManicuristsScreen> createState() => _ManicuristsScreenState();
}

class _ManicuristsScreenState extends State<ManicuristsScreen> {
  final _db = DatabaseHelper.instance;
  List<Manicurist> _manicurists = [];
  bool _loading = true;
  final _controllers = <_ManRowControllers>[];

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _load();
  }

  Future<void> _load() async {
    final data = await _db.getManicurists();
    setState(() {
      _manicurists = data;
      _loading = false;
      _syncControllers();
    });
  }

  void _syncControllers() {
    final needed = _manicurists.length + 1;
    while (_controllers.length < needed) {
      _controllers.add(_ManRowControllers());
    }
    while (_controllers.length > needed) {
      _controllers.removeLast().dispose();
    }
    for (int i = 0; i < _manicurists.length; i++) {
      final rc = _controllers[i];
      final m = _manicurists[i];
      if (rc.name.text != m.name) rc.name.text = m.name;
      rc.profitText = m.profitPercentage.toStringAsFixed(0);
    }
    final last = _controllers.last;
    last.name.text = '';
    last.profitText = '40';
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    for (final rc in _controllers) { rc.dispose(); }
    super.dispose();
  }

  void _onAppDataChanged() => _load();

  Future<void> _saveRow(int index) async {
    if (index >= _controllers.length) return;
    final rc = _controllers[index];
    final name = rc.name.text.trim();
    if (name.isEmpty) return;
    final profit = double.tryParse(rc.profitText.replaceAll(',', '.')) ?? 40.0;

    if (index < _manicurists.length) {
      await _db.updateManicurist(
        _manicurists[index].copyWith(name: name, profitPercentage: profit),
      );
    } else {
      await _db.insertManicurist(Manicurist(name: name, profitPercentage: profit));
    }
    AppData.instance.notifyChanged();
    await _load();
  }

  Future<void> _delete(int index) async {
    if (index >= _manicurists.length) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar manicurista'),
        content: Text('¿Eliminar a "${_manicurists[index].name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteManicurist(_manicurists[index].id!);
    AppData.instance.notifyChanged();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manicuristas'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 1)),
            ),
            child: Row(
              children: [
                _hCell('Nombre', 4, theme, false),
                _hCell('Ganancia %', 1, theme, true),
                const SizedBox(width: 6),
                const SizedBox(width: 42),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _controllers.length,
              itemExtent: 48,
              itemBuilder: (context, index) {
                final isNew = index == _manicurists.length;
                return _ManicuristRow(
                  key: ValueKey('man_$index'),
                  controllers: _controllers[index],
                  isNewRow: isNew,
                  even: index.isEven,
                  onDelete: isNew ? null : () => _delete(index),
                  onSave: () => _saveRow(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _hCell(String text, int flex, ThemeData theme, bool hasLeftBorder) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: hasLeftBorder
            ? BoxDecoration(
                border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
              )
            : null,
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer)),
      ),
    );
  }
}

class _ManRowControllers {
  final TextEditingController name = TextEditingController();
  final FocusNode nameFocus = FocusNode();
  String profitText = '40';

  void dispose() {
    name.dispose();
    nameFocus.dispose();
  }
}

class _ManicuristRow extends StatefulWidget {
  final _ManRowControllers controllers;
  final bool isNewRow;
  final bool even;
  final VoidCallback? onDelete;
  final Future<void> Function() onSave;

  const _ManicuristRow({
    super.key,
    required this.controllers,
    required this.isNewRow,
    required this.even,
    this.onDelete,
    required this.onSave,
  });

  @override
  State<_ManicuristRow> createState() => _ManicuristRowState();
}

class _ManicuristRowState extends State<_ManicuristRow> {
  bool _saving = false;
  final _profitFocus = FocusNode();
  final _profitCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controllers.nameFocus.addListener(_onFocusLost);
    _profitFocus.addListener(_onFocusLost);
    _profitCtrl.text = widget.controllers.profitText;
  }

  @override
  void didUpdateWidget(_ManicuristRow old) {
    super.didUpdateWidget(old);
    if (old.controllers != widget.controllers) {
      _profitCtrl.text = widget.controllers.profitText;
    }
  }

  @override
  void dispose() {
    widget.controllers.nameFocus.removeListener(_onFocusLost);
    _profitFocus.removeListener(_onFocusLost);
    _profitCtrl.dispose();
    super.dispose();
  }

  void _onFocusLost() {
    final any = widget.controllers.nameFocus.hasFocus || _profitFocus.hasFocus;
    if (!any) {
      widget.controllers.profitText = _profitCtrl.text;
      _handleSave();
    }
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    _saving = true;
    await widget.onSave();
    _saving = false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: widget.isNewRow
            ? theme.colorScheme.surfaceContainerLow
            : (widget.even ? theme.colorScheme.surface : Colors.transparent),
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: theme.dividerColor)),
              ),
              child: TextField(
                controller: widget.controllers.name,
                focusNode: widget.controllers.nameFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: theme.dividerColor)),
              ),
              child: TextField(
                controller: _profitCtrl,
                focusNode: _profitFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: InputBorder.none,
                  suffixText: '%',
                  suffixStyle: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                style: const TextStyle(fontSize: 14),
                keyboardType: TextInputType.number,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 42,
            height: 48,
            alignment: Alignment.centerLeft,
            child: widget.onDelete != null
                ? GestureDetector(
                    onTap: widget.onDelete,
                    child: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
