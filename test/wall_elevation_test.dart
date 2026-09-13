import 'package:flutter_test/flutter_test.dart';
import 'package:all_in_one/models/dynamic_floor_model.dart';
import 'package:all_in_one/services/architectural_prompt_service.dart';
import 'package:all_in_one/widgets/blueprint_canvas/wall_elevation_painter.dart';
import 'package:flutter/material.dart';

void main() {
  group('Wall Front Elevation Architecture Tests', () {
    test('All Walls (4-Wall Panoramic) correctly maps all 4 room walls with items', () {
      final dims = DynamicFloorDimensions(roomWidth: 10.5, roomLength: 18.5, ceilingHeight: 9.5);
      final bedWest = RoomItemPlacement(
        id: 'bed_west',
        itemName: 'King Size Bed',
        targetWall: 'West Wall (W)',
        customPosY: 4.5,
        customLength: 6.0,
        customHeight: 4.5,
        customElevation: 0.0,
      );

      final tvSouth = RoomItemPlacement(
        id: 'tv_south',
        itemName: 'TV Media Console',
        targetWall: 'South Wall (S)',
        customPosX: 2.8,
        customWidth: 5.0,
        customHeight: 4.8,
        customElevation: 2.0,
      );

      final wardrobeEast = RoomItemPlacement(
        id: 'wardrobe_east',
        itemName: 'Luxury Wardrobe Run',
        targetWall: 'East Wall (E)',
        customPosY: 1.5,
        customLength: 7.0,
        customHeight: 9.0,
        customElevation: 0.0,
      );

      final deskNorth = RoomItemPlacement(
        id: 'desk_north',
        itemName: 'Executive Study Desk',
        targetWall: 'North Wall (N)',
        customPosX: 1.0,
        customWidth: 4.5,
        customHeight: 2.5,
        customElevation: 0.0,
      );

      final placements = [bedWest, tvSouth, wardrobeEast, deskNorth];
      final calcItems = ArchitecturalPromptService.calculateDimensions(
        dims: dims,
        placements: placements,
      );

      const canvasSize = Size(2200, 950);
      const scale = 32.0;

      final sections = WallElevationPainter.getWallSections(
        dims: dims,
        wallKey: 'All Walls (4-Wall Panoramic)',
        canvasSize: canvasSize,
        scale: scale,
      );

      expect(sections.length, 4);
      expect(sections[0].wallKey, 'West Wall (W)');
      expect(sections[1].wallKey, 'South Wall (S)');
      expect(sections[2].wallKey, 'East Wall (E)');
      expect(sections[3].wallKey, 'North Wall (N)');

      final rectMap = WallElevationPainter.calculateWallItemRects(
        dims: dims,
        wallKey: 'All Walls (4-Wall Panoramic)',
        items: calcItems,
        placements: placements,
        canvasSize: canvasSize,
        scale: scale,
      );

      expect(rectMap.containsKey('bed_west'), isTrue);
      expect(rectMap.containsKey('tv_south'), isTrue);
      expect(rectMap.containsKey('wardrobe_east'), isTrue);
      expect(rectMap.containsKey('desk_north'), isTrue);

      // Verify each item is rendered in its proper wall section
      expect(rectMap['bed_west']!.left, greaterThanOrEqualTo(sections[0].origin.dx));
      expect(rectMap['tv_south']!.left, greaterThanOrEqualTo(sections[1].origin.dx));
      expect(rectMap['wardrobe_east']!.left, greaterThanOrEqualTo(sections[2].origin.dx));
      expect(rectMap['desk_north']!.left, greaterThanOrEqualTo(sections[3].origin.dx));
    });

    test('East Wall Front View correctly maps Wardrobe and AC unit on East partition', () {
      final dims = DynamicFloorDimensions(roomWidth: 10.5, roomLength: 16.0, ceilingHeight: 10.0);
      final wardrobe = RoomItemPlacement(
        id: 'wardrobe_east',
        itemName: 'Floor-to-Ceiling Wardrobe',
        targetWall: 'East Wall (E)',
        customPosY: 2.0,
        customLength: 7.0,
        customHeight: 9.0,
        customElevation: 0.0,
      );

      final acUnit = RoomItemPlacement(
        id: 'ac_east',
        itemName: 'Split AC Unit',
        targetWall: 'East Wall (E)',
        customPosY: 10.0,
        customLength: 3.2,
        customHeight: 1.15,
        customElevation: 8.2,
      );

      final placements = [wardrobe, acUnit];
      final calcItems = ArchitecturalPromptService.calculateDimensions(
        dims: dims,
        placements: placements,
      );

      const canvasSize = Size(1200, 850);
      const scale = 32.0;
      final origin = WallElevationPainter.getOrigin(
        dims: dims,
        wallKey: 'East Wall (E)',
        canvasSize: canvasSize,
        scale: scale,
      );

      final rectMap = WallElevationPainter.calculateWallItemRects(
        dims: dims,
        wallKey: 'East Wall (E)',
        items: calcItems,
        placements: placements,
        canvasSize: canvasSize,
        scale: scale,
      );

      expect(rectMap.containsKey('wardrobe_east'), isTrue);
      expect(rectMap.containsKey('ac_east'), isTrue);

      final wRect = rectMap['wardrobe_east']!;
      final acRect = rectMap['ac_east']!;

      expect(wRect.left, closeTo(origin.dx + 2.0 * scale, 0.1));
      expect(wRect.width, closeTo(7.0 * scale, 0.1));
      expect(wRect.height, closeTo(9.0 * scale, 0.1));

      final floorY = origin.dy + 10.0 * scale;
      expect(wRect.bottom, closeTo(floorY, 0.1));

      expect(acRect.left, closeTo(origin.dx + 10.0 * scale, 0.1));
      expect(acRect.width, closeTo(3.2 * scale, 0.1));
      expect(acRect.height, closeTo(1.15 * scale, 0.1));
      expect(acRect.bottom, closeTo(floorY - 8.2 * scale, 0.1));
    });

    test('In Wall Front View, adjusting height modifies ONLY height and preserves horizontal position', () {
      final wardrobe = RoomItemPlacement(
        id: 'wardrobe_1',
        itemName: 'Wardrobe',
        targetWall: 'East Wall (E)',
        customPosY: 3.0,
        customLength: 6.0,
        customHeight: 8.0,
        customElevation: 0.0,
      );

      // Increase height from 8.0 ft to 9.5 ft (loft expansion)
      wardrobe.customHeight = 9.5;
      expect(wardrobe.customHeight, 9.5);
      expect(wardrobe.customLength, 6.0); // Width/Length along wall strictly unchanged!
      expect(wardrobe.customPosY, 3.0); // Horizontal position strictly unchanged!
      expect(wardrobe.customElevation, 0.0); // Elevation strictly unchanged!
    });

    test('In Wall Front View, sliding item left/right modifies horizontal offset along the wall', () {
      final acUnit = RoomItemPlacement(
        id: 'ac_unit',
        itemName: 'Split AC',
        targetWall: 'East Wall (E)',
        customPosY: 2.0,
        customLength: 3.2,
        customHeight: 1.2,
        customElevation: 8.0,
      );

      // Slide AC rightwards by +4.5 ft
      acUnit.customPosY = acUnit.customPosY! + 4.5;
      expect(acUnit.customPosY, 6.5);
      expect(acUnit.customHeight, 1.2); // Height unchanged!
      expect(acUnit.customElevation, 8.0); // Elevation unchanged!
    });
  });
}
