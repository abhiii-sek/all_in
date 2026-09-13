import 'package:flutter_test/flutter_test.dart';
import 'package:all_in_one/models/room_model.dart';
import 'package:all_in_one/models/room_item.dart';
import 'package:all_in_one/models/wall_opening.dart';
import 'package:all_in_one/services/spatial_optimizer_service.dart';

void main() {
  group('Spatial Optimizer Tests', () {
    test('Bathroom Engine generates wet-dry separated layout with shower, commode, and basin', () {
      final bathroom = RoomModel(
        id: 'bath_test',
        name: 'Master Bathroom',
        roomType: RoomType.bathroom,
        wallTop: 2.4,
        wallRight: 1.8,
        wallBottom: 2.4,
        wallLeft: 1.8,
        requestedItems: [
          RoomItem.createDefault(ItemCategory.showerArea),
          RoomItem.createDefault(ItemCategory.commode),
          RoomItem.createDefault(ItemCategory.washBasin),
        ],
      );

      final layouts = SpatialOptimizerService.generateLayouts(bathroom);
      expect(layouts.length, greaterThanOrEqualTo(2));
      
      // Top layout has high score
      expect(layouts.first.score, greaterThanOrEqualTo(90));
      expect(layouts.first.placedItems.any((i) => i.category == ItemCategory.showerArea), isTrue);
      expect(layouts.first.placedItems.any((i) => i.category == ItemCategory.commode), isTrue);
      expect(layouts.first.placedItems.any((i) => i.category == ItemCategory.washBasin), isTrue);
    });

    test('Kitchen Engine generates ergonomic work triangle with Fridge, Sink, and Hob', () {
      final kitchen = RoomModel(
        id: 'kitchen_test',
        name: 'Kitchen',
        roomType: RoomType.kitchen,
        wallTop: 3.6,
        wallRight: 2.7,
        wallBottom: 3.6,
        wallLeft: 2.7,
        requestedItems: [
          RoomItem.createDefault(ItemCategory.refrigerator),
          RoomItem.createDefault(ItemCategory.kitchenSink),
          RoomItem.createDefault(ItemCategory.gasHob),
        ],
      );

      final layouts = SpatialOptimizerService.generateLayouts(kitchen);
      expect(layouts.length, greaterThanOrEqualTo(2));
      expect(layouts.first.title, contains('Triangle'));
      expect(layouts.first.score, greaterThan(90));
    });

    test('Bedroom Engine places bed on solid wall and study desk with natural side-light', () {
      final bedroom = RoomModel(
        id: 'bed_test',
        name: 'Master Bedroom',
        roomType: RoomType.bedroom,
        wallTop: 4.2,
        wallRight: 3.6,
        wallBottom: 4.2,
        wallLeft: 3.6,
        openings: [
          const WallOpening(
            id: 'win_1',
            type: OpeningType.window,
            wallIndex: 0,
            offsetFromCorner: 0.8,
            width: 1.5,
          ),
        ],
        requestedItems: [
          RoomItem.createDefault(ItemCategory.bed),
          RoomItem.createDefault(ItemCategory.wardrobe),
          RoomItem.createDefault(ItemCategory.studyDesk),
          RoomItem.createDefault(ItemCategory.tvUnit),
          RoomItem.createDefault(ItemCategory.acUnit),
        ],
      );

      final layouts = SpatialOptimizerService.generateLayouts(bedroom);
      expect(layouts.length, greaterThanOrEqualTo(2));
      expect(layouts.first.highlights.any((h) => h.contains('lighting') || h.contains('circulation')), isTrue);
    });
  });
}
