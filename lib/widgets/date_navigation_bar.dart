import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/time_config.dart';

class DateNavigationBar extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback? onJumpBack21Days;
  final VoidCallback? onGoToToday;
  final VoidCallback? onTapDate;

  const DateNavigationBar({
    super.key,
    required this.selectedDate,
    required this.onPreviousDay,
    required this.onNextDay,
    this.onJumpBack21Days,
    this.onGoToToday,
    this.onTapDate,
  });

  String _daysAgoText(DateTime today) {
    final diff = today.difference(selectedDate).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff > 1) return 'Hace $diff días';
    final abs = diff.abs();
    if (abs == 1) return 'Mañana';
    return 'En $abs días';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = TimeConfig.today();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          if (onJumpBack21Days != null)
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: onJumpBack21Days,
              tooltip: 'Hace 21 días',
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousDay,
            tooltip: 'Día anterior',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTapDate,
              child: Text(
                isToday
                    ? 'Hoy - ${DateFormat('EEEE d/M/yyyy', 'es').format(selectedDate)}'
                    : DateFormat('EEEE d/M/yyyy', 'es').format(selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              _daysAgoText(today),
              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
            tooltip: 'Día siguiente',
          ),
          if (onGoToToday != null)
            IconButton(
              icon: const Icon(Icons.today),
              onPressed: onGoToToday,
              tooltip: 'Ir a hoy',
            ),
        ],
      ),
    );
  }
}
