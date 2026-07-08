import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErrorHandler {
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void _copyAndNotify(String msg) {
    Clipboard.setData(ClipboardData(text: msg));
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Error copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  static void show(dynamic error) {
    final msg = error.toString();
    debugPrint('Error: $msg');
    _showSnackBar(
      SnackBar(
        content: GestureDetector(
          onTap: () => _copyAndNotify(msg),
          child: Text(msg, maxLines: 3, overflow: TextOverflow.ellipsis),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  static void showMessage(String message, {bool isError = false}) {
    debugPrint('Message: $message');
    _showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void _showSnackBar(SnackBar snackBar) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(snackBar);
  }
}
