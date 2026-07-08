import 'package:flutter/material.dart';

class AppointmentHeaderRow extends StatelessWidget {
  final ValueNotifier<double> horaW, clienteW, telW, serviciosW, descW, manW, adicW, pagoW, totalW;
  final void Function(int, double) onDividerDrag;
  final VoidCallback onDividerDragEnd;
  const AppointmentHeaderRow({
    super.key,
    required this.horaW, required this.clienteW, required this.telW,
    required this.serviciosW, required this.descW, required this.manW,
    required this.adicW, required this.pagoW, required this.totalW,
    required this.onDividerDrag,
    required this.onDividerDragEnd,
  });

  static const double dividerWidth = 6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outline, width: 1)),
      ),
      child: Row(
        children: [
          _hFixed('Hora', horaW, theme),
          _div(0, theme),
          _hFixed('Cliente', clienteW, theme),
          _div(1, theme),
          _hFixed('Teléfono', telW, theme),
          _div(2, theme),
          _hFixed('Servicios', serviciosW, theme),
          _div(3, theme),
          _hFixed('Manicurista', manW, theme),
          _div(4, theme),
          _hFixed('Descripción', descW, theme),
          _div(5, theme),
          _hFixed('Adicional', adicW, theme),
          _div(6, theme),
          _hFixed('Pago', pagoW, theme),
          _div(7, theme),
          _hFixed('Total', totalW, theme),
          _div(8, theme),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _div(int colIndex, ThemeData theme) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => onDividerDrag(colIndex, d.delta.dx),
        onHorizontalDragEnd: (_) => onDividerDragEnd(),
        child: Container(
          width: dividerWidth,
          height: 48,
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
          ),
        ),
      ),
    );
  }

  Widget _hFixed(String text, ValueNotifier<double> widthNotifier, ThemeData theme) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        return SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
          ),
        );
      },
    );
  }
}
