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
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weekly-core-hit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('周一'), findsOneWidget);

    final sunday = find.byKey(const ValueKey('day-hit-sun'));
    final navigation = find.byKey(const ValueKey('orb-navigation'));
    expect(
      tester.getBottomRight(sunday).dy,
      lessThan(tester.getTopLeft(navigation).dy),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weekly-core-hit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    final monday = find.byKey(const ValueKey('day-hit-mon')).hitTestable();
    expect(monday, findsOneWidget);
    await tester.tap(monday);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 550));

    expect(tester.takeException(), isNull);
    expect(find.byType(DayGalaxyScreen), findsOneWidget);
    expect(find.text('周一 · 上肢推力'), findsOneWidget);
    expect(find.text('上斜哑铃卧推'), findsWidgets);
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('exercise-meter-opacity')),
          )
          .opacity,
      0,
    );

    await tester.pump(const Duration(milliseconds: 600));
    final ropePress = find.byKey(const ValueKey('exercise-hit-mon-5'));
    expect(tester.getBottomRight(ropePress).dy, lessThan(844));

    await tester.tap(find.byKey(const ValueKey('exercise-hit-mon-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('exercise-meter-opacity')),
          )
          .opacity,
      1,
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 220));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const ValueKey('exercise-meter-opacity')),
          )
          .opacity,
      0,
    );

    final dayScreen = tester.widget<DayGalaxyScreen>(
      find.byType(DayGalaxyScreen),
    );
    expect(dayScreen.controller.count(dayScreen.day, 0), 1);
    expect(dayScreen.controller.events, hasLength(1));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 200));
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

    await tester.ensureVisible(find.text('周六 · 完全休息'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('周六 · 完全休息'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('添加训练动作'), findsOneWidget);

    await tester.ensureVisible(find.text('添加训练动作'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('添加训练动作'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1 个训练动作'), findsOneWidget);
    final settings = tester.widget<SettingsScreen>(find.byType(SettingsScreen));
    expect(settings.controller.plan[5].rest, isFalse);
    expect(settings.controller.plan[5].exercises, hasLength(1));

    await tester.tap(find.text('记录'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('训练记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('普通模式和星海模式共享完成状态', (tester) async {
    await loadApp(tester);

    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NormalWorkoutScreen), findsOneWidget);

    await tester.tap(find.text('周一'));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('normal-exercise-mon-0')));
    await tester.pump(const Duration(milliseconds: 250));

    final normal = tester.widget<NormalWorkoutScreen>(
      find.byType(NormalWorkoutScreen),
    );
    expect(
      normal.controller.count(normal.controller.plan.first, 0),
      normal.controller.plan.first.exercises.first.sets,
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(GalaxyScreen), findsOneWidget);
    expect(
      normal.controller.count(normal.controller.plan.first, 0),
      normal.controller.plan.first.exercises.first.sets,
    );
  });
}
