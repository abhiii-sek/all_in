import 'room_item.dart';

class LayoutOption {
  final String id;
  final String title;
  final String description;
  final int score; // 0 - 100
  final List<String> highlights;
  final List<String> warnings;
  final List<RoomItem> placedItems;
  final double usableAreaSqM;
  final double circulationRatio; // % of room area dedicated to free movement

  LayoutOption({
    required this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.highlights,
    required this.warnings,
    required this.placedItems,
    required this.usableAreaSqM,
    required this.circulationRatio,
  });
}
