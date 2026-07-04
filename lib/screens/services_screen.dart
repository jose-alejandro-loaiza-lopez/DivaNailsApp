import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/service.dart';
import '../services/app_data.dart';
import '../utils/formatters.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _db = DatabaseHelper.instance;
  List<Service> _services = [];
  bool _loading = true;
  final List<_RowControllers> _rowControllers = [];

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _loadServices();
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    for (final rc in _rowControllers) { rc.dispose(); }
    super.dispose();
  }

  void _onAppDataChanged() => _loadServices();

  Future<void> _loadServices() async {
    final services = await _db.getServices();
    setState(() {
      _services = services;
      _loading = false;
      _syncControllers();
    });
  }

  void _syncControllers() {
    final needed = _services.length + 1;
    while (_rowControllers.length < needed) {
      _rowControllers.add(_RowControllers());
    }
    while (_rowControllers.length > needed) {
      _rowControllers.removeLast().dispose();
    }
    for (int i = 0; i < _services.length; i++) {
      final rc = _rowControllers[i];
      if (rc.name.text != _services[i].name) {
        rc.name.text = _services[i].name;
      }
      final priceTxt = formatPrice(_services[i].price);
      if (rc.price.text != priceTxt) {
        rc.price.text = priceTxt;
      }
    }
    _rowControllers.last.name.text = '';
    _rowControllers.last.price.text = '';
  }

  Future<void> _saveRow(int index) async {
    if (index >= _rowControllers.length) return;
    final rc = _rowControllers[index];
    final name = rc.name.text.trim();
    if (name.isEmpty) return;
    final price = double.tryParse(rc.price.text.replaceAll(',', '.'));
    if (price == null || price <= 0) return;

    if (index < _services.length) {
      await _db.updateService(_services[index].copyWith(name: name, price: price));
    } else if (name.isNotEmpty) {
      await _db.insertService(Service(name: name, price: price));
    }
    AppData.instance.notifyChanged();
    await _loadServices();
  }

  Future<void> _deleteService(int index) async {
    if (index >= _services.length) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar servicio'),
        content: Text('¿Eliminar "${_services[index].name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteService(_services[index].id!);
    AppData.instance.notifyChanged();
      await _loadServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Servicios'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _HeaderRow(
            columns: const ['Servicio', 'Precio (\$)'],
            flexes: const [4, 1],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _rowControllers.length,
              itemExtent: 48,
              itemBuilder: (context, index) {
                final isNew = index == _services.length;
                return _ServiceRow(
                  key: ValueKey('svc_$index'),
                  controllers: _rowControllers[index],
                  isNewRow: isNew,
                  even: index.isEven,
                  onDelete: isNew ? null : () => _deleteService(index),
                  onSave: () => _saveRow(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RowControllers {
  final TextEditingController name = TextEditingController();
  final TextEditingController price = TextEditingController();
  final FocusNode nameFocus = FocusNode();
  final FocusNode priceFocus = FocusNode();

  void dispose() {
    name.dispose();
    price.dispose();
    nameFocus.dispose();
    priceFocus.dispose();
  }
}

class _HeaderRow extends StatelessWidget {
  final List<String> columns;
  final List<int> flexes;

  const _HeaderRow({required this.columns, required this.flexes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outline, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            Expanded(
              flex: flexes[i],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: i > 0
                    ? BoxDecoration(
                        border: Border(
                          left: BorderSide(color: theme.colorScheme.outlineVariant),
                        ),
                      )
                    : null,
                child: Text(
                  columns[i],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 6),
          const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _ServiceRow extends StatefulWidget {
  final _RowControllers controllers;
  final bool isNewRow;
  final bool even;
  final VoidCallback? onDelete;
  final Future<void> Function() onSave;

  const _ServiceRow({
    super.key,
    required this.controllers,
    required this.isNewRow,
    required this.even,
    this.onDelete,
    required this.onSave,
  });

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.controllers.nameFocus.addListener(_onNameFocusLost);
    widget.controllers.priceFocus.addListener(_onPriceFocusLost);
  }

  @override
  void dispose() {
    widget.controllers.nameFocus.removeListener(_onNameFocusLost);
    widget.controllers.priceFocus.removeListener(_onPriceFocusLost);
    super.dispose();
  }

  void _onNameFocusLost() {
    if (!widget.controllers.nameFocus.hasFocus) {
      _handleSave();
    }
  }

  void _onPriceFocusLost() {
    if (!widget.controllers.priceFocus.hasFocus) {
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
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: theme.dividerColor),
                ),
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
                border: Border(
                  right: BorderSide(color: theme.dividerColor),
                ),
              ),
              child: TextField(
                controller: widget.controllers.price,
                focusNode: widget.controllers.priceFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: InputBorder.none,
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
