import 'package:flutter/material.dart';
import '../../models/service.dart';
import '../../utils/formatters.dart';

class ServicesSelectionDialog extends StatefulWidget {
  final List<Service> services;
  final List<int> selectedIds;
  const ServicesSelectionDialog({super.key, required this.services, required this.selectedIds});

  @override
  State<ServicesSelectionDialog> createState() => _ServicesSelectionDialogState();
}

class _ServicesSelectionDialogState extends State<ServicesSelectionDialog> {
  late List<int> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar servicios'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.services.length,
          itemBuilder: (context, index) {
            final svc = widget.services[index];
            final isSelected = _selected.contains(svc.id);
            return CheckboxListTile(
              title: Text(svc.name),
              subtitle: Text('\$${formatPrice(svc.price)}'),
              value: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _selected.add(svc.id!);
                  } else {
                    _selected.remove(svc.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _selected), child: const Text('Aceptar')),
      ],
    );
  }
}
