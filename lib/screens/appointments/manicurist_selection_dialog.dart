import 'package:flutter/material.dart';
import '../../models/manicurist.dart';

class ManicuristSelectionDialog extends StatefulWidget {
  final List<Manicurist> manicurists;
  final int? selectedId;
  const ManicuristSelectionDialog({super.key, required this.manicurists, required this.selectedId});

  @override
  State<ManicuristSelectionDialog> createState() => _ManicuristSelectionDialogState();
}

class _ManicuristSelectionDialogState extends State<ManicuristSelectionDialog> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleccionar manicurista'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: RadioGroup<int>(
                groupValue: _selected,
                onChanged: (val) { setState(() => _selected = val); },
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.manicurists.length,
                  itemBuilder: (context, index) {
                    final man = widget.manicurists[index];
                    return RadioListTile<int>(
                      title: Text(man.name),
                      value: man.id!,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, -1), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('Aceptar')),
      ],
    );
  }
}
