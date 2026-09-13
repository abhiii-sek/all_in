import 'wall_opening.dart';
import 'room_item.dart';
import 'layout_option.dart';

enum RoomType {
  bathroom,
  kitchen,
  bedroom,
  livingRoom,
  studyRoom,
  custom,
}

class RoomModel {
  final String id;
  String name;
  RoomType roomType;
  
  // Exact 4 wall measurements (in meters)
  double wallTop; // Wall A (Top/North)
  double wallRight; // Wall B (Right/East)
  double wallBottom; // Wall C (Bottom/South)
  double wallLeft; // Wall D (Left/West)
  double ceilingHeight; // meters
  
  List<WallOpening> openings;
  List<RoomItem> requestedItems;
  List<LayoutOption> generatedLayouts;
  int selectedLayoutIndex;

  RoomModel({
    required this.id,
    required this.name,
    required this.roomType,
    required this.wallTop,
    required this.wallRight,
    required this.wallBottom,
    required this.wallLeft,
    this.ceilingHeight = 2.9,
    List<WallOpening>? openings,
    List<RoomItem>? requestedItems,
    List<LayoutOption>? generatedLayouts,
    this.selectedLayoutIndex = 0,
  })  : openings = openings ?? [],
        requestedItems = requestedItems ?? [],
        generatedLayouts = generatedLayouts ?? [];

  // Average dimensions for rectangular normalization & rendering
  double get effectiveWidth => (wallTop + wallBottom) / 2.0;
  double get effectiveLength => (wallLeft + wallRight) / 2.0;

  // Floor Area in Square Meters
  double get floorAreaSqM => effectiveWidth * effectiveLength;
  
  // Floor Area in Square Feet
  double get floorAreaSqFt => floorAreaSqM * 10.7639;

  // Room Volume in Cubic Meters
  double get roomVolumeCuM => floorAreaSqM * ceilingHeight;

  // Perimeter
  double get perimeterM => wallTop + wallRight + wallBottom + wallLeft;

  // Gross Wall Area
  double get grossWallAreaSqM => perimeterM * ceilingHeight;

  // Net Wall Area (subtracting doors and windows)
  double get netWallAreaSqM {
    double openingsArea = 0.0;
    for (final op in openings) {
      openingsArea += (op.width * op.height);
    }
    return (grossWallAreaSqM - openingsArea).clamp(0.0, double.infinity);
  }

  // Active placed items from selected layout
  List<RoomItem> get currentItems {
    if (generatedLayouts.isNotEmpty &&
        selectedLayoutIndex >= 0 &&
        selectedLayoutIndex < generatedLayouts.length) {
      return generatedLayouts[selectedLayoutIndex].placedItems;
    }
    return requestedItems;
  }

  RoomModel copyWith({
    String? id,
    String? name,
    RoomType? roomType,
    double? wallTop,
    double? wallRight,
    double? wallBottom,
    double? wallLeft,
    double? ceilingHeight,
    List<WallOpening>? openings,
    List<RoomItem>? requestedItems,
    List<LayoutOption>? generatedLayouts,
    int? selectedLayoutIndex,
  }) {
    return RoomModel(
      id: id ?? this.id,
      name: name ?? this.name,
      roomType: roomType ?? this.roomType,
      wallTop: wallTop ?? this.wallTop,
      wallRight: wallRight ?? this.wallRight,
      wallBottom: wallBottom ?? this.wallBottom,
      wallLeft: wallLeft ?? this.wallLeft,
      ceilingHeight: ceilingHeight ?? this.ceilingHeight,
      openings: openings ?? List.from(this.openings),
      requestedItems: requestedItems ?? List.from(this.requestedItems),
      generatedLayouts: generatedLayouts ?? List.from(this.generatedLayouts),
      selectedLayoutIndex: selectedLayoutIndex ?? this.selectedLayoutIndex,
    );
  }
}
