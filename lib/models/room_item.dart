import 'package:flutter/material.dart';

enum ItemCategory {
  // Bedroom / Living
  bed,
  wardrobe,
  studyDesk,
  nightstand,
  sofa,
  tvUnit,
  acUnit,
  wallArt,
  coffeeTable,
  // Bathroom
  commode,
  showerArea,
  washBasin,
  geyser,
  // Kitchen
  refrigerator,
  gasHob,
  chimney,
  kitchenSink,
  ovenTower,
  dishwasher,
  kitchenCounter,
}

class RoomItem {
  final String id;
  final String name;
  final ItemCategory category;
  final double width; // meters
  final double depth; // meters
  final double height; // meters
  final double clearanceFront; // required clearance in meters
  final double clearanceSides; // required clearance in meters
  
  // Placement coordinates in the room (in meters from top-left origin)
  double x;
  double y;
  double rotationDegrees; // 0, 90, 180, 270
  
  // Custom user inspiration photo (local file path or base64 data)
  final String? imagePath;
  final String? imageBase64;
  final String? notes;
  final Color primaryColor;

  RoomItem({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.depth,
    this.height = 0.8,
    this.clearanceFront = 0.6,
    this.clearanceSides = 0.15,
    this.x = 0.0,
    this.y = 0.0,
    this.rotationDegrees = 0.0,
    this.imagePath,
    this.imageBase64,
    this.notes,
    this.primaryColor = const Color(0xFF3B82F6),
  });

  RoomItem copyWith({
    String? id,
    String? name,
    ItemCategory? category,
    double? width,
    double? depth,
    double? height,
    double? clearanceFront,
    double? clearanceSides,
    double? x,
    double? y,
    double? rotationDegrees,
    String? imagePath,
    String? imageBase64,
    String? notes,
    Color? primaryColor,
  }) {
    return RoomItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      width: width ?? this.width,
      depth: depth ?? this.depth,
      height: height ?? this.height,
      clearanceFront: clearanceFront ?? this.clearanceFront,
      clearanceSides: clearanceSides ?? this.clearanceSides,
      x: x ?? this.x,
      y: y ?? this.y,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      notes: notes ?? this.notes,
      primaryColor: primaryColor ?? this.primaryColor,
    );
  }

  // Pre-configured standards
  static RoomItem createDefault(ItemCategory category, {String? customName}) {
    switch (category) {
      case ItemCategory.bed:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'King Bed (1.8m x 2.0m)',
          category: ItemCategory.bed,
          width: 1.8,
          depth: 2.0,
          height: 0.9,
          clearanceFront: 0.8,
          clearanceSides: 0.7,
          primaryColor: const Color(0xFF6366F1),
        );
      case ItemCategory.wardrobe:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Sliding Wardrobe (2.1m x 0.6m)',
          category: ItemCategory.wardrobe,
          width: 2.1,
          depth: 0.6,
          height: 2.4,
          clearanceFront: 0.8,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF8B5CF6),
        );
      case ItemCategory.studyDesk:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Workstation Desk (1.2m x 0.6m)',
          category: ItemCategory.studyDesk,
          width: 1.2,
          depth: 0.6,
          height: 0.75,
          clearanceFront: 0.9, // for chair roll-back
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF0EA5E9),
        );
      case ItemCategory.nightstand:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Nightstand',
          category: ItemCategory.nightstand,
          width: 0.45,
          depth: 0.4,
          height: 0.5,
          clearanceFront: 0.3,
          clearanceSides: 0.05,
          primaryColor: const Color(0xFFA855F7),
        );
      case ItemCategory.sofa:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? '3-Seater Sofa (2.1m x 0.9m)',
          category: ItemCategory.sofa,
          width: 2.1,
          depth: 0.9,
          height: 0.85,
          clearanceFront: 0.5,
          clearanceSides: 0.3,
          primaryColor: const Color(0xFFF59E0B),
        );
      case ItemCategory.tvUnit:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'TV Media Console',
          category: ItemCategory.tvUnit,
          width: 1.6,
          depth: 0.4,
          height: 0.45,
          clearanceFront: 1.5,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF64748B),
        );
      case ItemCategory.acUnit:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Split AC Unit (Indoor)',
          category: ItemCategory.acUnit,
          width: 0.9,
          depth: 0.25,
          height: 0.3,
          clearanceFront: 1.0,
          clearanceSides: 0.15,
          primaryColor: const Color(0xFF06B6D4),
        );
      case ItemCategory.wallArt:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Feature Wall Art',
          category: ItemCategory.wallArt,
          width: 1.2,
          depth: 0.05,
          height: 0.8,
          clearanceFront: 0.5,
          clearanceSides: 0.2,
          primaryColor: const Color(0xFFEC4899),
        );
      case ItemCategory.coffeeTable:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Coffee Table',
          category: ItemCategory.coffeeTable,
          width: 1.0,
          depth: 0.5,
          height: 0.4,
          clearanceFront: 0.4,
          clearanceSides: 0.4,
          primaryColor: const Color(0xFFD97706),
        );
      case ItemCategory.commode:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Wall-Hung WC Commode',
          category: ItemCategory.commode,
          width: 0.4,
          depth: 0.6,
          height: 0.4,
          clearanceFront: 0.6,
          clearanceSides: 0.25,
          primaryColor: const Color(0xFF10B981),
        );
      case ItemCategory.showerArea:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Glass Shower Enclosure',
          category: ItemCategory.showerArea,
          width: 1.0,
          depth: 1.0,
          height: 2.1,
          clearanceFront: 0.7,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF06B6D4),
        );
      case ItemCategory.washBasin:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Vanity Counter & Basin',
          category: ItemCategory.washBasin,
          width: 0.8,
          depth: 0.5,
          height: 0.85,
          clearanceFront: 0.7,
          clearanceSides: 0.15,
          primaryColor: const Color(0xFF14B8A6),
        );
      case ItemCategory.geyser:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Water Heater Geyser',
          category: ItemCategory.geyser,
          width: 0.4,
          depth: 0.4,
          height: 0.6,
          clearanceFront: 0.3,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFFEF4444),
        );
      case ItemCategory.refrigerator:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Double Door Refrigerator',
          category: ItemCategory.refrigerator,
          width: 0.8,
          depth: 0.75,
          height: 1.8,
          clearanceFront: 0.9,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF475569),
        );
      case ItemCategory.gasHob:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Gas Hob / Cooktop (4 Burner)',
          category: ItemCategory.gasHob,
          width: 0.75,
          depth: 0.5,
          height: 0.1,
          clearanceFront: 0.8,
          clearanceSides: 0.3,
          primaryColor: const Color(0xFFDC2626),
        );
      case ItemCategory.chimney:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Suction Chimney Hood',
          category: ItemCategory.chimney,
          width: 0.9,
          depth: 0.5,
          height: 0.6,
          clearanceFront: 0.5,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF334155),
        );
      case ItemCategory.kitchenSink:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Single/Double Bowl Sink',
          category: ItemCategory.kitchenSink,
          width: 0.9,
          depth: 0.5,
          height: 0.3,
          clearanceFront: 0.8,
          clearanceSides: 0.3,
          primaryColor: const Color(0xFF0284C7),
        );
      case ItemCategory.ovenTower:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Built-in Microwave & Oven Tower',
          category: ItemCategory.ovenTower,
          width: 0.6,
          depth: 0.6,
          height: 1.6,
          clearanceFront: 0.8,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF6B7280),
        );
      case ItemCategory.dishwasher:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Under-counter Dishwasher',
          category: ItemCategory.dishwasher,
          width: 0.6,
          depth: 0.6,
          height: 0.85,
          clearanceFront: 0.9,
          clearanceSides: 0.1,
          primaryColor: const Color(0xFF64748B),
        );
      case ItemCategory.kitchenCounter:
        return RoomItem(
          id: UniqueKey().toString(),
          name: customName ?? 'Granite Countertop Run',
          category: ItemCategory.kitchenCounter,
          width: 2.4,
          depth: 0.6,
          height: 0.85,
          clearanceFront: 0.9,
          clearanceSides: 0.0,
          primaryColor: const Color(0xFF78716C),
        );
    }
  }
}
