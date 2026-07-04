import 'dart:convert';
import '../services/time_config.dart';

class ServiceEntry {
  final int serviceId;
  final String name;
  final double price;

  ServiceEntry({required this.serviceId, this.name = '', required this.price});

  Map<String, dynamic> toMap() => {'service_id': serviceId, 'name': name, 'price': price};

  factory ServiceEntry.fromMap(Map<String, dynamic> map) => ServiceEntry(
        serviceId: map['service_id'] as int,
        name: (map['name'] as String?) ?? '',
        price: (map['price'] as num).toDouble(),
      );
}

class PaymentEntry {
  final String method;
  final double amount;

  PaymentEntry({required this.method, required this.amount});

  Map<String, dynamic> toMap() => {'method': method, 'amount': amount};

  factory PaymentEntry.fromMap(Map<String, dynamic> map) => PaymentEntry(
        method: map['method'] as String,
        amount: (map['amount'] as num).toDouble(),
      );

  String get displayMethod {
    switch (method) {
      case 'nequi':
        return 'Nequi';
      case 'bancolombia':
        return 'Bancolombia';
      case 'daviplata':
        return 'Daviplata';
      case 'efectivo':
        return 'Efectivo';
      default:
        return method;
    }
  }

  static const List<String> allMethods = [
    'nequi',
    'bancolombia',
    'daviplata',
    'efectivo',
  ];

  static const List<String> allDisplayNames = [
    'Nequi',
    'Bancolombia',
    'Daviplata',
    'Efectivo',
  ];
}

class Appointment {
  final int? id;
  final String clientName;
  final int? clientId;
  final String clientPhone;
  final List<ServiceEntry> serviceEntries;
  final int? manicuristId;
  final String manicuristName;
  final DateTime date;
  final double totalPrice;
  final List<PaymentEntry> payments;
  final String time;
  final double adicional;
  final String descripcion;

  Appointment({
    this.id,
    this.clientName = '',
    this.clientId,
    this.clientPhone = '',
    required this.serviceEntries,
    this.manicuristId,
    this.manicuristName = '',
    required this.date,
    required this.totalPrice,
    List<PaymentEntry>? payments,
    this.time = '',
    this.adicional = 0,
    this.descripcion = '',
  }) : payments = payments ?? [];

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'client_name': clientName,
      'client_id': clientId,
      'client_phone': clientPhone,
      'service_ids': jsonEncode(serviceEntries.map((e) => e.toMap()).toList()),
      'manicurist_id': manicuristId,
      'manicurist_name': manicuristName,
      'date': _dateToStr(date),
      'total_price': totalPrice,
      'payment_data': jsonEncode(payments.map((p) => p.toMap()).toList()),
      'time': time,
      'adicional': adicional,
      'descripcion': descripcion,
    };
  }

  factory Appointment.fromMap(Map<String, dynamic> map) {
    final raw = jsonDecode(map['service_ids'] as String) as List;
    final entries = raw
        .map((e) => ServiceEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    final payRaw = jsonDecode(map['payment_data'] as String) as List;
    final payments = payRaw
        .map((e) => PaymentEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    return Appointment(
      id: map['id'] as int?,
      clientName: (map['client_name'] as String?) ?? '',
      clientId: map['client_id'] as int?,
      clientPhone: (map['client_phone'] as String?) ?? '',
      serviceEntries: entries,
      manicuristId: map['manicurist_id'] as int?,
      manicuristName: (map['manicurist_name'] as String?) ?? '',
      date: _strToDate(map['date'] as String),
      totalPrice: (map['total_price'] as num).toDouble(),
      payments: payments,
      time: map['time'] as String? ?? '',
      adicional: (map['adicional'] as num?)?.toDouble() ?? 0,
      descripcion: map['descripcion'] as String? ?? '',
    );
  }

  List<int> get serviceIds => serviceEntries.map((e) => e.serviceId).toList();

  Appointment copyWith({
    int? id,
    String? clientName,
    int? clientId,
    String? clientPhone,
    List<ServiceEntry>? serviceEntries,
    int? manicuristId,
    String? manicuristName,
    DateTime? date,
    double? totalPrice,
    List<PaymentEntry>? payments,
    String? time,
    double? adicional,
    String? descripcion,
  }) {
    return Appointment(
      id: id ?? this.id,
      clientName: clientName ?? this.clientName,
      clientId: clientId ?? this.clientId,
      clientPhone: clientPhone ?? this.clientPhone,
      serviceEntries: serviceEntries ?? this.serviceEntries,
      manicuristId: manicuristId ?? this.manicuristId,
      manicuristName: manicuristName ?? this.manicuristName,
      date: date ?? this.date,
      totalPrice: totalPrice ?? this.totalPrice,
      payments: payments ?? this.payments,
      time: time ?? this.time,
      adicional: adicional ?? this.adicional,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  static String _dateToStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _strToDate(String s) {
    final parts = s.split('-');
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    final utcMidnight = DateTime.utc(y, m, d);
    return utcMidnight.add(Duration(hours: -TimeConfig.offsetHours()));
  }
}
