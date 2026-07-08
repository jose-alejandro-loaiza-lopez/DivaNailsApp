import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/client.dart';
import '../models/appointment.dart';
import '../services/app_data.dart';
import '../services/time_config.dart';

const double _cliDeleteW = 48;

double _tw(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: ui.TextDirection.ltr,
  );
  tp.layout();
  return tp.width;
}

const _months = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _db = DatabaseHelper.instance;
  List<Client> _clients = [];
  Map<int, int> _appointmentCounts = {};
  bool _loading = true;
  final _rowControllers = <_ClientRowControllers?>[];
  final _newCtrl = _ClientRowControllers();
  String _search = '';
  double _phoneW = 120;
  double _birthW = 100;
  double _locW = 150;
  final ScrollController _scrollCtrl = ScrollController();
  static const double _itemExtent = 48.0;
  static const int _windowBuffer = 16;

  List<Client> get _filteredClients {
    if (_search.isEmpty) return _clients;
    final q = _search.toLowerCase();
    return _clients.where((c) =>
      c.phone.toLowerCase().contains(q) ||
      c.name.toLowerCase().contains(q) ||
      c.lastName.toLowerCase().contains(q)
    ).toList();
  }

  _ClientRowControllers _ensureController(int index) {
    if (_rowControllers[index] == null) {
      _rowControllers[index] = _ClientRowControllers();
      _populateController(index);
    }
    return _rowControllers[index]!;
  }

  void _populateController(int index) {
    final rc = _rowControllers[index]!;
    final c = _clients[index];
    final phoneStr = c.phone;
    if (rc.phone.text != phoneStr) rc.phone.text = phoneStr;
    if (rc.name.text != c.name) rc.name.text = c.name;
    if (rc.lastName.text != c.lastName) rc.lastName.text = c.lastName;
    rc.birthDay = c.birthDay;
    rc.birthMonth = c.birthMonth;
    if (rc.location.text != c.location) rc.location.text = c.location;
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients || _clients.isEmpty || _search.isNotEmpty) return;
    final offset = _scrollCtrl.position.pixels;
    final viewportH = _scrollCtrl.position.viewportDimension;
    final firstVisible = (offset / _itemExtent).floor();
    final visibleCount = (viewportH / _itemExtent).ceil() + 1;
    final keepStart = max(0, firstVisible - _windowBuffer);
    final keepEnd = min(_clients.length, firstVisible + visibleCount + _windowBuffer);

    for (int i = 0; i < _rowControllers.length; i++) {
      final rc = _rowControllers[i];
      if (rc != null && (i < keepStart || i >= keepEnd)) {
        rc.dispose();
        _rowControllers[i] = null;
      }
    }
    for (int i = keepStart; i < keepEnd; i++) {
      if (_rowControllers[i] == null) {
        _rowControllers[i] = _ClientRowControllers();
        _populateController(i);
      }
    }
  }

  void _recalcWidths() {
    const pad = 28.0;
    const hStyle = TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
    const dStyle = TextStyle(fontSize: 14);
    _phoneW = _tw('Teléfono', hStyle) + pad;
    final visible = _rowControllers.where((rc) => rc != null).cast<_ClientRowControllers>().toList();
    for (final rc in [_newCtrl, ...visible]) {
      _phoneW = max(_phoneW, _tw(rc.phone.text.isEmpty ? '300 000 0000' : rc.phone.text, dStyle) + pad);
    }
    _birthW = _tw('Cumpleaños', hStyle) + pad;
    for (final rc in [_newCtrl, ...visible]) {
      final t = rc.birthDay != null && rc.birthMonth != null
          ? '${rc.birthDay} ${_months[(rc.birthMonth! - 1).clamp(0, 11)]}'
          : 'DD/MM';
      _birthW = max(_birthW, _tw(t, dStyle) + pad);
    }
    _locW = (_tw('Ubicación', hStyle) + pad) * 2;
    for (final rc in [_newCtrl, ...visible]) {
      _locW = max(_locW, (_tw(rc.location.text.isEmpty ? 'Dirección' : rc.location.text, dStyle) + pad) * 2);
    }
    double minName = _tw('Nombre', hStyle) + pad;
    double minLastName = _tw('Apellido', hStyle) + pad;
    for (final rc in [_newCtrl, ...visible]) {
      minName = max(minName, _tw(rc.name.text.isEmpty ? 'Nombre' : rc.name.text, dStyle) + pad);
      minLastName = max(minLastName, _tw(rc.lastName.text.isEmpty ? 'Apellido' : rc.lastName.text, dStyle) + pad);
    }
  }

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  Future<void> _load() async {
    final data = await _db.getClients();
    final counts = <int, int>{};
    for (final c in data) {
      if (c.id != null) {
        counts[c.id!] = await _db.getAppointmentsCountByClient(c.id!);
      }
    }
    data.sort((a, b) => _compareByNextBirthday(a, b));
    setState(() {
      _clients = data;
      _appointmentCounts = counts;
      _loading = false;
      _syncControllers();
      _recalcWidths();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onScroll();
      _recalcWidths();
    });
  }

  void _syncControllers() {
    for (int i = 0; i < _rowControllers.length; i++) {
      _rowControllers[i]?.dispose();
      _rowControllers[i] = null;
    }
    while (_rowControllers.length < _clients.length) {
      _rowControllers.add(null);
    }
    while (_rowControllers.length > _clients.length) {
      _rowControllers.removeLast();
    }
    _onScroll();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    AppData.instance.removeListener(_onAppDataChanged);
    _newCtrl.dispose();
    for (final rc in _rowControllers) { rc?.dispose(); }
    super.dispose();
  }

  void _onAppDataChanged() => _load();

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  int _compareByNextBirthday(Client a, Client b) {
    final now = TimeConfig.today();
    final aNext = _nextBirthday(a, now);
    final bNext = _nextBirthday(b, now);
    if (aNext == null && bNext == null) {
      return a.fullName.compareTo(b.fullName);
    }
    if (aNext == null) return 1;
    if (bNext == null) return -1;
    final cmp = aNext.compareTo(bNext);
    if (cmp != 0) return cmp;
    return a.fullName.compareTo(b.fullName);
  }

  DateTime? _nextBirthday(Client client, DateTime from) {
    if (client.birthDay == null || client.birthMonth == null) return null;
    final month = client.birthMonth!;
    final day = client.birthDay!;
    var next = DateTime(from.year, month, day);
    if (next.isBefore(from)) {
      next = DateTime(from.year + 1, month, day);
    }
    return next;
  }

  bool _isBirthdayToday(Client client) {
    if (client.birthDay == null || client.birthMonth == null) return false;
    final now = TimeConfig.today();
    return now.day == client.birthDay && now.month == client.birthMonth;
  }

  Future<void> _saveNew() async {
    final phone = _newCtrl.phone.text.trim();
    final name = _capitalize(_newCtrl.name.text.trim());
    if (name.isEmpty) return;
    final lastName = _capitalize(_newCtrl.lastName.text.trim());
    final client = Client(
      phone: phone,
      name: name,
      lastName: lastName,
      birthDay: _newCtrl.birthDay,
      birthMonth: _newCtrl.birthMonth,
      location: _capitalize(_newCtrl.location.text.trim()),
    );
    _newCtrl.name.text = name;
    _newCtrl.lastName.text = lastName;
    _newCtrl.location.text = _capitalize(_newCtrl.location.text.trim());
    await _db.insertClient(client);
    _newCtrl.phone.clear();
    _newCtrl.name.clear();
    _newCtrl.lastName.clear();
    _newCtrl.birthDay = null;
    _newCtrl.birthMonth = null;
    _newCtrl.location.clear();
    AppData.instance.notifyChanged();
    await _load();
  }

  Future<void> _saveRow(int index) async {
    if (index >= _rowControllers.length || index >= _clients.length) return;
    final rc = _ensureController(index);
    final phone = rc.phone.text.trim();
    final name = _capitalize(rc.name.text.trim());
    if (name.isEmpty) return;
    final lastName = _capitalize(rc.lastName.text.trim());
    rc.name.text = name;
    rc.lastName.text = lastName;
    rc.location.text = _capitalize(rc.location.text.trim());
    final client = Client(
      id: _clients[index].id,
      phone: phone,
      name: name,
      lastName: lastName,
      birthDay: rc.birthDay,
      birthMonth: rc.birthMonth,
      location: rc.location.text.trim(),
    );
    await _db.updateClient(client);
    AppData.instance.notifyChanged();
    await _load();
  }

  Future<void> _delete(int index) async {
    if (index >= _clients.length) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content:
            Text('¿Eliminar a "${_clients[index].fullName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteClient(_clients[index].id!);
      AppData.instance.notifyChanged();
      await _load();
    }
  }

  Future<void> _showClientAppointments(Client client) async {
    final appointments = await _db.getAppointmentsByClient(client.id!);
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _ClientAppointmentsDialog(
        client: client,
        appointments: appointments,
      ),
    );
  }

  Future<void> _editBirthday(void Function(int? day, int? month) onResult, {int? initialDay, int? initialMonth}) async {
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => _BirthdayDialog(day: initialDay, month: initialMonth),
    );
    if (result == null) return;
    if (result == -1) {
      onResult(null, null);
    } else {
      onResult(result % 100, result ~/ 100);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, apellido o teléfono...',
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
                  _newTextField(_newCtrl.phone, _newCtrl.phoneFocus, _phoneW, theme, TextInputType.phone, hintText: 'Teléfono'),
                  _newFlexField(_newCtrl.name, _newCtrl.nameFocus, 2, theme, null, hintText: 'Nombre', capitalize: true),
                  _newFlexField(_newCtrl.lastName, _newCtrl.lastNameFocus, 2, theme, null, hintText: 'Apellido', capitalize: true),
                  _newBirthdayCell(_birthW, theme),
                  _newTextField(_newCtrl.location, _newCtrl.locationFocus, _locW, theme, null, hintText: 'Ubicación', capitalize: true),
                  SizedBox(
                    width: _cliDeleteW + 8,
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
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: _filteredClients.isNotEmpty
                  ? const BorderRadius.vertical(top: Radius.circular(8))
                  : BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _hFixed('Teléfono', _phoneW, theme, false),
                _hFlex('Nombre', 2, theme, true),
                _hFlex('Apellido', 2, theme, true),
                _hFixed('Citas', 78, theme, true),
                _hFixed('Cumpleaños', _birthW, theme, true),
                _hFixed('Ubicación', _locW, theme, true),
                const SizedBox(width: 6),
                const SizedBox(width: _cliDeleteW - 6),
              ],
            ),
          ),
          Expanded(
            child: _filteredClients.isEmpty
                ? Center(
                    child: Text(
                      _search.isEmpty ? 'Sin clientes' : 'Sin resultados',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _filteredClients.length,
                    itemExtent: 48,
                    itemBuilder: (context, i) {
                      final index = _clients.indexOf(_filteredClients[i]);
                      final isEven = index.isEven;
                      final count = _appointmentCounts[_clients[index].id] ?? 0;
                      final birthdayToday = _isBirthdayToday(_clients[index]);
                      return _ClientRow(
                        key: ValueKey('cli_${_clients[index].id}'),
                        controllers: _ensureController(index),
                        even: isEven,
                        phoneW: _phoneW,
                        birthW: _birthW,
                        locW: _locW,
                        appointmentCount: count,
                        isBirthdayToday: birthdayToday,
                        onTapCitas: () => _showClientAppointments(_clients[index]),
                        onEditBirthday: (setValues, initDay, initMonth) async {
                        await _editBirthday((d, m) { setValues(d, m); }, initialDay: initDay, initialMonth: initMonth);
                        _saveRow(index);
                      },
                        onDelete: () => _delete(index),
                        onSave: () => _saveRow(index),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _newTextField(TextEditingController ctrl, FocusNode focus, double width, ThemeData theme,
      TextInputType? keyboard, {String hintText = '', bool capitalize = false}) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: const BoxDecoration(),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
            hintText: hintText.isEmpty ? null : hintText,
            hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: keyboard,
          textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
        ),
      ),
    );
  }

  Widget _newFlexField(TextEditingController ctrl, FocusNode focus, int flex, ThemeData theme,
      TextInputType? keyboard, {String hintText = '', bool capitalize = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: const BoxDecoration(),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
            hintText: hintText.isEmpty ? null : hintText,
            hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: keyboard,
          textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
        ),
      ),
    );
  }

  Widget _newBirthdayCell(double width, ThemeData theme) {
    final text = _newCtrl.birthDay != null && _newCtrl.birthMonth != null
        ? '${_newCtrl.birthDay} ${_months[(_newCtrl.birthMonth! - 1).clamp(0, 11)]}'
        : '';
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () => _editBirthday((d, m) {
          setState(() {
            _newCtrl.birthDay = d;
            _newCtrl.birthMonth = m;
          });
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            text.isEmpty ? 'DD/MM' : text,
            style: TextStyle(
              fontSize: 14,
              color: text.isEmpty ? theme.hintColor : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _hFixed(String text, double width, ThemeData theme, bool hasLeftBorder) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: hasLeftBorder
            ? BoxDecoration(
                border: Border(
                    left: BorderSide(color: theme.colorScheme.outlineVariant)),
              )
            : null,
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer)),
      ),
    );
  }

  Widget _hFlex(String text, int flex, ThemeData theme, bool hasLeftBorder) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: hasLeftBorder
            ? BoxDecoration(
                border: Border(
                    left: BorderSide(color: theme.colorScheme.outlineVariant)),
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

class _ClientRowControllers {
  final TextEditingController phone = TextEditingController();
  final TextEditingController name = TextEditingController();
  final TextEditingController lastName = TextEditingController();
  final TextEditingController location = TextEditingController();
  final FocusNode phoneFocus = FocusNode();
  final FocusNode nameFocus = FocusNode();
  final FocusNode lastNameFocus = FocusNode();
  final FocusNode locationFocus = FocusNode();
  int? birthDay;
  int? birthMonth;

  void dispose() {
    phone.dispose();
    name.dispose();
    lastName.dispose();
    location.dispose();
    phoneFocus.dispose();
    nameFocus.dispose();
    lastNameFocus.dispose();
    locationFocus.dispose();
  }
}

typedef _BirthdaySetter = void Function(int? day, int? month);

class _ClientRow extends StatefulWidget {
  final _ClientRowControllers controllers;
  final bool even;
  final double phoneW;
  final double birthW;
  final double locW;
  final int appointmentCount;
  final bool isBirthdayToday;
  final VoidCallback onTapCitas;
  final void Function(_BirthdaySetter, int? currentDay, int? currentMonth) onEditBirthday;
  final VoidCallback? onDelete;
  final Future<void> Function() onSave;

  const _ClientRow({
    super.key,
    required this.controllers,
    required this.even,
    required this.phoneW,
    required this.birthW,
    required this.locW,
    required this.appointmentCount,
    required this.isBirthdayToday,
    required this.onTapCitas,
    required this.onEditBirthday,
    this.onDelete,
    required this.onSave,
  });

  @override
  State<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends State<_ClientRow> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.controllers.phoneFocus.addListener(_onFocusLost);
    widget.controllers.nameFocus.addListener(_onFocusLost);
    widget.controllers.lastNameFocus.addListener(_onFocusLost);
    widget.controllers.locationFocus.addListener(_onFocusLost);
  }

  @override
  void dispose() {
    widget.controllers.phoneFocus.removeListener(_onFocusLost);
    widget.controllers.nameFocus.removeListener(_onFocusLost);
    widget.controllers.lastNameFocus.removeListener(_onFocusLost);
    widget.controllers.locationFocus.removeListener(_onFocusLost);
    super.dispose();
  }

  void _onFocusLost() {
    final hasAnyFocus = widget.controllers.phoneFocus.hasFocus ||
        widget.controllers.nameFocus.hasFocus ||
        widget.controllers.lastNameFocus.hasFocus ||
        widget.controllers.locationFocus.hasFocus;
    if (!hasAnyFocus) _handleSave();
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
    final c = widget.controllers;
    final birthText = c.birthDay != null && c.birthMonth != null
        ? '${c.birthDay} ${_months[(c.birthMonth! - 1).clamp(0, 11)]}'
        : '';

    return Container(
      decoration: BoxDecoration(
        color: widget.even ? theme.colorScheme.surface : Colors.transparent,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          _fixedTextCell(c.phone, c.phoneFocus, widget.phoneW, theme, TextInputType.phone, capitalize: false),
          _textCell(c.name, c.nameFocus, 2, theme, null, capitalize: true),
          _textCell(c.lastName, c.lastNameFocus, 2, theme, null, capitalize: true),
          _citasCell(theme),
          _birthdayCell(birthText, widget.birthW, theme, () {
            widget.onEditBirthday((d, m) {
              setState(() {
                c.birthDay = d;
                c.birthMonth = m;
              });
            }, c.birthDay, c.birthMonth);
          }),
          _fixedTextCell(c.location, c.locationFocus, widget.locW, theme, null, capitalize: true),
          const SizedBox(width: 6),
          Container(
            width: _cliDeleteW - 6,
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

  Widget _citasCell(ThemeData theme) {
    return GestureDetector(
      onTap: widget.onTapCitas,
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor)),
        ),
        child: Text(
          '${widget.appointmentCount}',
          style: TextStyle(
            fontSize: 14,
            color: widget.appointmentCount > 0 ? theme.colorScheme.primary : theme.hintColor,
            fontWeight: widget.appointmentCount > 0 ? FontWeight.w600 : null,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _fixedTextCell(TextEditingController ctrl, FocusNode focus, double width, ThemeData theme,
      TextInputType? keyboard, {bool capitalize = false}) {
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor)),
        ),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: keyboard,
          textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
        ),
      ),
    );
  }

  Widget _textCell(TextEditingController ctrl, FocusNode focus, int flex, ThemeData theme,
      TextInputType? keyboard, {bool capitalize = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: theme.dividerColor)),
        ),
        child: TextField(
          controller: ctrl,
          focusNode: focus,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: InputBorder.none,
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: keyboard,
          textCapitalization: capitalize ? TextCapitalization.words : TextCapitalization.none,
        ),
      ),
    );
  }

  Widget _birthdayCell(String text, double width, ThemeData theme, VoidCallback onTap) {
    final isToday = widget.isBirthdayToday;
    final bg = isToday ? theme.colorScheme.tertiaryContainer : Colors.transparent;
    final fg = isToday ? theme.colorScheme.onTertiaryContainer : null;

    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border(right: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(
            text.isEmpty ? 'DD/MM' : text,
            style: TextStyle(
              fontSize: 14,
              color: fg ?? (text.isEmpty ? theme.hintColor : null),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientAppointmentsDialog extends StatefulWidget {
  final Client client;
  final List<Appointment> appointments;

  const _ClientAppointmentsDialog({
    required this.client,
    required this.appointments,
  });

  @override
  State<_ClientAppointmentsDialog> createState() => _ClientAppointmentsDialogState();
}

class _ClientAppointmentsDialogState extends State<_ClientAppointmentsDialog> {
  late final ScrollController _scrollCtrl;
  late final List<Appointment> _ordered;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _ordered = widget.appointments.reversed.toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _daysAgoText(DateTime date) {
    final today = TimeConfig.today();
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return 'Hace $diff días';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Citas de ${widget.client.fullName}'),
      content: SizedBox(
        width: 450,
        height: 400,
        child: widget.appointments.isEmpty
            ? Center(
                child: Text(
                  'Sin citas registradas',
                  style: TextStyle(color: theme.hintColor),
                ),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                itemCount: _ordered.length,
                itemBuilder: (context, index) {
                  final apt = _ordered[index];
                  final dateStr = DateFormat('d/M/yyyy', 'es').format(apt.date);
                  final servicesText = apt.serviceEntries
                      .map((e) => e.name.isNotEmpty ? e.name : 'Servicio')
                      .join(', ');
                  final daysAgo = _daysAgoText(apt.date);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                        ),
                      ),
                      title: Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        servicesText.isNotEmpty ? servicesText : 'Sin servicios',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            daysAgo,
                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        AppData.instance.requestNavigateToDate(apt.date);
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class _BirthdayDialog extends StatefulWidget {
  final int? day;
  final int? month;
  const _BirthdayDialog({this.day, this.month});

  @override
  State<_BirthdayDialog> createState() => _BirthdayDialogState();
}

class _BirthdayDialogState extends State<_BirthdayDialog> {
  late int? _day;
  late int? _month;

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _month = widget.month;
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];

    return AlertDialog(
      title: const Text('Cumpleaños'),
      content: Row(
        children: [
          SizedBox(
            width: 80,
            child: DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'Día', isDense: true),
              items: List.generate(31, (i) => i + 1)
                  .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                  .toList(),
              onChanged: (v) => setState(() => _day = v),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: _month,
              decoration: const InputDecoration(labelText: 'Mes', isDense: true),
              items: List.generate(12, (i) => i + 1)
                  .map((m) =>
                      DropdownMenuItem(value: m, child: Text(months[m - 1])))
                  .toList(),
              onChanged: (v) => setState(() => _month = v),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, -1),
          child: const Text('Sin cumpleaños'),
        ),
        FilledButton(
          onPressed: _day != null && _month != null
              ? () => Navigator.pop(context, _month! * 100 + _day!)
              : null,
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
