import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../utils/formatters.dart';

class PaymentDialog extends StatefulWidget {
  final double total;
  final List<PaymentEntry> payments;
  const PaymentDialog({super.key, required this.total, required this.payments});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late Map<String, TextEditingController> _controllers;
  final _methods = PaymentEntry.allMethods;

  @override
  void initState() {
    super.initState();
    _controllers = {};
    for (final method in _methods) {
      final existing = widget.payments.cast<PaymentEntry?>().firstWhere(
        (p) => p?.method == method,
        orElse: () => null,
      );
      _controllers[method] = TextEditingController(
        text: existing != null ? formatPrice(existing.amount) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  double get _assignedTotal {
    double sum = 0;
    for (final method in _methods) {
      final val = double.tryParse(_controllers[method]!.text.replaceAll(',', '.'));
      sum += val ?? 0;
    }
    return sum;
  }

  List<PaymentEntry> _buildPayments() {
    final result = <PaymentEntry>[];
    for (final method in _methods) {
      final val = double.tryParse(_controllers[method]!.text.replaceAll(',', '.'));
      if (val != null && val > 0) {
        result.add(PaymentEntry(method: method, amount: val));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.total - _assignedTotal;
    return AlertDialog(
      title: Text('Configurar pago - \$${formatPrice(widget.total)}'),
      content: SizedBox(
        width: 300,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (int i = 0; i < _methods.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(PaymentEntry.allDisplayNames[i], style: const TextStyle(fontSize: 14)),
                    ),
                    const Text('\$ '),
                    Expanded(
                      child: TextField(
                        controller: _controllers[_methods[i]],
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                          hintText: '0',
                        ),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Row(
              children: [
                const Text('Restante: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '\$${formatPrice(remaining)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: remaining.abs() <= 0.01 ? Colors.green : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _buildPayments()),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
