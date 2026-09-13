import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';

/// Represents a complete architectural floor layout design option.
/// Enables creating multiple design options, duplicating old designs for modification,
/// and saving/finalizing verified architectural floor plans.
class ArchitecturalDesignOption {
  final String id;
  String name;
  String description;
  DynamicFloorDimensions dims;
  List<RoomItemPlacement> placements;
  DateTime createdAt;
  DateTime lastModified;
  bool isFinalized;
  DateTime? finalizedAt;
  String? finalizedNotes;

  ArchitecturalDesignOption({
    required this.id,
    required this.name,
    this.description = '',
    required this.dims,
    required this.placements,
    required this.createdAt,
    required this.lastModified,
    this.isFinalized = false,
    this.finalizedAt,
    this.finalizedNotes,
  });

  /// Creates a deep copy of this design option with modified fields.
  ArchitecturalDesignOption copyWith({
    String? id,
    String? name,
    String? description,
    DynamicFloorDimensions? dims,
    List<RoomItemPlacement>? placements,
    DateTime? createdAt,
    DateTime? lastModified,
    bool? isFinalized,
    DateTime? finalizedAt,
    String? finalizedNotes,
  }) {
    return ArchitecturalDesignOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      dims: dims != null ? dims.clone() : this.dims.clone(),
      placements: placements != null
          ? placements.map((p) => p.copyWith()).toList()
          : this.placements.map((p) => p.copyWith()).toList(),
      createdAt: createdAt ?? this.createdAt,
      lastModified: lastModified ?? this.lastModified,
      isFinalized: isFinalized ?? this.isFinalized,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      finalizedNotes: finalizedNotes ?? this.finalizedNotes,
    );
  }

  /// Duplicates an existing design option into a brand new design ready for modification.
  ArchitecturalDesignOption duplicate({String? newName, String? newDescription}) {
    final now = DateTime.now();
    return ArchitecturalDesignOption(
      id: 'design_${now.millisecondsSinceEpoch}_${(now.microsecond % 1000)}',
      name: newName ?? 'Copy of $name',
      description: newDescription ?? 'Duplicated from "$name" for custom alterations.',
      dims: dims.clone(),
      placements: placements.map((p) => p.copyWith(id: '${p.id}_copy_${now.millisecondsSinceEpoch}')).toList(),
      createdAt: now,
      lastModified: now,
      isFinalized: false, // New duplicated design starts as working draft
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'unit': dims.unit.name,
    'roomWidth': dims.roomWidth,
    'roomLength': dims.roomLength,
    'bathWidth': dims.bathWidth,
    'bathLength': dims.bathLength,
    'showerDepth': dims.showerDepth,
    'commodeWidth': dims.commodeWidth,
    'basinWidth': dims.basinWidth,
    'kitchenWidth': dims.kitchenWidth,
    'kitchenLength': dims.kitchenLength,
    'kitchenCounterDepth': dims.kitchenCounterDepth,
    'breakfastCounterRun': dims.breakfastCounterRun,
    'staircaseWidth': dims.staircaseWidth,
    'galleryWidth': dims.galleryWidth,
    'ceilingHeight': dims.ceilingHeight,
    'placements': placements.map((p) => {
      'id': p.id,
      'itemName': p.itemName,
      'targetWall': p.targetWall,
      'facingDirection': p.facingDirection,
      'rotationDegrees': p.rotationDegrees,
      'customWidth': p.customWidth,
      'customLength': p.customLength,
      'customHeight': p.customHeight,
      'customElevation': p.customElevation,
      'customPosX': p.customPosX,
      'customPosY': p.customPosY,
      'customNotes': p.customNotes,
      'amazonUrl': p.amazonUrl,
      'imageUrl': p.imageUrl,
      'productPrice': p.productPrice,
      'productBrand': p.productBrand,
    }).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastModified': lastModified.toIso8601String(),
    'isFinalized': isFinalized,
    'finalizedAt': finalizedAt?.toIso8601String(),
    'finalizedNotes': finalizedNotes,
  };

  factory ArchitecturalDesignOption.fromJson(Map<String, dynamic> json) {
    DimensionUnit parseUnit(String? unitStr) {
      if (unitStr == null) return DimensionUnit.feet;
      return DimensionUnit.values.firstWhere(
        (u) => u.name.toLowerCase() == unitStr.toLowerCase(),
        orElse: () => DimensionUnit.feet,
      );
    }

    final dims = DynamicFloorDimensions(
      unit: parseUnit(json['unit'] as String?),
      roomWidth: (json['roomWidth'] as num?)?.toDouble() ?? 10.5,
      roomLength: (json['roomLength'] as num?)?.toDouble() ?? 18.5,
      bathWidth: (json['bathWidth'] as num?)?.toDouble() ?? 5.91,
      bathLength: (json['bathLength'] as num?)?.toDouble() ?? 7.5,
      showerDepth: (json['showerDepth'] as num?)?.toDouble() ?? 3.01,
      commodeWidth: (json['commodeWidth'] as num?)?.toDouble() ?? 2.85,
      basinWidth: (json['basinWidth'] as num?)?.toDouble() ?? 2.14,
      kitchenWidth: (json['kitchenWidth'] as num?)?.toDouble() ?? 7.6,
      kitchenLength: (json['kitchenLength'] as num?)?.toDouble() ?? 9.8,
      kitchenCounterDepth: (json['kitchenCounterDepth'] as num?)?.toDouble() ?? 2.17,
      breakfastCounterRun: (json['breakfastCounterRun'] as num?)?.toDouble() ?? 2.03,
      staircaseWidth: (json['staircaseWidth'] as num?)?.toDouble() ?? 4.5,
      galleryWidth: (json['galleryWidth'] as num?)?.toDouble() ?? 2.8,
      ceilingHeight: (json['ceilingHeight'] as num?)?.toDouble() ?? 9.5,
    );

    final placementsList = <RoomItemPlacement>[];
    if (json['placements'] is List) {
      for (final p in json['placements'] as List) {
        if (p is Map<String, dynamic>) {
          placementsList.add(RoomItemPlacement(
            id: p['id'] as String? ?? '',
            itemName: p['itemName'] as String? ?? 'Furniture',
            targetWall: p['targetWall'] as String? ?? 'West Wall (W)',
            facingDirection: p['facingDirection'] as String? ?? 'Auto (Inward)',
            rotationDegrees: (p['rotationDegrees'] as num?)?.toInt() ?? 0,
            customWidth: (p['customWidth'] as num?)?.toDouble(),
            customLength: (p['customLength'] as num?)?.toDouble(),
            customHeight: (p['customHeight'] as num?)?.toDouble(),
            customElevation: (p['customElevation'] as num?)?.toDouble(),
            customPosX: (p['customPosX'] as num?)?.toDouble(),
            customPosY: (p['customPosY'] as num?)?.toDouble(),
            customNotes: p['customNotes'] as String?,
            amazonUrl: p['amazonUrl'] as String?,
            imageUrl: p['imageUrl'] as String?,
            productPrice: p['productPrice'] as String?,
            productBrand: p['productBrand'] as String?,
          ));
        }
      }
    }

    return ArchitecturalDesignOption(
      id: json['id'] as String? ?? 'design_${DateTime.now().millisecondsSinceEpoch}',
      name: json['name'] as String? ?? 'Design Option',
      description: json['description'] as String? ?? '',
      dims: dims,
      placements: placementsList,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
      lastModified: json['lastModified'] != null ? DateTime.tryParse(json['lastModified'] as String) ?? DateTime.now() : DateTime.now(),
      isFinalized: json['isFinalized'] as bool? ?? false,
      finalizedAt: json['finalizedAt'] != null ? DateTime.tryParse(json['finalizedAt'] as String) : null,
      finalizedNotes: json['finalizedNotes'] as String?,
    );
  }
}
