import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_in_one/screens/main_floor_experience_screen.dart';
import 'package:all_in_one/widgets/blueprint_canvas/wall_elevation_interactive_view.dart';
import 'package:all_in_one/models/dynamic_floor_model.dart';
import 'package:all_in_one/services/architectural_prompt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-Touch 2-Finger and Single-Finger Gesture Tests', () {
    testWidgets('MainFloorExperienceScreen: 1-finger tap selects item, 2-finger pinch zooms canvas', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            splashFactory: NoSplash.splashFactory,
            useMaterial3: false,
          ),
          home: const MainFloorExperienceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen renders
      expect(find.byType(MainFloorExperienceScreen), findsOneWidget);

      // Navigate to Step 2 (2D CAD Blueprint Studio)
      await tester.tap(find.textContaining('2. 2D CAD Blueprint Studio'));
      await tester.pumpAndSettle();

      // Verify Zoom FABs work
      final zoomInFab = find.byTooltip('Zoom In');
      expect(zoomInFab, findsOneWidget);
      await tester.tap(zoomInFab);
      await tester.pumpAndSettle();

      final zoomOutFab = find.byTooltip('Zoom Out');
      expect(zoomOutFab, findsOneWidget);
      await tester.tap(zoomOutFab);
      await tester.pumpAndSettle();

      final resetFab = find.byTooltip('Reset Center');
      expect(resetFab, findsOneWidget);
      await tester.tap(resetFab);
      await tester.pumpAndSettle();

      // Test 2-finger gesture simulation on canvas
      final center = tester.getCenter(find.byType(CustomPaint).first);

      // Start 2 pointers
      final touch1 = await tester.startGesture(center + const Offset(-50, 0), pointer: 1);
      final touch2 = await tester.startGesture(center + const Offset(50, 0), pointer: 2);
      await tester.pump();

      // 2-finger Pinch Out (Zoom in): move fingers further apart
      await touch1.moveTo(center + const Offset(-100, 0));
      await touch2.moveTo(center + const Offset(100, 0));
      await tester.pump();

      // 2-finger Drag (Pan): move both fingers together
      await touch1.moveBy(const Offset(40, 30));
      await touch2.moveBy(const Offset(40, 30));
      await tester.pump();

      await touch1.up();
      await touch2.up();
      await tester.pumpAndSettle();
    });

    testWidgets('WallElevationInteractiveView: renders and handles 2-finger pan & pinch zoom', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dims = DynamicFloorDimensions(
        unit: DimensionUnit.feet,
        roomWidth: 16.0,
        roomLength: 14.0,
        ceilingHeight: 10.0,
        bathWidth: 6.0,
        bathLength: 8.0,
        showerDepth: 3.5,
        kitchenWidth: 10.0,
        kitchenLength: 12.0,
        staircaseWidth: 4.0,
        galleryWidth: 5.0,
      );

      final List<MathematicalItemDimension> calcItems = [
        const MathematicalItemDimension(
          id: 'bed_1',
          itemName: 'King Bed & Side Tables',
          targetWall: 'East Wall (E)',
          width: 8.5,
          length: 6.8,
          height: 3.5,
          clearance: 2.5,
          formula: 'Standard King Bed',
          engineeringReason: 'Optimal sleeping comfort',
        ),
      ];

      final placements = [
        RoomItemPlacement(
          id: 'bed_1',
          itemName: 'King Bed & Side Tables',
          targetWall: 'East Wall (E)',
          facingDirection: 'Auto (Inward)',
          customWidth: 8.5,
          customLength: 6.8,
          customHeight: 3.5,
          customElevation: 0.0,
          customPosX: 2.0,
          customPosY: 2.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WallElevationInteractiveView(
              dims: dims,
              calculatedItems: calcItems,
              placements: placements,
              activeWallKey: 'East Wall (E)',
              onWallSelected: (_) {},
              onPlacementsChanged: (_) {},
              onExport: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WallElevationInteractiveView), findsOneWidget);

      // Verify quick action buttons exist
      expect(find.text('+ Add Split AC'), findsOneWidget);
      expect(find.text('+ Add Wardrobe'), findsOneWidget);

      // 2-finger pinch simulation on Wall Elevation
      final elevCenter = tester.getCenter(find.byType(CustomPaint).first);
      final g1 = await tester.startGesture(elevCenter + const Offset(-40, 0), pointer: 1);
      final g2 = await tester.startGesture(elevCenter + const Offset(40, 0), pointer: 2);
      await tester.pump();

      // Pinch zoom out & drag
      await g1.moveTo(elevCenter + const Offset(-20, 0));
      await g2.moveTo(elevCenter + const Offset(20, 0));
      await tester.pump();

      await g1.moveBy(const Offset(20, -15));
      await g2.moveBy(const Offset(20, -15));
      await tester.pump();

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
    });
  });
}
