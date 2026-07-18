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
  testWidgets('星环展开、系统返回和标题能量条均正常', (tester) async {
    await loadApp(tester);

    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weekly-core-hit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 820));
    expect(find.text('星环模式'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsOneWidget);

    final firstBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await firstBack;
    await tester.pump();
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('weekly-core-hit')).hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 820));
    await tester.tap(find.byKey(const ValueKey('day-hit-mon')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 760));

    expect(find.byType(DayGalaxyScreen), findsOneWidget);
    expect(find.text('周一 · 上肢推力'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('header-energy-meter'))).width,
      closeTo(82, 1),
    );

    tester
        .widget<GestureDetector>(
          find.byKey(const ValueKey('exercise-hit-mon-0')),
        )
        .onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      tester.widget<PulsarHeader>(find.byType(PulsarHeader)).energyExpanded,
      isTrue,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('header-energy-meter'))).width,
      greaterThan(220),
    );
    expect(find.byKey(const ValueKey('rest-timer')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 260));
    expect(
      tester.getSize(find.byKey(const ValueKey('header-energy-meter'))).width,
      closeTo(82, 1),
    );

    final dayScreen = tester.widget<DayGalaxyScreen>(
      find.byType(DayGalaxyScreen),
    );
    expect(dayScreen.controller.count(dayScreen.day, 0), 1);
    expect(dayScreen.controller.events, hasLength(1));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DayGalaxyScreen), findsNothing);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsOneWidget);

    final secondBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 360));
    await secondBack;
    await tester.pump();
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('周六可添加 AI 成长事项并拥有星群动画', (tester) async {
    await loadApp(tester);

    await tester.tap(find.text('计划'));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.ensureVisible(find.text('周六 · 自由探索'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('周六 · 自由探索'));
    await tester.pump(const Duration(milliseconds: 300));

    final add = find.byKey(const ValueKey('add-item-sat'));
    await tester.ensureVisible(add);
    tester.widget<ListTile>(add).onTap!();
    await tester.pump(const Duration(milliseconds: 300));
    final aiChoice = find.byKey(const ValueKey('activity-choice-ai'));
    tester.widget<ListTile>(aiChoice).onTap!();
    await tester.pump(const Duration(milliseconds: 360));

    final settings = tester.widget<SettingsScreen>(find.byType(SettingsScreen));
    expect(settings.controller.plan[5].rest, isFalse);
    expect(settings.controller.plan[5].exercises.single.kind, 'ai');

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('weekly-core-hit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 820));
    await tester.tap(find.byKey(const ValueKey('day-hit-sat')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 760));
    expect(find.byKey(const ValueKey('exercise-hit-sat-0')), findsOneWidget);
    expect(find.text('AI 项目推进'), findsWidgets);

    final dayBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 380));
    await dayBack;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DayGalaxyScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('脉冲矩阵支持左右滑动且两种显示共享真实组记录', (tester) async {
    await loadApp(tester);

    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('脉冲矩阵'), findsOneWidget);

    tester
        .widget<GestureDetector>(find.byKey(const ValueKey('matrix-day-0')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    expect(find.byKey(const ValueKey('normal-exercise-mon-0')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('matrix-day-pager')),
      const Offset(-320, 0),
    );
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    expect(find.byKey(const ValueKey('normal-exercise-tue-0')), findsOneWidget);

    tester
        .widget<GestureDetector>(find.byKey(const ValueKey('matrix-day-0')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 420));
    await tester.pump();
    tester
        .widget<InkWell>(find.byKey(const ValueKey('normal-exercise-mon-0')))
        .onTap!();
    await tester.pump(const Duration(milliseconds: 300));

    final matrix = tester.widget<NormalWorkoutScreen>(
      find.byType(NormalWorkoutScreen),
    );
    final monday = matrix.controller.plan.first;
    expect(matrix.controller.count(monday, 0), monday.exercises.first.sets);
    expect(matrix.controller.events, hasLength(monday.exercises.first.sets));

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.byType(GalaxyScreen), findsOneWidget);
    expect(matrix.controller.count(monday, 0), monday.exercises.first.sets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('记录可撤销且完整备份可以恢复', (tester) async {
    await loadApp(tester);
    final galaxy = tester.widget<GalaxyScreen>(find.byType(GalaxyScreen));
    final monday = galaxy.controller.plan.first;
    await galaxy.controller.setCount(monday, 0, 2);
    expect(galaxy.controller.events, hasLength(2));

    final backup = galaxy.controller.exportBackup();
    await galaxy.controller.undoLastSet();
    expect(galaxy.controller.count(monday, 0), 1);
    expect(galaxy.controller.events, hasLength(1));

    expect(await galaxy.controller.importBackup(backup), isTrue);
    expect(galaxy.controller.count(galaxy.controller.plan.first, 0), 2);
    expect(galaxy.controller.events, hasLength(2));
  });
}
