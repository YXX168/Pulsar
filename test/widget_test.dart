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
    await tester.pump(const Duration(milliseconds: 980));
    expect(find.text('星环模式'), findsNothing);
    expect(find.byKey(const ValueKey('header-energy-meter')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsOneWidget);

    final firstBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
    await firstBack;
    await tester.pump();
    expect(find.byKey(const ValueKey('weekly-core-hit')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('weekly-core-hit')).hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 980));
    await tester.tap(find.byKey(const ValueKey('day-hit-mon')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

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
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('rest-timer'))).dy,
      lessThan(260),
    );

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 400));
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
    await tester.pump(const Duration(milliseconds: 440));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    expect(find.byType(DayGalaxyScreen), findsNothing);
    expect(find.byKey(const ValueKey('day-hit-mon')), findsOneWidget);

    final secondBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 480));
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
    await tester.pump(const Duration(milliseconds: 980));
    await tester.tap(find.byKey(const ValueKey('day-hit-sat')).hitTestable());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('exercise-hit-sat-0')), findsOneWidget);
    expect(find.text('AI 项目推进'), findsWidgets);

    final dayBack = tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 440));
    await dayBack;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
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

  testWidgets('周次数据隔离且详细训练组可编辑删除', (tester) async {
    await loadApp(tester);
    final galaxy = tester.widget<GalaxyScreen>(find.byType(GalaxyScreen));
    final controller = galaxy.controller;
    final monday = controller.plan.first;

    expect(
      await controller.addDetailedSet(
        monday,
        0,
        reps: '9 次',
        weight: 32.5,
        rpe: 8,
        note: '动作稳定',
      ),
      isTrue,
    );
    expect(controller.count(monday, 0), 1);
    expect(controller.events.first.weight, 32.5);
    expect(controller.events.first.rpe, 8);

    final original = controller.events.first;
    await controller.updateEvent(
      original.copyWith(weight: 35, rpe: 8.5, note: '下次维持'),
    );
    expect(controller.events.first.weight, 35);
    expect(controller.events.first.note, '下次维持');

    controller.shiftWeek(-1);
    expect(controller.count(monday, 0), 0);
    controller.shiftWeek(1);
    expect(controller.count(monday, 0), 1);

    await controller.deleteEvent(controller.events.first);
    expect(controller.count(monday, 0), 0);
    expect(controller.events, isEmpty);
  });

  testWidgets('脉冲矩阵标签切换不再挤压相邻日期', (tester) async {
    await loadApp(tester);
    await tester.tap(find.byIcon(Icons.view_agenda_rounded));
    await tester.pump(const Duration(milliseconds: 320));

    final monday = find.byKey(const ValueKey('matrix-day-0'));
    final tuesday = find.byKey(const ValueKey('matrix-day-1'));
    final sunday = find.byKey(const ValueKey('matrix-day-6'));
    final mondayRect = tester.getRect(monday);
    final tuesdayRect = tester.getRect(tuesday);
    final sundayRect = tester.getRect(sunday);
    expect(mondayRect.width, closeTo(tuesdayRect.width, .01));
    expect(tuesdayRect.width, closeTo(sundayRect.width, .01));
    expect(sundayRect.right, lessThanOrEqualTo(381));

    tester.widget<GestureDetector>(tuesday).onTap!();
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.getRect(monday).left, closeTo(mondayRect.left, .1));
    expect(tester.getRect(tuesday).left, closeTo(tuesdayRect.left, .1));
    expect(tester.getRect(sunday).right, closeTo(sundayRect.right, .1));

    final matrix = tester.widget<NormalWorkoutScreen>(
      find.byType(NormalWorkoutScreen),
    );
    final weekLabel = find.byKey(const ValueKey('week-label'));
    final currentWeekSize = tester.getSize(weekLabel);
    matrix.controller.shiftWeek(-1);
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.getSize(weekLabel), currentWeekSize);
    tester.widget<GestureDetector>(weekLabel).onTap!();
    await tester.pump(const Duration(milliseconds: 320));
    expect(tester.getSize(weekLabel), currentWeekSize);
    expect(tester.takeException(), isNull);
  });
}
