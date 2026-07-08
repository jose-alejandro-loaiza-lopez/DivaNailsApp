import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/service.dart';
import '../services/app_data.dart';
import '../utils/formatters.dart';
import '../utils/error_handler.dart';

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
  final _newCtrl = _RowControllers();
  String _search = '';

  List<Service> get _filteredServices {
    if (_search.isEmpty) return _services;
    final q = _search.toLowerCase();
    return _services.where((s) => s.name.toLowerCase().contains(q)).toList();
  }

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _loadServices();
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    _newCtrl.dispose();
    for (final rc in _rowControllers) { rc.dispose(); }
    super.dispose();
  }

  void _onAppDataChanged() => _loadServices();

  Future<void> _loadServices() async {
    final services = await _db.getServices();
    services.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    setState(() {
      _services = services;
      _loading = false;
      _syncControllers();
    });
  }

  void _syncControllers() {
    while (_rowControllers.length < _services.length) {
      _rowControllers.add(_RowControllers());
    }
    while (_rowControllers.length > _services.length) {
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
  }

  Future<void> _saveNew() async {
    final name = _newCtrl.name.text.trim();
    if (name.isEmpty) {
      ErrorHandler.showMessage('El nombre del servicio es obligatorio', isError: true);
      return;
    }
    final price = double.tryParse(_newCtrl.price.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ErrorHandler.showMessage('El precio debe ser un número válido mayor a 0', isError: true);
      return;
    }
    await _db.insertService(Service(name: name, price: price));
    _newCtrl.name.clear();
    _newCtrl.price.clear();
    AppData.instance.notifyChanged();
    await _loadServices();
    ErrorHandler.showMessage('Servicio guardado');
  }

  Future<void> _saveRow(int index) async {
    if (index >= _rowControllers.length) return;
    final rc = _rowControllers[index];
    final name = rc.name.text.trim();
    if (name.isEmpty) {
      ErrorHandler.showMessage('El nombre del servicio es obligatorio', isError: true);
      return;
    }
    final price = double.tryParse(rc.price.text.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ErrorHandler.showMessage('El precio debe ser un número válido mayor a 0', isError: true);
      return;
    }

    await _db.updateService(_services[index].copyWith(name: name, price: price));
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
      ErrorHandler.showMessage('Eliminado correctamente');
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
        title: const Text('Servicios'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar servicios...',
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          if (_search.isEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: TextField(
                          controller: _newCtrl.name,
                          focusNode: _newCtrl.nameFocus,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Servicio',
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: TextField(
                          controller: _newCtrl.price,
                          focusNode: _newCtrl.priceFocus,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Precio',
                            prefixText: '\$ ',
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: _saveNew,
                        ),
                      ),
                    ),
                  ],
              ),
            ),
          if (_search.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 16, color: theme.dividerColor),
            ),
          if (_search.isNotEmpty) const SizedBox(height: 8),
          _HeaderRow(
            columns: const ['Servicio', 'Precio (\$)'],
            flexes: const [4, 1],
          ),
          Expanded(
            child: _filteredServices.isEmpty
                ? Center(
                    child: Text(
                      _search.isEmpty ? 'Sin servicios' : 'Sin resultados',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredServices.length,
                    itemExtent: 48,
                    itemBuilder: (context, i) {
                      final index = _services.indexOf(_filteredServices[i]);
                      return _ServiceRow(
                        key: ValueKey('svc_${_services[index].id}'),
                        controllers: _rowControllers[index],
                        even: index.isEven,
                        onDelete: () => _deleteService(index),
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
  final bool even;
  final VoidCallback? onDelete;
  final Future<void> Function() onSave;

  const _ServiceRow({
    super.key,
    required this.controllers,
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
        color: widget.even ? theme.colorScheme.surface : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: TextField(
                controller: widget.controllers.name,
                focusNode: widget.controllers.nameFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: TextField(
                controller: widget.controllers.price,
                focusNode: widget.controllers.priceFocus,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
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
