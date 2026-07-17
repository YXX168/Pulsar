import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(const PulsarApp());
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('周星系可以进入训练日并记录一组', (tester) async {
    await loadApp(tester);

    expect(find.text('PULSAR'), findsOneWidget);
    expect(find.text('周一'), findsOneWidget);

    final monday = find.byKey(const ValueKey('day-hit-mon')).hitTestable();
    expect(monday, findsOneWidget);
    await tester.tap(monday);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));

    expect(tester.takeException(), isNull);
    expect(find.byType(DayGalaxyScreen), findsOneWidget);
    expect(find.text('周一 · 上肢推力'), findsOneWidget);
    expect(find.text('上斜哑铃卧推'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('exercise-hit-mon-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final dayScreen = tester.widget<DayGalaxyScreen>(
      find.byType(DayGalaxyScreen),
    );
    expect(dayScreen.controller.count(dayScreen.day, 0), 1);
    expect(dayScreen.controller.events, hasLength(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.tap(find.text('记录'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('近 7 天能量'), findsOneWidget);
    expect(find.text('28 天活跃场'), findsOneWidget);
    expect(find.text('周一 · 上肢推力'), findsOneWidget);
  });

  testWidgets('底栏和训练计划按钮均可点击', (tester) async {
    await loadApp(tester);

    await tester.tap(find.text('计划'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('每周训练计划'), findsOneWidget);

    await tester.tap(find.text('周一 · 上肢推力'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('添加训练动作'), findsOneWidget);

    await tester.ensureVisible(find.text('添加训练动作'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('添加训练动作'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('7 个训练动作'), findsOneWidget);

    await tester.tap(find.text('记录'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('训练记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
