import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pulsar/main.dart';

void main() {
  testWidgets('Pulsar renders the weekly constellation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const PulsarApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('PULSAR'), findsOneWidget);
    expect(find.text('MON'), findsOneWidget);
  });
}
