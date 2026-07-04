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
          _hFixed('Hora', horaW, theme, false),
          _div(0),
          _hFixed('Cliente', clienteW, theme, false),
          _div(1),
          _hFixed('Teléfono', telW, theme, false),
          _div(2),
          _hFixed('Servicios', serviciosW, theme, false),
          _div(3),
          _hFixed('Descripción', descW, theme, false),
          _div(4),
          _hFixed('Manicurista', manW, theme, false),
          _div(5),
          _hFixed('Adicional', adicW, theme, false),
          _div(6),
          _hFixed('Pago', pagoW, theme, false),
          _div(7),
          _hFixed('Total', totalW, theme, false),
          _div(8),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _div(int colIndex) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (d) => onDividerDrag(colIndex, d.delta.dx),
        onHorizontalDragEnd: (_) => onDividerDragEnd(),
        child: Container(
          width: dividerWidth,
          height: 48,
          color: Colors.transparent,
        ),
      ),
    );
  }

  Widget _hFixed(String text, ValueNotifier<double> widthNotifier, ThemeData theme, bool hasLeftBorder) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        return SizedBox(
          width: width,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: hasLeftBorder
                ? BoxDecoration(
                    border: Border(left: BorderSide(color: theme.colorScheme.outlineVariant)),
                  )
                : null,
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: theme.colorScheme.onPrimaryContainer)),
          ),
        );
      },
    );
  }
}
