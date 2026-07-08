import 'package:flutter/material.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import 'appointment_controllers.dart';

const double appointmentDeleteWidth = 36;
const double appointmentDividerWidth = 6;

String formatTime12h(String time24) {
  if (time24.isEmpty) return '';
  final parts = time24.split(':');
  if (parts.length != 2) return time24;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1].padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $period';
}

class AppointmentRow extends StatelessWidget {
  final AptRowControllers controllers;
  final bool isNewRow;
  final bool even;
  final bool readOnly;
  final bool hasPaymentError;
  final ValueNotifier<double> horaW, clienteW, telW, serviciosW, descW, manW, adicW, pagoW, totalW;
  final VoidCallback onTapClient;
  final VoidCallback onTapServices;
  final VoidCallback onTapManicurist;
  final VoidCallback onTapPayment;
  final VoidCallback onTapTime;
  final VoidCallback? onDelete;
  final Future<void> Function() onSave;

  const AppointmentRow({
    super.key,
    required this.controllers,
    required this.isNewRow,
    required this.even,
    required this.readOnly,
    required this.hasPaymentError,
    required this.horaW, required this.clienteW, required this.telW,
    required this.serviciosW, required this.descW, required this.manW,
    required this.adicW, required this.pagoW, required this.totalW,
    required this.onTapClient,
    required this.onTapServices,
    required this.onTapManicurist,
    required this.onTapPayment,
    required this.onTapTime,
    this.onDelete,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isNewRow
        ? theme.colorScheme.surfaceContainerLow
        : (even ? theme.colorScheme.surface : Colors.transparent);
    final border = Border(bottom: BorderSide(color: theme.dividerColor));
    final dc = controllers;
    return Container(
      decoration: BoxDecoration(color: bg, border: border),
      child: Row(
        children: [
          _fixedTimeCell(controllers.time24, horaW, theme, readOnly ? null : onTapTime),
          const SizedBox(width: appointmentDividerWidth),
          _fixedTapCell(controllers.clientName, 'Toca para seleccionar...', clienteW, theme,
              readOnly ? null : onTapClient, null),
          const SizedBox(width: appointmentDividerWidth),
          _fixedTapCell(controllers.clientPhone, '', telW, theme, null, null),
          const SizedBox(width: appointmentDividerWidth),
          _fixedTapCell(controllers.servicesText, 'Toca para seleccionar...', serviciosW, theme,
              readOnly ? null : onTapServices, null),
          const SizedBox(width: appointmentDividerWidth),
          _fixedTapCell(controllers.manicuristName, 'Toca para asignar...', manW, theme,
              readOnly ? null : onTapManicurist, null),
          const SizedBox(width: appointmentDividerWidth),
          _descCell(dc, descW, theme, readOnly),
          const SizedBox(width: appointmentDividerWidth),
          _adicCell(dc, adicW, theme, readOnly),
          const SizedBox(width: appointmentDividerWidth),
          _fixedPaymentCell(controllers.paymentText, pagoW, theme, onTapPayment, hasPaymentError),
          const SizedBox(width: appointmentDividerWidth),
          _fixedPriceCell(controllers.totalPrice + controllers.adicional, totalW, theme),
          const SizedBox(width: appointmentDividerWidth),
          Container(
            width: appointmentDeleteWidth,
            height: 48,
            alignment: Alignment.centerLeft,
            child: onDelete != null
                ? GestureDetector(
                    onTap: onDelete,
                    child: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _descCell(AptRowControllers dc, ValueNotifier<double> widthNotifier, ThemeData theme, bool readOnly) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, w, _) => SizedBox(
        width: w,
        child: Focus(
          onFocusChange: (f) {
            if (!f && !readOnly) {
              dc.descripcion = dc.descCtrl.text;
              onSave().catchError(ErrorHandler.show);
            }
          },
          child: TextField(
              controller: dc.descCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              readOnly: readOnly,
            ),
        ),
      ),
    );
  }

  Widget _adicCell(AptRowControllers dc, ValueNotifier<double> widthNotifier, ThemeData theme, bool readOnly) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, w, _) => SizedBox(
        width: w,
        child: Focus(
          onFocusChange: (f) {
            if (!f && !readOnly) {
              final text = dc.adicCtrl.text.trim();
              if (text.isNotEmpty) {
                final val = double.tryParse(text.replaceAll(',', '.'));
                if (val == null) {
                  ErrorHandler.showMessage('El adicional debe ser un número válido', isError: true);
                  return;
                }
                dc.adicional = val;
              }
              onSave().catchError(ErrorHandler.show);
            }
          },
          child: TextField(
              controller: dc.adicCtrl,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '0',
                prefixText: '\$ ',
              ),
              style: const TextStyle(fontSize: 14),
              keyboardType: TextInputType.number,
              readOnly: readOnly,
            ),
        ),
      ),
    );
  }

  Widget _fixedTimeCell(String time24, ValueNotifier<double> widthNotifier, ThemeData theme, VoidCallback? onTap) {
    final display = formatTime12h(time24);
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              display.isEmpty ? '--:--' : display,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: display.isEmpty ? theme.hintColor : null,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fixedTapCell(String? text, String hint, ValueNotifier<double> widthNotifier, ThemeData theme,
      VoidCallback? onTap, Color? textColor) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        final t = text ?? '';
        final displayText = t.isEmpty ? hint : t;
        final isHint = t.isEmpty;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 14,
                color: textColor ?? (isHint ? theme.hintColor : null),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _fixedPaymentCell(String text, ValueNotifier<double> widthNotifier, ThemeData theme,
      VoidCallback? onTap, bool hasError) {
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        final displayText = text.isEmpty ? 'Toca para configurar...' : text;
        final isHint = text.isEmpty;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: hasError ? theme.colorScheme.error.withValues(alpha: 0.15) : null,
            ),
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 14,
                color: isHint
                    ? theme.hintColor
                    : (hasError ? theme.colorScheme.error : null),
                fontWeight: hasError ? FontWeight.w600 : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }

  Widget _fixedPriceCell(double price, ValueNotifier<double> widthNotifier, ThemeData theme) {
    final cp = '\$${formatPrice(price)}';
    return ValueListenableBuilder<double>(
      valueListenable: widthNotifier,
      builder: (context, width, _) {
        return Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: const BoxDecoration(),
          child: Text(
            cp,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        );
      },
    );
  }
}
