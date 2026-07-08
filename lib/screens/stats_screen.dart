import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/appointment.dart';
import '../models/manicurist.dart';
import '../models/service.dart';
import '../models/client.dart';
import '../services/app_data.dart';
import '../services/time_config.dart';
import '../services/theme_service.dart';
import '../utils/formatters.dart';

enum _DateMode { range, week }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _db = DatabaseHelper.instance;
  DateTime _from = TimeConfig.today();
  DateTime _to = TimeConfig.today();
  List<Appointment> _appointments = [];
  List<Manicurist> _manicurists = [];
  List<Service> _services = [];
  List<Client> _clients = [];
  bool _loading = true;
  _DateMode _mode = _DateMode.week;
  late int _weekNumber;
  late int _weekYear;

  @override
  void initState() {
    super.initState();
    AppData.instance.addListener(_onAppDataChanged);
    _initWeek();
    _calculate();
  }

  @override
  void dispose() {
    AppData.instance.removeListener(_onAppDataChanged);
    super.dispose();
  }

  void _onAppDataChanged() => _calculate();

  void _initWeek() {
    final (week, year) = _isoWeek(TimeConfig.today());
    _weekNumber = week;
    _weekYear = year;
    _applyWeek();
  }

  (int, int) _isoWeek(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final thursday = _isoThursday(d);
    final year = thursday.year;
    final jan1 = DateTime.utc(year, 1, 1);
    final week = ((thursday.difference(jan1).inDays + jan1.weekday - 1) / 7).ceil();
    return (week < 1 ? 1 : week, year);
  }

  DateTime _isoThursday(DateTime d) {
    final weekday = d.weekday;
    return d.add(Duration(days: DateTime.thursday - weekday));
  }

  DateTime _mondayOfWeek(int year, int week) {
    final jan1 = DateTime.utc(year, 1, 1);
    final thursday = _isoThursday(jan1);
    final firstMonday = thursday.subtract(Duration(days: DateTime.thursday - DateTime.monday));
    return firstMonday.add(Duration(days: (week - 1) * 7));
  }

  int _isoWeeksInYear(int year) {
    final dec31 = DateTime.utc(year, 12, 31);
    final week = _isoWeek(dec31);
    return week.$1 == 1 ? _isoWeek(DateTime.utc(year, 12, 24)).$1 : week.$1;
  }

  void _applyWeek() {
    final monday = _mondayOfWeek(_weekYear, _weekNumber);
    final sunday = monday.add(const Duration(days: 6));
    setState(() {
      _from = monday;
      _to = sunday;
    });
  }

  void _previousWeek() {
    setState(() {
      _weekNumber--;
      if (_weekNumber < 1) {
        _weekYear--;
        _weekNumber = _isoWeeksInYear(_weekYear);
      }
    });
    _applyWeek();
    _calculate();
  }

  void _nextWeek() {
    final maxWeeks = _isoWeeksInYear(_weekYear);
    setState(() {
      _weekNumber++;
      if (_weekNumber > maxWeeks) {
        _weekNumber = 1;
        _weekYear++;
      }
    });
    _applyWeek();
    _calculate();
  }

  void _pickWeekDialog() {
    final now = TimeConfig.today();
    int dialogYear = _weekYear;
    final todayWeek = _isoWeek(TimeConfig.today()).$1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final weeks = <Map<String, dynamic>>[];
          final maxWeeks = _isoWeeksInYear(dialogYear);
          for (int w = 1; w <= maxWeeks; w++) {
            final start = _mondayOfWeek(dialogYear, w);
            final end = start.add(const Duration(days: 6));
            weeks.add({'week': w, 'start': start, 'end': end});
          }
          final defaultWeek = weeks.indexWhere((w) => (w['week'] as int) == _weekNumber && dialogYear == _weekYear);
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(
                  child: Text('Seleccionar semana', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 22),
                  onPressed: () => setDialogState(() => dialogYear--),
                ),
                Text('$dialogYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: () => setDialogState(() => dialogYear++),
                ),
              ],
            ),
            content: SizedBox(
              width: 800,
              height: 480,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.5,
                ),
                itemCount: weeks.length,
                itemBuilder: (context, index) {
                  final w = weeks[index];
                  final start = w['start'] as DateTime;
                  final end = w['end'] as DateTime;
                  final isSelected = index == defaultWeek;
                  final isCurrentWeek = (w['week'] as int) == todayWeek && (w['start'] as DateTime).year == now.year;
                  Color? bg;
                  if (isSelected) {
                    bg = Theme.of(context).colorScheme.primaryContainer;
                  } else if (isCurrentWeek) {
                    bg = Theme.of(context).colorScheme.tertiaryContainer;
                  }
                  return Material(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(ctx, {'week': w['week'], 'year': dialogYear}),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sem ${w['week']}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (isSelected || isCurrentWeek) ? FontWeight.bold : FontWeight.normal)),
                            Text('${DateFormat('d/M', 'es').format(start)} – ${DateFormat('d/M', 'es').format(end)}',
                                style: TextStyle(fontSize: 10, color: Theme.of(context).hintColor)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ],
          );
        },
      ),
    ).then((val) {
      if (val != null) {
        final data = val as Map<String, dynamic>;
        setState(() {
          _weekNumber = data['week'] as int;
          _weekYear = data['year'] as int;
        });
        _applyWeek();
        _calculate();
      }
    });
  }

  Future<void> _calculate() async {
    setState(() => _loading = true);
    final appointments = await _db.getAppointmentsInRange(_from, _to);
    final manicurists = await _db.getManicurists();
    final services = await _db.getServices();
    final clients = await _db.getClients();
    setState(() {
      _appointments = appointments;
      _manicurists = manicurists;
      _services = services;
      _clients = clients;
      _loading = false;
    });
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es'),
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _from = picked);
      _calculate();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('es'),
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _to = picked);
      _calculate();
    }
  }

  double get _totalGross =>
      _appointments.fold<double>(0, (s, a) => s + a.totalPrice + a.adicional);

  Map<int, _ManStats> get _statsByManicurist {
    final map = <int, _ManStats>{};
    for (final apt in _appointments) {
      final mid = apt.manicuristId;
      if (mid == null) continue;
      final man = _manicurists.cast<Manicurist?>().firstWhere(
        (m) => m?.id == mid,
        orElse: () => null,
      );
      final pct = man?.profitPercentage ?? 40.0;
      final entry = map.putIfAbsent(mid, () => _ManStats(name: man?.name ?? '?', percentage: pct));
      entry.gross += apt.totalPrice + apt.adicional;
      entry.count++;
    }
    return map;
  }

  Map<String, double> get _paymentsByMethod {
    final map = <String, double>{};
    for (final apt in _appointments) {
      for (final pay in apt.payments) {
        map[pay.method] = (map[pay.method] ?? 0) + pay.amount;
      }
    }
    return map;
  }

  String _methodDisplayName(String method) {
    switch (method) {
      case 'nequi': return 'Nequi';
      case 'bancolombia': return 'Bancolombia';
      case 'daviplata': return 'Daviplata';
      case 'efectivo': return 'Efectivo';
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = _statsByManicurist;
    final totalGross = _totalGross;
    final totalNet = stats.values.fold<double>(0, (s, e) => s + e.net);
    final payments = _paymentsByMethod;
    final totalPayments = payments.values.fold<double>(0, (s, v) => s + v);

    return Scaffold(      appBar: AppBar(
        title: const Text('Caja'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Mode selector + date controls
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              children: [
                SegmentedButton<_DateMode>(
                  segments: const [
                    ButtonSegment(value: _DateMode.week, label: Text('Semana')),
                    ButtonSegment(value: _DateMode.range, label: Text('Rango')),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (sel) {
                    setState(() {
                      _mode = sel.first;
                      if (_mode == _DateMode.range) {
                        _from = TimeConfig.today();
                        _to = TimeConfig.today();
                      }
                    });
                    if (_mode == _DateMode.week) {
                      _initWeek();
                    }
                    _calculate();
                  },
                ),
                const SizedBox(height: 12),
                if (_mode == _DateMode.week)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _previousWeek,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickWeekDialog,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Semana $_weekNumber',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                    '${DateFormat('EEEE d/M/yyyy', 'es').format(_from)} – ${DateFormat('EEEE d/M/yyyy', 'es').format(_to)}',
                                    style: TextStyle(fontSize: 13, color: theme.hintColor),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _nextWeek,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton('Desde', _from, theme, _pickFrom),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Icon(Icons.arrow_forward, size: 18),
                      ),
                      Expanded(
                        child: _dateButton('Hasta', _to, theme, _pickTo),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _appointments.isEmpty
                    ? Center(
                        child: Text('Sin registros en el período',
                            style: TextStyle(color: theme.hintColor)))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          // Total gross
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Total bruto',
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text('\$${_fmt(totalGross)}',
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Per-manicurist header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 2, child: Text('Manicurista',
                                    style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(flex: 1, child: Text('Citas',
                                    style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Expanded(flex: 1, child: Text('Bruto',
                                    style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                                Expanded(flex: 1, child: Text('%',
                                    style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                                Expanded(flex: 1, child: Text('Ganancia',
                                    style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Per-manicurist rows
                          ...stats.values.map((s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom: BorderSide(color: theme.dividerColor)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                        flex: 2,
                                        child: Text(s.name, style: const TextStyle(fontSize: 14))),
                                    Expanded(
                                        flex: 1,
                                        child: Text('${s.count}',
                                            style: const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.center)),
                                    Expanded(
                                        flex: 1,
                                        child: Text('\$${_fmt(s.gross)}',
                                            style: const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.right)),
                                    Expanded(
                                        flex: 1,
                                        child: Text('${formatPrice(s.percentage)}%',
                                            style: const TextStyle(fontSize: 14),
                                            textAlign: TextAlign.center)),
                                    Expanded(
                                        flex: 1,
                                        child: Text('\$${_fmt(s.net)}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF388E3C)),
                                            textAlign: TextAlign.right)),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                          // Total net
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total a pagar',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer)),
                                Text('\$${_fmt(totalNet)}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onPrimaryContainer)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Business profit
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Ganancia del negocio',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800)),
                                Text('\$${_fmt(totalGross - totalNet)}',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Payment methods
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Medios de pago',
                                      style: TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 12),
                                  ...PaymentEntry.allMethods.map((m) {
                                    final amount = payments[m] ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_methodDisplayName(m),
                                              style: const TextStyle(fontSize: 14)),
                                          Text('\$${_fmt(amount)}',
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    );
                                  }),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total pagado',
                                          style: TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.bold)),
                                      Text('\$${_fmt(totalPayments)}',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.primary)),
                                    ],
                                  ),
                                  if (totalGross - totalPayments > 1)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Sin pago',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.colorScheme.error,
                                                  fontWeight: FontWeight.w500)),
                                          Text('\$${_fmt(totalGross - totalPayments)}',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  color: theme.colorScheme.error,
                                                  fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.file_download),
                              label: const Text('Exportar a Excel'),
                              onPressed: _exportToExcel,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel() async {
    if (_appointments.isEmpty) return;
    final buf = StringBuffer('\uFEFF');
    buf.writeln(
        'Fecha;Hora;Cliente;Teléfono;Servicios;Descripción;Manicurista;Adicional;Pago;Total');
    for (final apt in _appointments) {
      final servicesText = apt.serviceEntries
          .map((e) {
            final svc = _services.where((s) => s.id == e.serviceId).firstOrNull;
            final name = svc?.name ?? (e.name.isNotEmpty ? e.name : '?');
            return '$name (\$${formatPrice(e.price)})';
          })
          .join(', ');
      final manicurist = apt.manicuristId != null
          ? (_manicurists
              .where((m) => m.id == apt.manicuristId)
              .firstOrNull
              ?.name ?? apt.manicuristName)
          : apt.manicuristName;
      final phone = apt.clientId != null
          ? (_clients.where((c) => c.id == apt.clientId).firstOrNull?.phone ?? apt.clientPhone)
          : apt.clientPhone;
      final total = apt.totalPrice + apt.adicional;
      final paid = apt.payments.fold<double>(0, (s, p) => s + p.amount);
      String paymentText;
      if (apt.payments.isEmpty) {
        paymentText = '--';
      } else {
        paymentText = apt.payments
            .map((p) => '${p.displayMethod} (\$${_fmt(p.amount)})')
            .join(' + ');
        final diff = total - paid;
        if (diff.abs() > 0.01) {
          paymentText += ' | Diferencia: \$${_fmt(diff)}';
        }
      }
      final dateStr = DateFormat('d/M/yyyy', 'es').format(apt.date);
      final timeStr = apt.time.isEmpty ? '--:--' : apt.time;
      buf.writeln(
          '$dateStr;$timeStr;${apt.clientName};$phone;"$servicesText";${apt.descripcion};$manicurist;\$${_fmt(apt.adicional)};$paymentText;\$${_fmt(total)}');
    }
    try {
      final dir = Directory(ThemeService.instance.effectiveExportPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final now = DateTime.now();
      final ts = DateFormat('yyyyMMdd_HHmmss', 'es').format(now);
      final file = File('${dir.path}\\DivaNails_${DateFormat('yyyyMMdd', 'es').format(_from)}-${DateFormat('yyyyMMdd', 'es').format(_to)}_$ts.csv');
      await file.writeAsString(buf.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        final snackBar = SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Exportado a ${file.path}'),
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Process.start('cmd', ['/c', 'start', '', file.path]);
            },
          ),
        );
        final controller = ScaffoldMessenger.of(context).showSnackBar(snackBar);
        Future.delayed(const Duration(seconds: 5)).then((_) => controller.close());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Widget _dateButton(String label, DateTime date, ThemeData theme, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
            const SizedBox(height: 2),
            Text(DateFormat('d/M/yyyy', 'es').format(date),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => formatPriceWithDots(v);
}

class _ManStats {
  final String name;
  final double percentage;
  double gross = 0;
  int count = 0;

  _ManStats({required this.name, required this.percentage});

  double get net => gross * percentage / 100;
}
