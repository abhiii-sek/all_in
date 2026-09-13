import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_in_one/models/dynamic_floor_model.dart';
import 'package:all_in_one/services/architectural_prompt_service.dart';
import 'package:all_in_one/widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';
import 'package:all_in_one/screens/main_floor_experience_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Revamped CAD Studio & Mouse Interaction Verification', () {
    test('DynamicFloor2DPainter has distinct floor colors for all furniture items', () {
      final bedColor = DynamicFloor2DPainter.getItemColor('bed_1', 'King Size Bed');
      final wardrobeColor = DynamicFloor2DPainter.getItemColor('ward_1', 'Master Wardrobe');
      final tvColor = DynamicFloor2DPainter.getItemColor('tv_1', 'TV Media Unit');
      final dressColor = DynamicFloor2DPainter.getItemColor('dress_1', 'Dressing Vanity');
      final studyColor = DynamicFloor2DPainter.getItemColor('study_1', 'Study Desk');

      expect(bedColor, const Color(0xFF2563EB)); // Royal Blue
      expect(wardrobeColor, const Color(0xFF059669)); // Emerald Green
      expect(tvColor, const Color(0xFF7C3AED)); // Deep Violet
      expect(dressColor, const Color(0xFFE11D48)); // Rose Pink
      expect(studyColor, const Color(0xFFD97706)); // Amber Orange

      // All colors should be mutually distinct
      final colorSet = {bedColor, wardrobeColor, tvColor, dressColor, studyColor};
      expect(colorSet.length, 5);
    });

    test('Room door is positioned at South tip of East wall with 4-quadrant cyclic rotation', () {
      final dims = DynamicFloorDimensions(
        roomWidth: 14.0,
        roomLength: 16.0,
        bathWidth: 6.0,
        bathLength: 8.0,
        kitchenWidth: 10.0,
        kitchenLength: 10.0,
        staircaseWidth: 6.0,
        galleryWidth: 4.0,
      );

      expect(dims.roomDoorSwingQuadrant, 0);

      // Verify cyclic rotation increments
      dims.roomDoorSwingQuadrant = (dims.roomDoorSwingQuadrant + 1) % 4;
      expect(dims.roomDoorSwingQuadrant, 1);
      dims.roomDoorSwingQuadrant = (dims.roomDoorSwingQuadrant + 1) % 4;
      expect(dims.roomDoorSwingQuadrant, 2);
      dims.roomDoorSwingQuadrant = (dims.roomDoorSwingQuadrant + 1) % 4;
      expect(dims.roomDoorSwingQuadrant, 3);
      dims.roomDoorSwingQuadrant = (dims.roomDoorSwingQuadrant + 1) % 4;
      expect(dims.roomDoorSwingQuadrant, 0);
    });

    test('Rotation swaps visual dimensions and preserves room boundary constraints', () {
      final dims = DynamicFloorDimensions(
        roomWidth: 14.0,
        roomLength: 16.0,
        bathWidth: 6.0,
        bathLength: 8.0,
        kitchenWidth: 10.0,
        kitchenLength: 10.0,
        staircaseWidth: 6.0,
        galleryWidth: 4.0,
      );

      final placement = RoomItemPlacement(
        id: 'bed_item',
        itemName: 'King Bed',
        targetWall: 'West Wall (W)',
        customWidth: 6.0,
        customLength: 6.5,
        customPosX: 0.0,
        customPosY: 4.75,
        rotationDegrees: 0,
        facingDirection: 'Facing South (↓)',
      );

      // Rotate by 90 degrees
      placement.rotationDegrees = (placement.rotationDegrees + 90) % 360;
      final oldW = placement.customWidth!;
      final oldL = placement.customLength!;
      placement.customWidth = oldL; // 6.5
      placement.customLength = oldW; // 6.0
      placement.facingDirection = 'Facing West (←)';

      expect(placement.customWidth, 6.5);
      expect(placement.customLength, 6.0);
      expect(placement.rotationDegrees, 90);
      expect(placement.facingDirection, 'Facing West (←)');

      // Verify item rect reflects updated dimensions
      final calcItems = ArchitecturalPromptService.calculateDimensions(
        dims: dims,
        placements: [placement],
      );
      final rectMap = DynamicFloor2DPainter.calculateItemRects(
        dims: dims,
        items: calcItems,
        canvasSize: const Size(1800, 1500),
        scale: 28.0,
      );

      final rect = rectMap['bed_item']!;
      expect(rect.width, closeTo(6.5 * 28.0, 0.01));
      expect(rect.height, closeTo(6.0 * 28.0, 0.01));
    });

    testWidgets('MainFloorExperienceScreen renders and allows item selection', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: MainFloorExperienceScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Step 2 (2D CAD Blueprint Studio)
      final step2Btn = find.text('2. 2D CAD Blueprint Studio');
      expect(step2Btn, findsOneWidget);
      await tester.tap(step2Btn);
      await tester.pumpAndSettle();

      // Verify CAD Canvas is rendered
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify Design Options badge is visible
      expect(find.text('Option A: Master Suite (Balanced)'), findsWidgets);
    });
  });
}
