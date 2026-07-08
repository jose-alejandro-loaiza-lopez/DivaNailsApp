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
  String _search = '';
  late List<Service> _filtered;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedIds);
    _filtered = widget.services;
  }

  void _onSearch(String v) {
    setState(() {
      _search = v;
      final q = _search.toLowerCase();
      _filtered = widget.services.where((s) => s.name.toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar servicios'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre del servicio...',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onSearch,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final svc = _filtered[index];
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
          ],
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
