import 'dart:math' as math;
import '../models/dynamic_floor_model.dart';

class RoomItemPlacement {
  String id;
  String itemName;
  String targetWall; // 'North Wall (N)', 'South Wall (S)', 'East Wall (E)', 'West Wall (W)', 'North-West Corner (N-W)', etc.
  String facingDirection; // 'Facing South (↓)', 'Facing North (↑)', 'Facing East (→)', 'Facing West (←)', 'Auto'
  int rotationDegrees; // 0, 90, 180, 270
  double? customWidth;
  double? customLength;
  double? customHeight;
  double? customElevation; // Height above finished floor level (AFF)
  double? customPosX; // X position in room units
  double? customPosY; // Y position in room units
  String? customNotes;
  String? amazonUrl;
  String? imageUrl;
  String? productPrice;
  String? productBrand;

  RoomItemPlacement({
    required this.itemName,
    required this.targetWall,
    this.facingDirection = 'Auto (Inward)',
    this.rotationDegrees = 0,
    this.id = '',
    this.customWidth,
    this.customLength,
    this.customHeight,
    this.customElevation,
    this.customPosX,
    this.customPosY,
    this.customNotes,
    this.amazonUrl,
    this.imageUrl,
    this.productPrice,
    this.productBrand,
  });

  RoomItemPlacement copyWith({
    String? id,
    String? itemName,
    String? targetWall,
    String? facingDirection,
    int? rotationDegrees,
    double? customWidth,
    double? customLength,
    double? customHeight,
    double? customElevation,
    double? customPosX,
    double? customPosY,
    String? customNotes,
    String? amazonUrl,
    String? imageUrl,
    String? productPrice,
    String? productBrand,
  }) {
    return RoomItemPlacement(
      id: id ?? this.id,
      itemName: itemName ?? this.itemName,
      targetWall: targetWall ?? this.targetWall,
      facingDirection: facingDirection ?? this.facingDirection,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      customWidth: customWidth ?? this.customWidth,
      customLength: customLength ?? this.customLength,
      customHeight: customHeight ?? this.customHeight,
      customElevation: customElevation ?? this.customElevation,
      customPosX: customPosX ?? this.customPosX,
      customPosY: customPosY ?? this.customPosY,
      customNotes: customNotes ?? this.customNotes,
      amazonUrl: amazonUrl ?? this.amazonUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      productPrice: productPrice ?? this.productPrice,
      productBrand: productBrand ?? this.productBrand,
    );
  }
}

class MathematicalItemDimension {
  final String id;
  final String itemName;
  final String targetWall;
  final String facingDirection;
  final int rotationDegrees;
  final double width;
  final double length;
  final double height;
  final double clearance;
  final double? customPosX;
  final double? customPosY;
  final double? customElevation;
  final String formula;
  final String engineeringReason;
  final bool isCustom;
  final String? amazonUrl;
  final String? imageUrl;
  final String? productPrice;
  final String? productBrand;

  const MathematicalItemDimension({
    required this.itemName,
    required this.targetWall,
    required this.width,
    required this.length,
    required this.height,
    required this.clearance,
    required this.formula,
    required this.engineeringReason,
    this.facingDirection = 'Auto (Inward)',
    this.rotationDegrees = 0,
    this.id = '',
    this.customPosX,
    this.customPosY,
    this.customElevation,
    this.isCustom = false,
    this.amazonUrl,
    this.imageUrl,
    this.productPrice,
    this.productBrand,
  });
}

class ArchitecturalPromptService {
  static const List<String> facingDirectionOptions = [
    'Auto (Inward)',
    'Facing South (↓)',
    'Facing North (↑)',
    'Facing East (→)',
    'Facing West (←)',
  ];

  static const List<int> rotationOptions = [0, 90, 180, 270];

  static String defaultFacingForWall(String wall) {
    final w = wall.toLowerCase();
    if (w.contains('north') || w.contains('(n)')) return 'Facing North (↑)';
    if (w.contains('south') || w.contains('(s)')) return 'Facing South (↓)';
    if (w.contains('west') || w.contains('(w)')) return 'Facing East (→)';
    if (w.contains('east') || w.contains('(e)')) return 'Facing West (←)';
    return 'Auto (Inward)';
  }

  static List<MathematicalItemDimension> calculateDimensions({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
  }) {
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);

    final rW = dims.roomWidth;
    final rL = dims.roomLength;
    final marginBetweenItems = u(1.0); // Standard safety gap between co-located items

    // 1. Group placements by normalized wall to count co-located items
    final Map<String, List<int>> wallGroups = {};
    for (int i = 0; i < placements.length; i++) {
      final wallKey = _normalizeWallKey(placements[i].targetWall);
      wallGroups.putIfAbsent(wallKey, () => []).add(i);
    }

    final List<MathematicalItemDimension> results = [];

    for (int i = 0; i < placements.length; i++) {
      final p = placements[i];
      final itemId = p.id.isNotEmpty ? p.id : 'item_$i';
      final nameLower = p.itemName.toLowerCase();
      final targetLower = p.targetWall.toLowerCase();
      final wallKey = _normalizeWallKey(p.targetWall);

      final coLocatedIndices = wallGroups[wallKey] ?? [i];
      final int itemCountOnWall = coLocatedIndices.length;

      // Determine total span of the wall this item is attached to
      final bool isNorthOrSouthWall = targetLower.contains('north') ||
          targetLower.contains('south') ||
          targetLower.contains('(n)') ||
          targetLower.contains('(s)');
      final double totalWallSpan = isNorthOrSouthWall ? rW : rL;

      // Calculate recalibrated available span when multiple items share the wall
      double availableWallSpan = totalWallSpan;
      if (itemCountOnWall > 1) {
        final totalMargins = (itemCountOnWall - 1) * marginBetweenItems;
        availableWallSpan = (totalWallSpan - totalMargins).clamp(u(4.0), totalWallSpan);
      }

      final bool isFullWall = (nameLower.contains('full') ||
              nameLower.contains('wall to wall') ||
              nameLower.contains('entire') ||
              nameLower.contains('complete') ||
              nameLower.contains('all wall') ||
              nameLower.contains('whole wall')) &&
          itemCountOnWall == 1; // If multiple items, share span gracefully!

      // Proportional allocation share on shared walls
      final double shareFactor = itemCountOnWall > 1 ? (1.0 / itemCountOnWall) : 1.0;
      final double allocatedSpan = availableWallSpan * shareFactor;

      // If user provided custom dimensions or custom position, use them directly!
      if (p.customWidth != null || p.customLength != null || p.customPosX != null || p.customPosY != null) {
        double defaultW = u(3.0);
        double defaultL = u(3.0);
        double defaultH = u(3.0);

        if (nameLower.contains('bed')) {
          defaultW = (rW * 0.52).clamp(u(4.5), u(6.5));
          defaultL = (rL * 0.35).clamp(u(5.8), u(7.0));
          defaultH = u(3.2);
        } else if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
          defaultW = u(2.2).clamp(u(0.5), rW * 0.25);
          defaultL = isFullWall ? totalWallSpan : (itemCountOnWall > 1 ? allocatedSpan.clamp(u(3.5), availableWallSpan) : (totalWallSpan * 0.45).clamp(u(4.0), u(9.0)));
          defaultH = (dims.ceilingHeight * (isFullWall ? 1.0 : 0.88)).clamp(u(7.0), dims.ceilingHeight);
        } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
          defaultW = (totalWallSpan * 0.45).clamp(u(4.0), u(6.0));
          defaultL = u(1.5);
          defaultH = u(1.5);
        } else if (nameLower.contains('dress') || nameLower.contains('vanity') || nameLower.contains('mirror') || nameLower.contains('fram')) {
          defaultW = (totalWallSpan * 0.35).clamp(u(2.5), u(5.5));
          defaultL = u(1.5);
          defaultH = u(6.5);
        } else if (nameLower.contains('study') || nameLower.contains('table') || nameLower.contains('desk')) {
          defaultW = (totalWallSpan * 0.45).clamp(u(3.5), u(5.5));
          defaultL = u(2.0);
          defaultH = u(2.5);
        } else if (nameLower.contains('sofa') || nameLower.contains('couch') || nameLower.contains('seating')) {
          defaultW = (rW * 0.50).clamp(u(4.5), u(6.5));
          defaultL = (rL * 0.28).clamp(u(3.5), u(6.0));
          defaultH = u(2.8);
        }

        final cW = p.customWidth ?? defaultW;
        final cL = p.customLength ?? defaultL;
        final cH = p.customHeight ?? defaultH;

        final posX = p.customPosX ?? 0.0;
        final posY = p.customPosY ?? 0.0;
        final gapWest = posX;
        final gapEast = (rW - (posX + cW)).clamp(0.0, rW);
        final gapSouth = posY;
        final gapNorth = (rL - (posY + cL)).clamp(0.0, rL);

        final minClearance = [gapWest, gapEast, gapSouth, gapNorth].where((g) => g > u(0.05)).fold<double>(10000.0, math.min);
        final effClearance = minClearance == 10000.0 ? 0.0 : minClearance;

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: cW,
          length: cL,
          height: cH,
          clearance: effClearance,
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          customElevation: p.customElevation,
          formula: 'Width (W-E): ${dims.format(cW)}, Length (S-N): ${dims.format(cL)}, Height: ${dims.format(cH)}',
          engineeringReason: 'Position: (${dims.format(posX)}, ${dims.format(posY)}). Wall Gaps: W (Left): ${gapWest < u(0.05) ? "FLUSH" : dims.format(gapWest)}, E (Right): ${gapEast < u(0.05) ? "FLUSH" : dims.format(gapEast)}, S (Top): ${gapSouth < u(0.05) ? "FLUSH" : dims.format(gapSouth)}, N (Bottom): ${gapNorth < u(0.05) ? "FLUSH" : dims.format(gapNorth)}.',
          isCustom: true,
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
        continue;
      }

      if (nameLower.contains('bed')) {
        final bedW = (rW * 0.52).clamp(u(4.5), u(6.5));
        final bedL = (rL * 0.35).clamp(u(5.8), u(7.0));
        final bedH = u(3.2);
        final clearance = (rW - bedW - u(2.0)).clamp(u(2.5), u(10.0));

        final recalibratedSpan = itemCountOnWall > 1
            ? bedW.clamp(u(4.0), allocatedSpan)
            : bedW;

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: recalibratedSpan,
          length: bedL,
          height: bedH,
          clearance: clearance,
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: itemCountOnWall > 1
              ? 'Recalibrated Span: ${dims.format(recalibratedSpan)} on ${p.targetWall}'
              : 'Width = ${dims.format(bedW)}, Length = ${dims.format(bedL)}',
          engineeringReason:
              'Attached to ${p.targetWall}, ${p.facingDirection}. Leaves ${dims.format(clearance)} central circulation walkway to the opposite wall.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
        final wardW = u(2.12).clamp(u(0.5), rW * 0.25);
        final double wardL = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(3.5), availableWallSpan)
                : (totalWallSpan * 0.45).clamp(u(4.0), u(9.0)));
        final wardH = (dims.ceilingHeight * (isFullWall ? 1.0 : 0.88)).clamp(u(7.0), dims.ceilingHeight);
        final clearance = u(3.0);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: wardW,
          length: wardL,
          height: wardH,
          clearance: clearance,
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: isFullWall
              ? 'Full Wall Span = ${dims.format(wardL)} (100% Wall-to-Wall Custom Joinery), Depth = ${dims.format(wardW)}'
              : (itemCountOnWall > 1
                  ? 'Recalibrated Shared Span = ${dims.format(wardL)} (Reserves ${dims.format(marginBetweenItems)} margin for co-placed items)'
                  : 'Depth = ${dims.format(wardW)} (Standard Ergonomic Hanger Depth), Length = WallSpan × 45% (${dims.format(wardL)})'),
          engineeringReason: isFullWall
              ? 'Spans 100% of ${p.targetWall} (${dims.format(wardL)}) from corner to corner with floor-to-ceiling joinery and sliding doors.'
              : 'Mounted flush along ${p.targetWall}, ${p.facingDirection}. Recalibrated with ${dims.format(marginBetweenItems)} spacing margin.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else if (nameLower.contains('dress') || nameLower.contains('desiss') || nameLower.contains('vanity') || nameLower.contains('mirror') || nameLower.contains('fram') || nameLower.contains('makeup')) {
        final dressW = u(1.5);
        final dressL = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(2.5), availableWallSpan)
                : (totalWallSpan * 0.35).clamp(u(2.5), u(5.5)));
        final dressH = u(6.5);
        final clearance = u(3.0);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: dressW,
          length: dressL,
          height: dressH,
          clearance: clearance,
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: 'Depth = ${dims.format(dressW)}, Span = ${dims.format(dressL)} (Recalibrated on ${p.targetWall})',
          engineeringReason:
              'Full-length vertical dressing frame with integrated vanity counter and ambient edge-lighting on ${p.targetWall}.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
        final tvW = u(1.5);
        final tvL = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(3.5), availableWallSpan)
                : (totalWallSpan * 0.45).clamp(u(4.0), u(7.5)));
        final tvH = u(1.6);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: tvW,
          length: tvL,
          height: tvH,
          clearance: u(4.5),
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: 'Console Depth = ${dims.format(tvW)}, Length = ${dims.format(tvL)} (Recalibrated for co-placement)',
          engineeringReason:
              'Floating wall-mounted entertainment console on ${p.targetWall}, ${p.facingDirection} preserving unobstructed floor space.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else if (nameLower.contains('study') || nameLower.contains('table') || nameLower.contains('desk')) {
        final deskW = u(2.0);
        final deskL = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(3.0), availableWallSpan)
                : (totalWallSpan * 0.45).clamp(u(3.5), u(5.5)));
        final deskH = u(2.5);
        final chairClearance = u(3.0);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: deskW,
          length: deskL,
          height: deskH,
          clearance: chairClearance,
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: 'Depth = ${dims.format(deskW)}, Length = ${dims.format(deskL)}',
          engineeringReason:
              'Aligned on ${p.targetWall}, ${p.facingDirection}. Reserves ${dims.format(chairClearance)} chair roll-back clearance.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else if (nameLower.contains('sofa') || nameLower.contains('couch') || nameLower.contains('recliner')) {
        final sofaW = (rW * 0.50).clamp(u(4.5), u(6.5));
        final sofaL = (rL * 0.28).clamp(u(3.5), u(6.0));
        final sofaH = u(2.8);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: sofaW,
          length: sofaL,
          height: sofaH,
          clearance: u(2.8),
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: 'Width = clamp(RoomWidth × 50%, ${dims.format(u(4.5))}, ${dims.format(u(6.5))}), Depth = RoomLength × 28%',
          engineeringReason:
              'Placed on ${p.targetWall}, ${p.facingDirection}. Establishes optimal viewing distance to the opposite media console.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      } else {
        final genW = (totalWallSpan * 0.35).clamp(u(2.0), u(4.5));
        final genL = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(2.0), availableWallSpan)
                : (totalWallSpan * 0.30).clamp(u(2.0), u(5.0)));
        final genH = u(3.0);

        results.add(MathematicalItemDimension(
          id: itemId,
          itemName: p.itemName,
          targetWall: p.targetWall,
          facingDirection: p.facingDirection,
          rotationDegrees: p.rotationDegrees,
          width: genW,
          length: genL,
          height: genH,
          clearance: u(2.5),
          customPosX: p.customPosX,
          customPosY: p.customPosY,
          formula: 'Proportional clamp: Width = ${dims.format(genW)}, Length = ${dims.format(genL)}',
          engineeringReason: 'Optimized placement along ${p.targetWall}, ${p.facingDirection} maintaining standard walkway buffer.',
          amazonUrl: p.amazonUrl,
          imageUrl: p.imageUrl,
          productPrice: p.productPrice,
          productBrand: p.productBrand,
        ));
      }
    }

    return results;
  }

  static String _normalizeWallKey(String targetWall) {
    final w = targetWall.toLowerCase();
    if (w.contains('north') || w.contains('(n)')) return 'north';
    if (w.contains('south') || w.contains('(s)')) return 'south';
    if (w.contains('west') || w.contains('(w)')) return 'west';
    if (w.contains('east') || w.contains('(e)')) return 'east';
    if (w.contains('n-w')) return 'nw';
    if (w.contains('n-e')) return 'ne';
    if (w.contains('s-w')) return 'sw';
    if (w.contains('s-e')) return 'se';
    return 'center';
  }

  static String generateMasterPrompt({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
    String roomName = 'Master Architectural Space',
  }) {
    final calcItems = calculateDimensions(dims: dims, placements: placements);
    final unitStr = dims.unit.label;
    final roomAreaVal = dims.roomWidth * dims.roomLength;
    final roomAreaFormatted = dims.formatArea(roomAreaVal);
    final bathAreaVal = dims.bathWidth * dims.bathLength;
    final bathAreaFormatted = dims.formatArea(bathAreaVal);
    final kitchenAreaVal = dims.kitchenWidth * dims.kitchenLength;
    final kitchenAreaFormatted = dims.formatArea(kitchenAreaVal);
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);

    final buffer = StringBuffer();

    buffer.writeln('# 🏛️ AI MASTER 3D ARCHITECTURAL GENERATION PROMPT');
    buffer.writeln('**Project:** $roomName');
    buffer.writeln('**Generated By:** AI CAD Spatial Blueprint & Spatial Dimension Engine');
    buffer.writeln('**Measurement Standard:** $unitStr | **Scale:** 1:50 Architectural Standard\n');
    buffer.writeln('---');

    buffer.writeln('## 📐 1. ROOM DIMENSIONS & EXACT SPATIAL ARCHITECTURE');
    buffer.writeln('### 🛏️ Master Bedroom Suite:');
    buffer.writeln('- **Dimensions:** ${dims.format(dims.roomWidth)} Width × ${dims.format(dims.roomLength)} Length');
    buffer.writeln('- **Floor Area:** $roomAreaFormatted');
    buffer.writeln('- **Ceiling Height:** ${dims.format(dims.ceilingHeight)} (Finished Floor to Ceiling)');
    buffer.writeln('- **West Wall:** Strictly ${dims.format(dims.roomLength)} continuous solid feature wall.');
    buffer.writeln('- **East Wall:** Strictly ${dims.format(dims.roomLength)} dividing wall between Bedroom Suite and Staircase Core.');
    buffer.writeln('- **Main Room Entrance Door:** Width ${dims.format(u(3.0))}, located precisely at the end of the ${dims.format(dims.roomLength)} East wall (y = ${dims.format(dims.roomLength)}), swinging inward (NW) into the bedroom vestibule.');
    buffer.writeln('- **Glazed Bed Window (W1):** Width ${dims.format(u(5.0))}, centered on the exterior North wall.\n');

    buffer.writeln('### 🚿 Ensuite Bathroom (Integrated Half-Inside Suite):');
    buffer.writeln('- **Dimensions:** ${dims.format(dims.bathWidth)} Width × ${dims.format(dims.bathLength)} Length ($bathAreaFormatted)');
    buffer.writeln('- **Top Half (${dims.format(dims.bathLength / 2)} Inside Room):** Spans from y = ${dims.format(dims.roomLength - dims.bathLength / 2)} to y = ${dims.format(dims.roomLength)} inside the bedroom footprint. Contains the floating vanity washbasin and mirror.');
    buffer.writeln('- **Bathroom Door (Bath Gate):** Width ${dims.format(u(2.5))}, located on the **East Partition Wall** of the bathroom inside the bedroom passage, opening inward into the bathroom from the suite vestibule.');
    buffer.writeln('- **Bottom Half (${dims.format(dims.bathLength / 2)} Outside Room):** Spans from y = ${dims.format(dims.roomLength)} to y = ${dims.format(dims.roomLength + dims.bathLength / 2)}. Contains the commode (WC), glass walk-in shower wet area with floor drain, and exterior ventilator window (V1: ${dims.format(u(2.0))}).\n');

    buffer.writeln('### 🍳 Adjoining Zones & Circulation Core:');
    buffer.writeln('- **Modular Kitchen:** ${dims.format(dims.kitchenWidth)} × ${dims.format(dims.kitchenLength)} ($kitchenAreaFormatted), L-shaped granite counter, 4-burner hob, sink, and ${dims.format(u(3.0))} entry gate.');
    buffer.writeln('- **Staircase Core:** Width ${dims.format(dims.staircaseWidth)}, timber wood treads, first-floor landing corridor connecting staircase exit directly to the Master Bedroom Door.');
    buffer.writeln('- **Gallery Corridor:** Width ${dims.format(dims.galleryWidth)} connecting circulation.\n');

    buffer.writeln('---');
    buffer.writeln('## 🛋️ 2. PLACED FURNITURE & INTERIOR ITEMS (EXACT POSITIONS & COORDINATES)');
    if (calcItems.isEmpty) {
      buffer.writeln('No custom furniture items placed yet. Room maintains open spatial carpet area.\n');
    } else {
      buffer.writeln('Every item is spatially mapped with exact coordinates, facing orientations, and clearances:\n');

      for (int i = 0; i < calcItems.length; i++) {
        final item = calcItems[i];
        final p = placements.firstWhere((pl) => pl.id == item.id, orElse: () => placements[i]);
        final posX = p.customPosX != null ? dims.format(p.customPosX!) : 'Wall Aligned';
        final posY = p.customPosY != null ? dims.format(p.customPosY!) : 'Wall Aligned';

        buffer.writeln('### Item ${i + 1}: ${item.itemName}');
        buffer.writeln('- **Target Wall Attachment:** **${item.targetWall}**');
        buffer.writeln('- **Facing Orientation:** **${item.facingDirection}** (Rotation: ${item.rotationDegrees}°)');
        buffer.writeln('- **Exact Coordinates (X, Y):** `X: $posX, Y: $posY`');
        buffer.writeln('- **3D Dimensions:** Width (X-Span): **${dims.format(item.width)}** | Depth/Length (Y-Span): **${dims.format(item.length)}** | Height: **${dims.format(item.height)}**');
        if (p.customElevation != null && p.customElevation! > 0) {
          buffer.writeln('- **Elevation Above Floor (AFF):** ${dims.format(p.customElevation!)}');
        }
        buffer.writeln('- **Preserved Clearance:** **${dims.format(item.clearance)}** walkway');
        buffer.writeln('- **Engineering Rationale:** ${item.engineeringReason}\n');
      }
    }

    buffer.writeln('---');
    buffer.writeln('## 🎨 3. AI 3D IMAGE GENERATION PROMPTS (COPY & PASTE READY)');
    buffer.writeln('Use these detailed prompts in Midjourney v6, DALL-E 3, Stable Diffusion XL, or Unreal Engine 5 to generate photorealistic 3D interior visuals:\n');

    // Build items summary string for 3D prompts
    final itemsSummary = calcItems.map((it) => '${it.itemName} (${dims.format(it.width)}×${dims.format(it.length)}) on ${it.targetWall} ${it.facingDirection}').join(', ');

    buffer.writeln('### 🌟 Prompt 1: 3D Isometric Cutaway Floor Plan');
    buffer.writeln('```');
    buffer.writeln('Ultra-detailed 3D isometric cutaway architectural visualization of a luxury master bedroom suite (${dims.format(dims.roomWidth)} x ${dims.format(dims.roomLength)}, ceiling height ${dims.format(dims.ceilingHeight)}). Solid ${dims.format(dims.roomLength)} West wall and East wall. Placed furniture: $itemsSummary. Attached ensuite bathroom (${dims.format(dims.bathWidth)} x ${dims.format(dims.bathLength)}) on South-West with top half inside bedroom featuring floating modern vanity and East gate entrance, bottom half with glass walk-in shower and commode. Adjacent staircase core (${dims.format(dims.staircaseWidth)}) with warm oak wood treads. Architectural lighting: 3000K warm LED recessed ceiling spotlights, indirect cove headboard illumination, soft natural morning sunlight through ${dims.format(u(5.0))} North window. Modern Scandinavian-minimalist luxury aesthetic, white oak hardwood flooring, matte charcoal feature walls, brass fixtures, 8k resolution, ray-traced shadows, Unreal Engine 5 Lumen interior render, photorealistic architectural digest style --ar 16:9 --v 6.0');
    buffer.writeln('```\n');

    buffer.writeln('### 🌟 Prompt 2: Eye-Level Master Bedroom Interior Perspective');
    buffer.writeln('```');
    buffer.writeln('Eye-level cinematic interior architectural photograph standing at the room entrance doorway (at y = ${dims.format(dims.roomLength)} on East wall) looking into a modern master bedroom suite (${dims.format(dims.roomWidth)} x ${dims.format(dims.roomLength)}). Foreground shows the wide hardwood walkway leading past the ensuite bathroom East door. In the main bedroom area: $itemsSummary. Large ${dims.format(u(5.0))} window on the opposite wall with sheer white linen curtains filtering soft daylight. High-end interior styling: textured linen bedding, bespoke fluted wood acoustic wall panels, floating vanity console with warm backlight, designer armchair. Volumetric sun rays, shallow depth of field, f/2.8 24mm architectural lens, Hasselblad X2D 100C photo, hyper-realistic materials, award-winning interior design --ar 16:9 --v 6.0');
    buffer.writeln('```\n');

    buffer.writeln('### 🌟 Prompt 3: Top-Down 3D Axonometric Spatial Layout');
    buffer.writeln('```');
    buffer.writeln('Architectural 3D axonometric top-down render of a complete floor layout: Master Bedroom (${dims.format(dims.roomWidth)} x ${dims.format(dims.roomLength)}), Ensuite Bathroom (${dims.format(dims.bathWidth)} x ${dims.format(dims.bathLength)}), Modular Kitchen (${dims.format(dims.kitchenWidth)} x ${dims.format(dims.kitchenLength)}), and Staircase Core (${dims.format(dims.staircaseWidth)}). Every furniture piece accurately positioned: $itemsSummary. Crisp dimensional shadows, clean color zoning (periwinkle bedroom floor, mint bathroom tile, warm oak staircase), modern architectural CAD presentation render --ar 1:1 --v 6.0');
    buffer.writeln('```\n');

    return buffer.toString();
  }
}
