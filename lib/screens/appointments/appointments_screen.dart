import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../database/database_helper.dart';
import '../../models/service.dart';
import '../../models/appointment.dart';
import '../../models/manicurist.dart';
import '../../models/client.dart';
import '../../widgets/date_navigation_bar.dart';
import '../../services/app_data.dart';
import '../../services/time_config.dart';
import '../../utils/formatters.dart';
import 'appointment_controllers.dart';
import 'appointment_header.dart';
import 'appointment_row.dart';
import 'client_selection_dialog.dart';
import 'services_selection_dialog.dart';
import 'manicurist_selection_dialog.dart';
import 'payment_dialog.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _db = DatabaseHelper.instance;
  DateTime _selectedDate = TimeConfig.today();
  DateTime get _today => TimeConfig.today();
  List<Appointment> _appointments = [];
  List<Service> _services = [];
  List<Manicurist> _manicurists = [];
  List<Client> _clients = [];
  Map<int, int> _appointmentCounts = {};
  final _rowControllers = <AptRowControllers>[];
  final _hScrollCtrl = ScrollController();
  final _hScrollBarCtrl = ScrollController();
  final _headerHCtrl = ScrollController();
  final _vScrollCtrl = ScrollController();
  bool _isSyncingH = false;
  bool _loading = true;
  final ValueNotifier<double> _horaW = ValueNotifier(87);
  final ValueNotifier<double> _clienteW = ValueNotifier(131);
  final ValueNotifier<double> _telW = ValueNotifier(105);
  final ValueNotifier<double> _serviciosW = ValueNotifier(355);
  final ValueNotifier<double> _descW = ValueNotifier(197);
  final ValueNotifier<double> _manW = ValueNotifier(107);
  final ValueNotifier<double> _adicW = ValueNotifier(90);
  final ValueNotifier<double> _pagoW = ValueNotifier(297);
  final ValueNotifier<double> _totalW = ValueNotifier(77);
  double _viewportWidth = 0;

  void _recalcWidths() {
    _horaW.value = max(_horaW.value, _columnMins[0]);
    _clienteW.value = max(_clienteW.value, _columnMins[1]);
    _telW.value = max(_telW.value, _columnMins[2]);
    _serviciosW.value = max(_serviciosW.value, _columnMins[3]);
    _descW.value = max(_descW.value, _columnMins[4]);
    _manW.value = max(_manW.value, _columnMins[5]);
    _adicW.value = max(_adicW.value, _columnMins[6]);
    _pagoW.value = max(_pagoW.value, _columnMins[7]);
    _totalW.value = max(_totalW.value, _columnMins[8]);
  }

  Future<void> _saveWidths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('horaW', _horaW.value);
    await prefs.setDouble('clienteW', _clienteW.value);
    await prefs.setDouble('telW', _telW.value);
    await prefs.setDouble('serviciosW', _serviciosW.value);
    await prefs.setDouble('descW', _descW.value);
    await prefs.setDouble('manW', _manW.value);
    await prefs.setDouble('adicW', _adicW.value);
    await prefs.setDouble('pagoW', _pagoW.value);
    await prefs.setDouble('totalW', _totalW.value);
  }

  Future<void> _loadWidthsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _horaW.value = prefs.getDouble('horaW') ?? _horaW.value;
    _clienteW.value = prefs.getDouble('clienteW') ?? _clienteW.value;
    _telW.value = prefs.getDouble('telW') ?? _telW.value;
    _serviciosW.value = prefs.getDouble('serviciosW') ?? _serviciosW.value;
    _descW.value = prefs.getDouble('descW') ?? _descW.value;
    _manW.value = prefs.getDouble('manW') ?? _manW.value;
    _adicW.value = prefs.getDouble('adicW') ?? _adicW.value;
    _pagoW.value = prefs.getDouble('pagoW') ?? _pagoW.value;
    _totalW.value = prefs.getDouble('totalW') ?? _totalW.value;
  }

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _hScrollCtrl.addListener(_syncHeaderScroll);
    _hScrollCtrl.addListener(_syncToScrollBar);
    _hScrollBarCtrl.addListener(_syncFromScrollBar);
    _loadData();
  }

  void _syncHeaderScroll() {
    if (_headerHCtrl.hasClients && _hScrollCtrl.hasClients) {
      _headerHCtrl.jumpTo(_hScrollCtrl.offset);
    }
  }

  void _syncToScrollBar() {
    if (_isSyncingH || !_hScrollBarCtrl.hasClients) return;
    _isSyncingH = true;
    _hScrollBarCtrl.jumpTo(_hScrollCtrl.offset);
    _isSyncingH = false;
  }

  void _syncFromScrollBar() {
    if (_isSyncingH || !_hScrollCtrl.hasClients) return;
    _isSyncingH = true;
    _hScrollCtrl.jumpTo(_hScrollBarCtrl.offset);
    _isSyncingH = false;
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    _hScrollCtrl.removeListener(_syncHeaderScroll);
    _hScrollCtrl.removeListener(_syncToScrollBar);
    _hScrollBarCtrl.removeListener(_syncFromScrollBar);
    for (final rc in _rowControllers) { rc.dispose(); }
    _hScrollCtrl.dispose();
    _hScrollBarCtrl.dispose();
    _headerHCtrl.dispose();
    _vScrollCtrl.dispose();
    _horaW.dispose();
    _clienteW.dispose();
    _telW.dispose();
    _serviciosW.dispose();
    _descW.dispose();
    _manW.dispose();
    _adicW.dispose();
    _pagoW.dispose();
    _totalW.dispose();
    super.dispose();
  }

  static const _columnMins = [87.0, 74.0, 105.0, 87.0, 107.0, 106.0, 90.0, 82.0, 76.0];

  void _onDividerDrag(int colIndex, double delta) {
    setState(() {
      final vals = [_horaW.value, _clienteW.value, _telW.value, _serviciosW.value,
          _manW.value, _descW.value, _adicW.value, _pagoW.value, _totalW.value];

      if (colIndex == 8) {
        vals[8] = max(_columnMins[8], vals[8] + delta);
        final newTotal = vals.fold<double>(0, (s, v) => s + v) + appointmentDeleteWidth + 9 * appointmentDividerWidth;
        if (newTotal < _viewportWidth) {
          vals[8] = max(_columnMins[8], vals[8] + (_viewportWidth - newTotal));
        }
      } else {
        vals[colIndex] = max(_columnMins[colIndex], vals[colIndex] + delta);
        if (colIndex < 8) {
          vals[colIndex + 1] = max(_columnMins[colIndex + 1], vals[colIndex + 1] - delta);
        }
        final newTotal = vals.fold<double>(0, (s, v) => s + v) + appointmentDeleteWidth + 9 * appointmentDividerWidth;
        if (newTotal < _viewportWidth) {
          final fix = _viewportWidth - newTotal;
          vals[colIndex + 1] = max(_columnMins[colIndex + 1], vals[colIndex + 1] + fix);
        }
      }

      _horaW.value = vals[0]; _clienteW.value = vals[1]; _telW.value = vals[2];
      _serviciosW.value = vals[3]; _manW.value = vals[4]; _descW.value = vals[5];
      _adicW.value = vals[6]; _pagoW.value = vals[7]; _totalW.value = vals[8];
    });
  }

  void _onAppDataChanged() {
    final targetDate = AppData.instance.consumeNavigateToDate();
    if (targetDate != null) {
      setState(() => _selectedDate = targetDate);
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appointments = await _db.getAppointmentsByDate(_selectedDate);
      final services = await _db.getServices();
      final manicurists = await _db.getManicurists();
      final clients = await _db.getClients();
      final counts = await _db.getAppointmentCountsGroupedByClient();
      setState(() {
        _appointments = appointments;
        _services = services;
        _manicurists = manicurists;
        _clients = clients;
        _appointmentCounts = counts;
        _loading = false;
        _syncControllers();
        _recalcWidths();
      });
      await _loadWidthsFromPrefs();
      await _saveWidths();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _syncControllers() {
    final needed = _appointments.length + 1;
    while (_rowControllers.length < needed) {
      _rowControllers.add(AptRowControllers());
    }
    while (_rowControllers.length > needed) {
      _rowControllers.removeLast().dispose();
    }
    for (int i = 0; i < _appointments.length; i++) {
      final rc = _rowControllers[i];
      final apt = _appointments[i];
      rc.clientId = apt.clientId;
      final client = apt.clientId != null
          ? _clients.cast<Client?>().firstWhere(
              (c) => c?.id == apt.clientId,
              orElse: () => null,
            )
          : null;
      if (client != null) {
        rc.clientName = client.fullName;
        rc.clientPhone = client.phone;
      } else {
        rc.clientName = apt.clientName;
        rc.clientPhone = apt.clientPhone;
      }
      rc.time24 = apt.time;
      rc.updateServices(apt.serviceEntries, _services);
      rc.selectedManicuristId = apt.manicuristId;
      if (apt.manicuristId != null) {
        final man = _manicurists.cast<Manicurist?>().firstWhere(
          (m) => m?.id == apt.manicuristId,
          orElse: () => null,
        );
        rc.manicuristName = man?.name ?? apt.manicuristName;
      } else {
        rc.manicuristName = apt.manicuristName;
      }
      rc.totalPrice = apt.totalPrice;
      rc.updatePayments(apt.payments);
      rc.adicional = apt.adicional;
      rc.descripcion = apt.descripcion;
      rc.descCtrl.text = apt.descripcion;
      rc.adicCtrl.text = apt.adicional > 0 ? formatPrice(apt.adicional) : '';
    }
    final last = _rowControllers.last;
    last.clientName = '';
    last.clientPhone = '';
    last.clientId = null;
    last.time24 = '';
    last.updateServices([], _services);
    last.selectedManicuristId = null;
    last.manicuristName = '';
    last.totalPrice = 0;
    last.updatePayments([]);
    last.descripcion = '';
    last.descCtrl.text = '';
    last.adicional = 0;
    last.adicCtrl.text = '';
  }

  bool get _isViewingPast => !AppData.instance.devMode && _selectedDate.isBefore(_today);

  bool _isPast(int index) {
    if (index >= _appointments.length) return false;
    return !AppData.instance.devMode && _appointments[index].date.isBefore(_today);
  }

  void _goPreviousDay() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 1)));
    _loadData();
  }

  void _goBack21Days() {
    setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 21)));
    _loadData();
  }

  void _goToToday() {
    setState(() => _selectedDate = TimeConfig.today());
    _loadData();
  }

  void _goNextDay() {
    setState(() => _selectedDate = _selectedDate.add(const Duration(days: 1)));
    _loadData();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es'),
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  void _sortAppointments() {
    _appointments.sort((a, b) {
      final aTime = a.time.isEmpty ? 'Z' : a.time;
      final bTime = b.time.isEmpty ? 'Z' : b.time;
      final cmp = aTime.compareTo(bTime);
      if (cmp != 0) return cmp;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });
  }

  Future<void> _saveRow(int index) async {
    if (index >= _rowControllers.length) return;
    final rc = _rowControllers[index];

    final total = rc.selectedServiceEntries.fold<double>(0, (sum, e) => sum + e.price);
    rc.totalPrice = total;

    final entries = List<ServiceEntry>.from(rc.selectedServiceEntries);
    final payments = List<PaymentEntry>.from(rc.payments);
    final hasContent = rc.clientName.isNotEmpty ||
        rc.time24.isNotEmpty ||
        entries.isNotEmpty ||
        rc.selectedManicuristId != null ||
        payments.isNotEmpty ||
        rc.descripcion.isNotEmpty ||
        rc.adicional > 0;
    if (!hasContent && index >= _appointments.length) return;

    final wasNew = index >= _appointments.length;

    String? oldTime;
    if (!wasNew) oldTime = _appointments[index].time;

    try {
      if (!wasNew) {
        final updated = _appointments[index].copyWith(
          clientName: rc.clientName.trim(),
          clientId: rc.clientId,
          clientPhone: rc.clientPhone ?? '',
          serviceEntries: entries,
          manicuristId: rc.selectedManicuristId,
          manicuristName: rc.manicuristName,
          totalPrice: total,
          payments: payments,
          time: rc.time24,
          adicional: rc.adicional,
          descripcion: rc.descripcion,
        );
        await _db.updateAppointment(updated);
        _appointments[index] = updated;
      } else {
        final id = await _db.insertAppointment(Appointment(
          clientName: rc.clientName.trim(),
          clientId: rc.clientId,
          clientPhone: rc.clientPhone ?? '',
          serviceEntries: entries,
          manicuristId: rc.selectedManicuristId,
          manicuristName: rc.manicuristName,
          date: _selectedDate,
          totalPrice: total,
          payments: payments,
          time: rc.time24,
          adicional: rc.adicional,
          descripcion: rc.descripcion,
        ));
        _appointments.add(Appointment(
          id: id,
          clientName: rc.clientName.trim(),
          clientId: rc.clientId,
          clientPhone: rc.clientPhone ?? '',
          serviceEntries: entries,
          manicuristId: rc.selectedManicuristId,
          manicuristName: rc.manicuristName,
          date: _selectedDate,
          totalPrice: total,
          payments: payments,
          time: rc.time24,
          adicional: rc.adicional,
          descripcion: rc.descripcion,
        ));
      }

      final timeChanged = wasNew || oldTime != rc.time24;
      if (timeChanged) {
        _sortAppointments();
        _syncControllers();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteAppointment(int index) async {
    if (index >= _appointments.length || _isPast(index)) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text('¿Eliminar registro de "${_appointments[index].clientName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _db.deleteAppointment(_appointments[index].id!);
        await _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _selectServices(int index) async {
    if (index >= _rowControllers.length || _isPast(index)) return;
    final rc = _rowControllers[index];
    final result = await showDialog<List<int>>(
      context: context,
      builder: (ctx) => ServicesSelectionDialog(
        services: _services,
        selectedIds: rc.selectedServiceEntries.map((e) => e.serviceId).toList(),
      ),
    );
    if (result != null) {
      final entries = result.map((id) {
        final svc = _services.cast<Service?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
        return ServiceEntry(serviceId: id, name: svc?.name ?? '', price: svc?.price ?? 0);
      }).toList();
      rc.updateServices(entries, _services);
      _saveRow(index);
    }
  }

  Future<void> _selectManicurist(int index) async {
    if (index >= _rowControllers.length || _isPast(index)) return;
    final rc = _rowControllers[index];
    final result = await showDialog<int?>(
      context: context,
      builder: (ctx) => ManicuristSelectionDialog(
        manicurists: _manicurists,
        selectedId: rc.selectedManicuristId,
      ),
    );
    if (result == null || result == -1) return;
    rc.selectedManicuristId = result;
    rc.updateManicuristName(result, _manicurists);
    _saveRow(index);
  }

  Future<void> _configurePayment(int index) async {
    if (index >= _rowControllers.length) return;
    final rc = _rowControllers[index];
    final totalConAdicional = rc.totalPrice + rc.adicional;
    final result = await showDialog<List<PaymentEntry>>(
      context: context,
      builder: (ctx) => PaymentDialog(
        total: totalConAdicional,
        payments: List.from(rc.payments),
      ),
    );
    if (result != null) {
      rc.updatePayments(result);
      _saveRow(index);
    }
  }

  Future<void> _pickTime(int index) async {
    if (index >= _rowControllers.length || _isPast(index)) return;
    final rc = _rowControllers[index];
    var hour = TimeConfig.now().hour;
    var minute = 0;
    final parts = rc.time24.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        hour = h;
        minute = m;
      }
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      initialEntryMode: TimePickerEntryMode.dial,
      helpText: 'Select time',
      builder: (context, child) => Localizations.override(
        context: context,
        locale: const Locale('en', 'US'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked != null) {
      rc.time24 = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      _saveRow(index);
    }
  }

  Future<void> _pickClient(int index) async {
    if (index >= _rowControllers.length || _isPast(index)) return;
    final rc = _rowControllers[index];
    final result = await showDialog<Client>(
      context: context,
      builder: (ctx) => ClientSelectionDialog(clients: _clients, appointmentCounts: _appointmentCounts),
    );
    if (result != null) {
      rc.clientName = result.fullName;
      rc.clientId = result.id;
      rc.clientPhone = result.phone;
      _saveRow(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          DateNavigationBar(
            selectedDate: _selectedDate,
            onPreviousDay: _goPreviousDay,
            onNextDay: _goNextDay,
            onJumpBack21Days: _goBack21Days,
            onGoToToday: _goToToday,
            onTapDate: () => _pickDate(),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _viewportWidth = constraints.maxWidth;
                final total = _horaW.value + _clienteW.value + _telW.value + _serviciosW.value + _descW.value +
                    _manW.value + _adicW.value + _pagoW.value + _totalW.value + appointmentDeleteWidth +
                    9 * appointmentDividerWidth;
                final itemCount = _isViewingPast ? _appointments.length : _rowControllers.length;
                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _headerHCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: total,
                        child: AppointmentHeaderRow(
                          horaW: _horaW, clienteW: _clienteW,
                          telW: _telW, serviciosW: _serviciosW,
                          descW: _descW, manW: _manW,
                          adicW: _adicW, pagoW: _pagoW, totalW: _totalW,
                          onDividerDrag: _onDividerDrag,
                          onDividerDragEnd: _saveWidths,
                        ),
                      ),
                    ),
                    Expanded(
                      child: RawScrollbar(
                        thumbVisibility: true,
                        thickness: 12,
                        controller: _vScrollCtrl,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          controller: _vScrollCtrl,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            controller: _hScrollCtrl,
                            child: SelectionArea(
                              child: SizedBox(
                                width: total,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...List.generate(itemCount, (index) {
                                      final isNew = !_isViewingPast && index == _appointments.length;
                                      final past = _isPast(index);
                                      final hasError = _rowControllers[index].hasPaymentError;
                                      return SizedBox(
                                        height: 48,
                                        child: AppointmentRow(
                                          key: ValueKey('apt_$index'),
                                          controllers: _rowControllers[index],
                                          isNewRow: isNew,
                                          even: index.isEven,
                                          readOnly: past,
                                          hasPaymentError: hasError,
                                          horaW: _horaW, clienteW: _clienteW,
                                          telW: _telW, serviciosW: _serviciosW,
                                          descW: _descW, manW: _manW,
                                          adicW: _adicW, pagoW: _pagoW, totalW: _totalW,
                                          onTapClient: () => _pickClient(index),
                                          onTapServices: () => _selectServices(index),
                                          onTapManicurist: () => _selectManicurist(index),
                                          onTapPayment: () => _configurePayment(index),
                                          onTapTime: () => _pickTime(index),
                                          onDelete: (past || isNew) ? null : () => _deleteAppointment(index),
                                          onSave: () => _saveRow(index),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    RawScrollbar(
                      thumbVisibility: true,
                      thickness: 12,
                      controller: _hScrollBarCtrl,
                      child: SizedBox(
                        height: 12,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _hScrollBarCtrl,
                          child: SizedBox(width: total, height: 1),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
