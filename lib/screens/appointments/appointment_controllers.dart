import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../models/manicurist.dart';
import '../../utils/formatters.dart';

class AptRowControllers {
  String clientName = '';
  String clientPhone = '';
  int? clientId;
  String time24 = '';
  List<ServiceEntry> selectedServiceEntries = [];
  String servicesText = '';
  int? selectedManicuristId;
  String manicuristName = '';
  double totalPrice = 0;
  List<PaymentEntry> payments = [];
  String paymentText = '';
  double adicional = 0;
  String descripcion = '';
  final descCtrl = TextEditingController();
  final adicCtrl = TextEditingController();

  void updateServices(List<ServiceEntry> entries, List<Service> services) {
    selectedServiceEntries = List.from(entries);
    servicesText = entries.map((e) {
      final svc = services.cast<Service?>().firstWhere(
        (s) => s?.id == e.serviceId,
        orElse: () => null,
      );
      final name = svc?.name ?? (e.name.isNotEmpty ? e.name : '?');
      return '$name (\$${formatPrice(e.price)})';
    }).join(', ');
  }

  void updateManicuristName(int? id, List<Manicurist> manicurists) {
    if (id == null) {
      manicuristName = '';
      return;
    }
    final man = manicurists.cast<Manicurist?>().firstWhere(
      (m) => m?.id == id,
      orElse: () => null,
    );
    manicuristName = man?.name ?? '?';
  }

  void updatePayments(List<PaymentEntry> newPayments) {
    payments = List.from(newPayments);
    paymentText = newPayments
        .map((p) => '${p.displayMethod} \$${formatPrice(p.amount)}')
        .join(' + ');
  }

  bool get hasPaymentError {
    if (payments.isEmpty) return false;
    final sum = payments.fold<double>(0, (s, p) => s + p.amount);
    return (sum - totalPrice - adicional).abs() > 0.01;
  }

  void dispose() {
    descCtrl.dispose();
    adicCtrl.dispose();
  }
}
