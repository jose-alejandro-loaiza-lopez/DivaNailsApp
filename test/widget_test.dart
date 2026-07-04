import 'package:flutter_test/flutter_test.dart';

import 'package:diva_nails/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const DivaNailsApp());
    expect(find.text('Registro'), findsOneWidget);
  });
}
