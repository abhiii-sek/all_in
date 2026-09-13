import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:all_in_one/main.dart';
import 'package:all_in_one/services/design_option_manager_service.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DesignOptionManagerService.init();
  });

  testWidgets('App launches with SavedDesignsLauncherScreen and continues to CAD studio', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(const BuildMateApp());
    await tester.pumpAndSettle();

    // Verify Startup Launcher Hub UI
    expect(find.textContaining('HomeCraft OS • Blueprint CAD Studio'), findsOneWidget);
    expect(find.textContaining('⚡ CONTINUE WORKING'), findsOneWidget);
    expect(find.textContaining('+ Add New Design'), findsWidgets);
    expect(find.textContaining('Saved Floor Design Options'), findsOneWidget);

    // Tap "Open in 2D Studio" on the continue hero card
    final openStudioBtn = find.text('Open in 2D Studio').first;
    expect(openStudioBtn, findsOneWidget);
    await tester.tap(openStudioBtn);
    await tester.pumpAndSettle();

    // Verify 2-step CAD Studio is opened
    expect(find.textContaining('1. Dimensions & Openings'), findsOneWidget);
    expect(find.textContaining('2. 2D CAD Blueprint Studio'), findsOneWidget);

    // Tap step 2 tab at the top
    await tester.tap(find.textContaining('2. 2D CAD Blueprint Studio'));
    await tester.pumpAndSettle();

    // Verify 2D CAD Studio controls
    expect(find.textContaining('Rulers & Dims'), findsOneWidget);
    expect(find.textContaining('CAD Grid'), findsOneWidget);
    expect(find.textContaining('Room Stamps & Areas'), findsOneWidget);
    expect(find.textContaining('Export CAD Blueprint PNG'), findsOneWidget);
  });
}
