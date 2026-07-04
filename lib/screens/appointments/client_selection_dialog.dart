import 'package:flutter/material.dart';
import '../../models/client.dart';

class ClientSelectionDialog extends StatefulWidget {
  final List<Client> clients;
  const ClientSelectionDialog({super.key, required this.clients});

  @override
  State<ClientSelectionDialog> createState() => _ClientSelectionDialogState();
}

class _ClientSelectionDialogState extends State<ClientSelectionDialog> {
  String _search = '';
  late List<Client> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.clients;
  }

  void _onSearch(String v) {
    setState(() {
      _search = v;
      _filtered = widget.clients.where((c) {
        final q = _search.toLowerCase();
        return c.name.toLowerCase().contains(q) ||
            c.lastName.toLowerCase().contains(q) ||
            c.phone.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar cliente'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, apellido o teléfono...',
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
                  final c = _filtered[index];
                  return ListTile(
                    dense: true,
                    title: Text('${c.name} ${c.lastName}'),
                    subtitle: Text(c.phone),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
