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

/// Spatially recalibrated item with exact coordinates, dimensions, facing vectors, and gap matrix
class RecalibratedSpatialItem {
  final String id;
  final String itemName;
  final String targetWall;
  final String facingDirection;
  final int rotationDegrees;
  final double x; // Exact X coordinate in room units (0 = West wall)
  final double y; // Exact Y coordinate in room units (0 = North wall)
  final double z; // Elevation AFF (0 = Finished floor level)
  final double width; // X-span breadth in room units
  final double length; // Y-span depth/length in room units
  final double height; // Z-span height in room units
  final double gapToNorthWall;
  final double gapToSouthWall;
  final double gapToEastWall;
  final double gapToWestWall;
  final double minWallClearance;
  final Map<String, double> pairwiseGaps; // Map<otherItemId, gapDistance>
  final String formula;
  final String engineeringReason;
  final double? rawWidth;
  final double? rawLength;
  final bool isCustom;
  final String? amazonUrl;
  final String? imageUrl;
  final String? productPrice;
  final String? productBrand;

  const RecalibratedSpatialItem({
    required this.id,
    required this.itemName,
    required this.targetWall,
    required this.facingDirection,
    required this.rotationDegrees,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.length,
    required this.height,
    required this.gapToNorthWall,
    required this.gapToSouthWall,
    required this.gapToEastWall,
    required this.gapToWestWall,
    required this.minWallClearance,
    required this.pairwiseGaps,
    required this.formula,
    required this.engineeringReason,
    this.rawWidth,
    this.rawLength,
    this.isCustom = false,
    this.amazonUrl,
    this.imageUrl,
    this.productPrice,
    this.productBrand,
  });

  double get xMax => x + width;
  double get yMax => y + length;
  double get zMax => z + height;
  double get footprintArea => width * length;

  MathematicalItemDimension toMathItem() {
    return MathematicalItemDimension(
      id: id,
      itemName: itemName,
      targetWall: targetWall,
      facingDirection: facingDirection,
      rotationDegrees: rotationDegrees,
      width: rawWidth ?? width,
      length: rawLength ?? length,
      height: height,
      clearance: minWallClearance,
      customPosX: x,
      customPosY: y,
      customElevation: z,
      formula: formula,
      engineeringReason: engineeringReason,
      isCustom: isCustom,
      amazonUrl: amazonUrl,
      imageUrl: imageUrl,
      productPrice: productPrice,
      productBrand: productBrand,
    );
  }
}

/// Comprehensive spatial recalibration result containing complete geometry, metrics, and prompts
class SpatialRecalibrationResult {
  final DynamicFloorDimensions dims;
  final List<RecalibratedSpatialItem> items;
  final double totalRoomArea;
  final double occupiedArea;
  final double freeCarpetArea;
  final double occupiedPercentage;
  final int collisionCount;
  final List<String> collisionDetails;
  final double minCirculationCorridor;
  final String masterPrompt;
  final String midjourneyIsometricPrompt;
  final String midjourneyEyeLevelPrompt;
  final String midjourneyTopDownPrompt;
  final String cadTechnicalPrompt;

  const SpatialRecalibrationResult({
    required this.dims,
    required this.items,
    required this.totalRoomArea,
    required this.occupiedArea,
    required this.freeCarpetArea,
    required this.occupiedPercentage,
    required this.collisionCount,
    required this.collisionDetails,
    required this.minCirculationCorridor,
    required this.masterPrompt,
    required this.midjourneyIsometricPrompt,
    required this.midjourneyEyeLevelPrompt,
    required this.midjourneyTopDownPrompt,
    required this.cadTechnicalPrompt,
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
    if (w.contains('north') || w.contains('(n)') || w.contains('top')) return 'Facing South (↓)';
    if (w.contains('south') || w.contains('(s)') || w.contains('bottom')) return 'Facing North (↑)';
    if (w.contains('west') || w.contains('(w)') || w.contains('left')) return 'Facing East (→)';
    if (w.contains('east') || w.contains('(e)') || w.contains('right')) return 'Facing West (←)';
    return 'Auto (Inward)';
  }

  /// Recalibrate entire spatial layout with exact coordinates, architectural dimensions,
  /// facing vectors, wall clearances, and pairwise item gap matrix.
  static SpatialRecalibrationResult recalibrateSpatialLayout({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
    String roomName = 'Master Architectural Space',
  }) {
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);

    final double rW = dims.roomWidth;
    final double rL = dims.roomLength;
    final double rH = dims.ceilingHeight;
    final double roomArea = rW * rL;

    // Safety margin between multiple items sharing the same wall
    final double standardWallMargin = u(1.0);

    // 1. Group placements by wall to compute shared spans & avoid collisions
    final Map<String, List<int>> wallGroups = {};
    for (int i = 0; i < placements.length; i++) {
      final wallKey = _normalizeWallKey(placements[i].targetWall);
      wallGroups.putIfAbsent(wallKey, () => []).add(i);
    }

    // Temporary raw item spatial data
    final List<_RawSpatialData> rawItems = [];

    // Track running positions along each wall for automatic sequential non-overlapping placement
    double westWallRunningY = 0.0;
    double eastWallRunningY = 0.0;
    double northWallRunningX = 0.0;
    double southWallRunningX = 0.0;

    for (int i = 0; i < placements.length; i++) {
      final p = placements[i];
      final itemId = p.id.isNotEmpty ? p.id : 'item_${i + 1}';
      final nameLower = p.itemName.toLowerCase();
      final targetLower = p.targetWall.toLowerCase();
      final wallKey = _normalizeWallKey(p.targetWall);

      final coLocated = wallGroups[wallKey] ?? [i];
      final int itemCountOnWall = coLocated.length;

      final bool isNorthOrSouthWall = targetLower.contains('north') ||
          targetLower.contains('south') ||
          targetLower.contains('(n)') ||
          targetLower.contains('(s)');
      final double totalWallSpan = isNorthOrSouthWall ? rW : rL;

      // Available wall span factoring in standard margins
      double availableWallSpan = totalWallSpan;
      if (itemCountOnWall > 1) {
        final totalMargins = (itemCountOnWall - 1) * standardWallMargin;
        availableWallSpan = (totalWallSpan - totalMargins).clamp(u(3.5), totalWallSpan);
      }
      final double allocatedSpan = availableWallSpan / itemCountOnWall;

      final bool isFullWall = (nameLower.contains('full') ||
              nameLower.contains('wall to wall') ||
              nameLower.contains('entire') ||
              nameLower.contains('complete') ||
              nameLower.contains('all wall') ||
              nameLower.contains('whole wall')) &&
          itemCountOnWall == 1;

      // Resolve Dimensions (W, L, H)
      double w;
      double l;
      double h;
      String formula = '';
      String reason = '';

      if (p.customWidth != null || p.customLength != null || p.customHeight != null || p.customPosX != null || p.customPosY != null) {
        w = p.customWidth ?? u(3.5);
        l = p.customLength ?? u(3.0);
        h = p.customHeight ?? u(3.0);
        formula = 'Width (W-E): ${dims.format(w)}, Length (S-N): ${dims.format(l)}, Height: ${dims.format(h)}';
        final posX = p.customPosX ?? 0.0;
        final posY = p.customPosY ?? 0.0;
        final gapWest = posX;
        final gapEast = (rW - (posX + w)).clamp(0.0, rW);
        final gapSouth = posY;
        final gapNorth = (rL - (posY + l)).clamp(0.0, rL);
        reason = 'Position: (${dims.format(posX)}, ${dims.format(posY)}). Wall Gaps: W (Left): ${gapWest < u(0.05) ? "FLUSH" : dims.format(gapWest)}, E (Right): ${gapEast < u(0.05) ? "FLUSH" : dims.format(gapEast)}, S (Top): ${gapSouth < u(0.05) ? "FLUSH" : dims.format(gapSouth)}, N (Bottom): ${gapNorth < u(0.05) ? "FLUSH" : dims.format(gapNorth)}.';
      } else if (nameLower.contains('sofa') || nameLower.contains('couch') || nameLower.contains('recliner') || nameLower.contains('sectional')) {
        if (nameLower.contains('sectional') || nameLower.contains('l-shape') || nameLower.contains('corner')) {
          w = (rW * 0.60).clamp(u(7.0), u(9.5));
          l = (rL * 0.35).clamp(u(5.5), u(6.5));
          h = u(2.8);
          formula = 'Sectional Sofa: Width = ${dims.format(w)}, Length = ${dims.format(l)}, Height = ${dims.format(h)}';
          reason = 'L-shaped sectional seating configuration with chaise lounge extension.';
        } else if (nameLower.contains('2-seater') || nameLower.contains('loveseat')) {
          w = u(5.0).clamp(u(4.0), rW * 0.5);
          l = u(3.0);
          h = u(2.8);
          formula = '2-Seater Loveseat: Width = ${dims.format(w)}, Depth = ${dims.format(l)}, Height = ${dims.format(h)}';
          reason = 'Compact 2-seater loveseat ideal for secondary bedroom lounge.';
        } else if (nameLower.contains('recliner') || nameLower.contains('armchair') || nameLower.contains('single')) {
          w = u(3.2);
          l = u(3.2);
          h = u(3.2);
          formula = 'Single Accent Armchair/Recliner: Width = ${dims.format(w)}, Depth = ${dims.format(l)}, Height = ${dims.format(h)}';
          reason = 'Ergonomic plush single lounge armchair with reclining backrest.';
        } else {
          // Standard 3-seater sofa
          w = (rW * 0.55).clamp(u(5.5), u(7.5));
          l = u(3.2);
          h = u(2.8);
          formula = 'Standard 3-Seater Sofa: Width = ${dims.format(w)}, Depth = ${dims.format(l)}, Height = ${dims.format(h)}';
          reason = 'Standard 3-seater living sofa with plush cushions and lumbar back support.';
        }
      } else if (nameLower.contains('bed')) {
        final double baseBedW = nameLower.contains('queen')
            ? u(5.2)
            : (nameLower.contains('single') || nameLower.contains('twin')
                ? u(3.5)
                : (rW * 0.52).clamp(u(4.5), u(6.5)));
        w = itemCountOnWall > 1 ? baseBedW.clamp(u(3.5), allocatedSpan) : baseBedW;
        l = (rL * 0.36).clamp(u(5.8), u(7.0));
        h = u(3.2);
        formula = itemCountOnWall > 1
            ? 'Bed Shared Span: Width = ${dims.format(w)} (Recalibrated for shared ${p.targetWall}), Length = ${dims.format(l)}'
            : 'Bed: Width = ${dims.format(w)}, Length = ${dims.format(l)}, Height = ${dims.format(h)}';
        reason = itemCountOnWall > 1
            ? 'Positioned along shared ${p.targetWall} with recalibrated ${dims.format(w)} span.'
            : 'Master platform bed aligned on ${p.targetWall}, ${p.facingDirection}.';
      } else if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
        w = u(2.12).clamp(u(1.8), rW * 0.28);
        l = isFullWall
            ? totalWallSpan
            : (itemCountOnWall > 1
                ? allocatedSpan.clamp(u(3.5), availableWallSpan)
                : (totalWallSpan * 0.45).clamp(u(4.0), u(9.5)));
        h = (rH * (isFullWall ? 1.0 : 0.90)).clamp(u(7.0), rH);
        formula = isFullWall
            ? 'Full Wall-to-Wall Custom Wardrobe: Span = ${dims.format(l)}, Depth = ${dims.format(w)}, Height = ${dims.format(h)}'
            : 'Modular Wardrobe: Span = ${dims.format(l)}, Hanger Depth = ${dims.format(w)}, Height = ${dims.format(h)}';
        reason = 'Floor-to-ceiling wardrobe with sliding joinery and interior LED shelf illumination.';
      } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
        w = isNorthOrSouthWall ? (totalWallSpan * 0.45).clamp(u(4.5), u(7.5)) : u(1.4);
        l = isNorthOrSouthWall ? u(1.4) : (totalWallSpan * 0.45).clamp(u(4.5), u(7.5));
        h = u(1.6);
        formula = 'Floating TV Media Console: Span = ${dims.format(isNorthOrSouthWall ? w : l)}, Depth = ${dims.format(isNorthOrSouthWall ? l : w)}, Height = ${dims.format(h)}';
        reason = 'Wall-hung low-profile entertainment console with concealed cable chase and acoustic back panel.';
      } else if (nameLower.contains('study') || nameLower.contains('desk') || nameLower.contains('table') || nameLower.contains('work')) {
        w = isNorthOrSouthWall ? (totalWallSpan * 0.45).clamp(u(3.8), u(5.5)) : u(2.0);
        l = isNorthOrSouthWall ? u(2.0) : (totalWallSpan * 0.45).clamp(u(3.8), u(5.5));
        h = u(2.5);
        formula = 'Ergonomic Study Desk: Width = ${dims.format(isNorthOrSouthWall ? w : l)}, Depth = ${dims.format(isNorthOrSouthWall ? l : w)}, Height = ${dims.format(h)}';
        reason = 'Ergonomic workstation with cable grommet and 3.0 ft chair roll-back zone.';
      } else if (nameLower.contains('dress') || nameLower.contains('vanity') || nameLower.contains('mirror') || nameLower.contains('makeup')) {
        w = isNorthOrSouthWall ? (totalWallSpan * 0.35).clamp(u(3.0), u(5.0)) : u(1.5);
        l = isNorthOrSouthWall ? u(1.5) : (totalWallSpan * 0.35).clamp(u(3.0), u(5.0));
        h = u(6.5);
        formula = 'Full-Length Vanity Dressing Unit: Span = ${dims.format(isNorthOrSouthWall ? w : l)}, Depth = ${dims.format(isNorthOrSouthWall ? l : w)}, Height = ${dims.format(h)}';
        reason = 'Full-height dressing mirror frame with integrated floating drawer and backlit perimeter halo.';
      } else if (nameLower.contains('coffee') || nameLower.contains('center table')) {
        w = u(4.0);
        l = u(2.2);
        h = u(1.5);
        formula = 'Center Coffee Table: Width = ${dims.format(w)}, Depth = ${dims.format(l)}, Height = ${dims.format(h)}';
        reason = 'Low-profile marble-top center coffee table positioned in front of seating.';
      } else if (nameLower.contains('nightstand') || nameLower.contains('bedside')) {
        w = u(1.8);
        l = u(1.5);
        h = u(1.8);
        formula = 'Bedside Nightstand: Width = ${dims.format(w)}, Depth = ${dims.format(l)}, Height = ${dims.format(h)}';
        reason = 'Compact bedside pedestal with wireless charging pad and soft-close drawer.';
      } else {
        w = (totalWallSpan * 0.35).clamp(u(2.5), u(4.5));
        l = isFullWall ? totalWallSpan : (itemCountOnWall > 1 ? allocatedSpan.clamp(u(2.5), availableWallSpan) : (totalWallSpan * 0.30).clamp(u(2.5), u(5.0)));
        h = u(3.0);
        formula = 'Proportional Dimension: Width = ${dims.format(w)}, Length = ${dims.format(l)}, Height = ${dims.format(h)}';
        reason = 'Architecturally proportioned auxiliary furniture unit.';
      }

      // Resolve Facing Direction
      String facing = p.facingDirection;
      if (facing == 'Auto (Inward)' || facing.isEmpty) {
        facing = defaultFacingForWall(p.targetWall);
      }

      // Adjust dimensions orientation based on facing & wall alignment
      double itemDimX = w;
      double itemDimY = l;
      if (!nameLower.contains('bed') && p.customWidth == null && p.customLength == null) {
        if (targetLower.contains('west') || targetLower.contains('east') || targetLower.contains('(w)') || targetLower.contains('(e)')) {
          itemDimX = math.min(w, l);
          itemDimY = math.max(w, l);
        } else if (targetLower.contains('north') || targetLower.contains('south') || targetLower.contains('(n)') || targetLower.contains('(s)')) {
          itemDimX = math.max(w, l);
          itemDimY = math.min(w, l);
        }
      }

      if ((p.customWidth == null && p.customLength == null) && (p.rotationDegrees == 90 || p.rotationDegrees == 270)) {
        final temp = itemDimX;
        itemDimX = itemDimY;
        itemDimY = temp;
      }

      // Resolve Coordinates (X, Y, Z)
      double posX = 0.0;
      double posY = 0.0;
      final double posZ = p.customElevation ?? 0.0;

      if (p.customPosX != null && p.customPosY != null) {
        posX = p.customPosX!.clamp(0.0, math.max(0.0, rW - itemDimX));
        posY = p.customPosY!.clamp(0.0, math.max(0.0, rL - itemDimY));
      } else if (targetLower.contains('north-west') || targetLower.contains('n-w')) {
        posX = u(0.5);
        posY = u(0.5);
      } else if (targetLower.contains('north-east') || targetLower.contains('n-e')) {
        posX = (rW - itemDimX - u(0.5)).clamp(0.0, rW);
        posY = u(0.5);
      } else if (targetLower.contains('south-west') || targetLower.contains('s-w')) {
        posX = u(0.5);
        posY = (rL - itemDimY - u(0.5)).clamp(0.0, rL);
      } else if (targetLower.contains('south-east') || targetLower.contains('s-e')) {
        posX = (rW - itemDimX - u(0.5)).clamp(0.0, rW);
        posY = (rL - itemDimY - u(0.5)).clamp(0.0, rL);
      } else if (targetLower.contains('west') || targetLower.contains('(w)') || targetLower.contains('left')) {
        posX = 0.0;
        if (itemCountOnWall == 1) {
          posY = (rL - itemDimY) / 2.0;
        } else {
          posY = westWallRunningY.clamp(0.0, math.max(0.0, rL - itemDimY));
          westWallRunningY += itemDimY + standardWallMargin;
        }
      } else if (targetLower.contains('east') || targetLower.contains('(e)') || targetLower.contains('right')) {
        posX = (rW - itemDimX).clamp(0.0, rW);
        if (itemCountOnWall == 1) {
          posY = (rL - itemDimY) / 2.0;
        } else {
          posY = eastWallRunningY.clamp(0.0, math.max(0.0, rL - itemDimY));
          eastWallRunningY += itemDimY + standardWallMargin;
        }
      } else if (targetLower.contains('north') || targetLower.contains('(n)') || targetLower.contains('top')) {
        posY = 0.0;
        if (itemCountOnWall == 1) {
          posX = (rW - itemDimX) / 2.0;
        } else {
          posX = northWallRunningX.clamp(0.0, math.max(0.0, rW - itemDimX));
          northWallRunningX += itemDimX + standardWallMargin;
        }
      } else if (targetLower.contains('south') || targetLower.contains('(s)') || targetLower.contains('bottom')) {
        posY = (rL - itemDimY).clamp(0.0, rL);
        if (itemCountOnWall == 1) {
          posX = (rW - itemDimX) / 2.0;
        } else {
          posX = southWallRunningX.clamp(0.0, math.max(0.0, rW - itemDimX));
          southWallRunningX += itemDimX + standardWallMargin;
        }
      } else {
        // Center floor
        posX = (rW - itemDimX) / 2.0;
        posY = (rL - itemDimY) / 2.0;
      }

      final actualGapWest = posX;
      final actualGapEast = (rW - (posX + itemDimX)).clamp(0.0, rW);
      final actualGapSouth = posY;
      final actualGapNorth = (rL - (posY + itemDimY)).clamp(0.0, rL);
      if (p.customPosX != null || p.customPosY != null || p.customWidth != null || p.customLength != null) {
        reason = 'Position: (${dims.format(posX)}, ${dims.format(posY)}). Wall Gaps: W (Left): ${actualGapWest < u(0.05) ? "FLUSH" : dims.format(actualGapWest)}, E (Right): ${actualGapEast < u(0.05) ? "FLUSH" : dims.format(actualGapEast)}, S (Top): ${actualGapSouth < u(0.05) ? "FLUSH" : dims.format(actualGapSouth)}, N (Bottom): ${actualGapNorth < u(0.05) ? "FLUSH" : dims.format(actualGapNorth)}.';
      }

      rawItems.add(_RawSpatialData(
        id: itemId,
        placement: p,
        itemName: p.itemName,
        targetWall: p.targetWall,
        facingDirection: facing,
        rotationDegrees: p.rotationDegrees,
        x: posX,
        y: posY,
        z: posZ,
        width: itemDimX,
        length: itemDimY,
        rawWidth: w,
        rawLength: l,
        height: h,
        formula: formula,
        engineeringReason: reason,
        isCustom: p.customWidth != null || p.customLength != null || p.customPosX != null,
      ));
    }

    // 2. Collision Detection & Pairwise Gap Matrix Calculation
    int collisionCount = 0;
    final List<String> collisionDetails = [];
    final List<RecalibratedSpatialItem> recalibratedList = [];

    double occupiedArea = 0.0;

    for (int i = 0; i < rawItems.length; i++) {
      final a = rawItems[i];
      occupiedArea += a.width * a.length;

      final double gapNorth = a.y;
      final double gapSouth = (rL - (a.y + a.length)).clamp(0.0, rL);
      final double gapWest = a.x;
      final double gapEast = (rW - (a.x + a.width)).clamp(0.0, rW);

      final double minWall = [gapNorth, gapSouth, gapWest, gapEast].where((g) => g > u(0.05)).fold<double>(10000.0, math.min);
      final double effMinWall = minWall == 10000.0 ? 0.0 : minWall;

      final Map<String, double> pairwise = {};

      for (int j = 0; j < rawItems.length; j++) {
        if (i == j) continue;
        final b = rawItems[j];

        // Horizontal gap
        double dx = 0.0;
        if (b.x >= a.x + a.width) {
          dx = b.x - (a.x + a.width);
        } else if (a.x >= b.x + b.width) {
          dx = a.x - (b.x + b.width);
        }

        // Vertical gap
        double dy = 0.0;
        if (b.y >= a.y + a.length) {
          dy = b.y - (a.y + a.length);
        } else if (a.y >= b.y + b.length) {
          dy = a.y - (b.y + b.length);
        }

        double physicalDistance = 0.0;
        if (dx > 0 && dy > 0) {
          physicalDistance = math.sqrt(dx * dx + dy * dy);
        } else if (dx > 0) {
          physicalDistance = dx;
        } else if (dy > 0) {
          physicalDistance = dy;
        } else {
          // Overlap / Collision!
          physicalDistance = 0.0;
          collisionCount++;
          collisionDetails.add('Collision detected between "${a.itemName}" and "${b.itemName}".');
        }

        pairwise[b.id] = physicalDistance;
      }

      recalibratedList.add(RecalibratedSpatialItem(
        id: a.id,
        itemName: a.itemName,
        targetWall: a.targetWall,
        facingDirection: a.facingDirection,
        rotationDegrees: a.rotationDegrees,
        x: a.x,
        y: a.y,
        z: a.z,
        width: a.width,
        length: a.length,
        rawWidth: a.rawWidth,
        rawLength: a.rawLength,
        height: a.height,
        gapToNorthWall: gapNorth,
        gapToSouthWall: gapSouth,
        gapToEastWall: gapEast,
        gapToWestWall: gapWest,
        minWallClearance: effMinWall,
        pairwiseGaps: pairwise,
        formula: a.formula,
        engineeringReason: a.engineeringReason,
        isCustom: a.isCustom,
        amazonUrl: a.placement.amazonUrl,
        imageUrl: a.placement.imageUrl,
        productPrice: a.placement.productPrice,
        productBrand: a.placement.productBrand,
      ));
    }

    final double freeCarpetArea = (roomArea - occupiedArea).clamp(0.0, roomArea);
    final double occupiedPercentage = roomArea > 0 ? (occupiedArea / roomArea * 100.0) : 0.0;

    // Minimum circulation corridor across the room
    double minWalkway = u(3.0);
    for (final it in recalibratedList) {
      if (it.minWallClearance > 0 && it.minWallClearance < minWalkway) {
        minWalkway = it.minWallClearance;
      }
    }

    // 3. Generate High-Fidelity Prompts
    final masterPrompt = _buildMasterPrompt(
      dims: dims,
      items: recalibratedList,
      roomName: roomName,
      occupiedArea: occupiedArea,
      freeCarpetArea: freeCarpetArea,
      occupiedPercentage: occupiedPercentage,
    );

    final midIsometric = _buildIsometricPrompt(dims: dims, items: recalibratedList);
    final midEyeLevel = _buildEyeLevelPrompt(dims: dims, items: recalibratedList);
    final midTopDown = _buildTopDownPrompt(dims: dims, items: recalibratedList);
    final cadPrompt = _buildCadPrompt(dims: dims, items: recalibratedList);

    return SpatialRecalibrationResult(
      dims: dims,
      items: recalibratedList,
      totalRoomArea: roomArea,
      occupiedArea: occupiedArea,
      freeCarpetArea: freeCarpetArea,
      occupiedPercentage: occupiedPercentage,
      collisionCount: collisionCount ~/ 2, // remove duplicate pair count
      collisionDetails: collisionDetails.toSet().toList(),
      minCirculationCorridor: minWalkway,
      masterPrompt: masterPrompt,
      midjourneyIsometricPrompt: midIsometric,
      midjourneyEyeLevelPrompt: midEyeLevel,
      midjourneyTopDownPrompt: midTopDown,
      cadTechnicalPrompt: cadPrompt,
    );
  }

  /// Backward-compatible wrapper for existing screens
  static List<MathematicalItemDimension> calculateDimensions({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
  }) {
    final result = recalibrateSpatialLayout(dims: dims, placements: placements);
    return result.items.map((it) => it.toMathItem()).toList();
  }

  /// Backward-compatible master prompt generator
  static String generateMasterPrompt({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
    String roomName = 'Master Architectural Space',
  }) {
    final result = recalibrateSpatialLayout(dims: dims, placements: placements, roomName: roomName);
    return result.masterPrompt;
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

  static String _buildMasterPrompt({
    required DynamicFloorDimensions dims,
    required List<RecalibratedSpatialItem> items,
    required String roomName,
    required double occupiedArea,
    required double freeCarpetArea,
    required double occupiedPercentage,
  }) {
    final unitStr = dims.unit.label;
    final roomAreaFormatted = dims.formatArea(dims.roomWidth * dims.roomLength);
    final bathAreaFormatted = dims.formatArea(dims.bathWidth * dims.bathLength);
    final kitchenAreaFormatted = dims.formatArea(dims.kitchenWidth * dims.kitchenLength);
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);

    final buffer = StringBuffer();

    buffer.writeln('# 🏛️ AI MASTER ARCHITECTURAL SPATIAL SPECIFICATION & PROMPT');
    buffer.writeln('**Project Space:** $roomName');
    buffer.writeln('**Calibrated By:** CAD Architectural Spatial Recalibration Engine');
    buffer.writeln('**Measurement Standard:** $unitStr | **Drafting Standard:** Architectural 1:50\n');
    buffer.writeln('---');

    buffer.writeln('## 📐 1. EXACT ROOM GEOMETRY & ARCHITECTURAL BOUNDARIES');
    buffer.writeln('### 🛏️ Main Master Space:');
    buffer.writeln('- **Room Width (East ↔ West):** ${dims.format(dims.roomWidth)}');
    buffer.writeln('- **Room Length (North ↔ South):** ${dims.format(dims.roomLength)}');
    buffer.writeln('- **Ceiling Height (Finished Floor Level to Ceiling):** ${dims.format(dims.ceilingHeight)}');
    buffer.writeln('- **Total Carpet Area:** $roomAreaFormatted');
    buffer.writeln('- **Occupied Furniture Footprint:** ${dims.formatArea(occupiedArea)} (${occupiedPercentage.toStringAsFixed(1)}%)');
    buffer.writeln('- **Free Circulation Area:** ${dims.formatArea(freeCarpetArea)}');
    buffer.writeln('- **West Boundary Wall:** Continuous solid wall spanning ${dims.format(dims.roomLength)} from North to South (X = 0.00).');
    buffer.writeln('- **East Boundary Wall:** Dividing wall spanning ${dims.format(dims.roomLength)} (X = ${dims.format(dims.roomWidth)}).');
    buffer.writeln('- **Main Room Entrance Door:** Width ${dims.format(u(3.0))}, positioned at y = ${dims.format(dims.roomLength)} on the East wall, swinging inward.');
    buffer.writeln('- **Glazed Window (W1):** Width ${dims.format(u(5.0))}, centered on the North exterior wall (y = 0.00).\n');

    buffer.writeln('### 🚿 Ensuite Attached Bathroom:');
    buffer.writeln('- **Dimensions:** ${dims.format(dims.bathWidth)} Width × ${dims.format(dims.bathLength)} Length ($bathAreaFormatted)');
    buffer.writeln('- **Top Half Inside Bedroom Footprint:** Spans from y = ${dims.format(dims.roomLength - dims.bathLength / 2)} to y = ${dims.format(dims.roomLength)}. Contains floating vanity washbasin and mirror.');
    buffer.writeln('- **Bathroom Door (Bath Gate):** Width ${dims.format(u(2.5))}, located on the East partition wall inside the bedroom vestibule.');
    buffer.writeln('- **Bottom Half Outside Bedroom Footprint:** Spans from y = ${dims.format(dims.roomLength)} to y = ${dims.format(dims.roomLength + dims.bathLength / 2)}. Contains glass shower stall and WC commode.\n');

    buffer.writeln('### 🍳 Adjoining Zones:');
    buffer.writeln('- **Modular Kitchen:** ${dims.format(dims.kitchenWidth)} × ${dims.format(dims.kitchenLength)} ($kitchenAreaFormatted), L-shaped granite countertop.');
    buffer.writeln('- **Staircase Core:** Width ${dims.format(dims.staircaseWidth)}, timber wood treads with direct landing corridor to Bedroom Door.\n');

    buffer.writeln('---');
    buffer.writeln('## 🛋️ 2. RECALIBRATED FURNITURE & FIXTURE PLACEMENT MATRIX');

    if (items.isEmpty) {
      buffer.writeln('No furniture items currently placed. The floor layout maintains unobstructed open carpet area.\n');
    } else {
      buffer.writeln('Every piece of furniture is spatially recalibrated with precise coordinates, 3D dimensions, facing directions, wall clearances, and pairwise gaps:\n');

      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        buffer.writeln('### [${i + 1}] ${it.itemName}');
        buffer.writeln('- **Target Wall Attachment:** **${it.targetWall}**');
        buffer.writeln('- **Facing Orientation:** **${it.facingDirection}** (Rotation: ${it.rotationDegrees}°)');
        buffer.writeln('- **3D Bounding Dimensions:** Width (X-Span): **${dims.format(it.width)}** × Depth/Length (Y-Span): **${dims.format(it.length)}** × Height (Z-Span): **${dims.format(it.height)}**');
        buffer.writeln('- **Exact Coordinates (X, Y, Z):** `X: ${dims.format(it.x)}, Y: ${dims.format(it.y)}, Z: ${dims.format(it.z)}` (Origin (0,0) at North-West Corner)');
        buffer.writeln('- **Clearances to Walls:**');
        buffer.writeln('  - Gap to North Wall: **${it.gapToNorthWall < u(0.05) ? "FLUSH (0.00)" : dims.format(it.gapToNorthWall)}**');
        buffer.writeln('  - Gap to South Wall: **${it.gapToSouthWall < u(0.05) ? "FLUSH (0.00)" : dims.format(it.gapToSouthWall)}**');
        buffer.writeln('  - Gap to West Wall: **${it.gapToWestWall < u(0.05) ? "FLUSH (0.00)" : dims.format(it.gapToWestWall)}**');
        buffer.writeln('  - Gap to East Wall: **${it.gapToEastWall < u(0.05) ? "FLUSH (0.00)" : dims.format(it.gapToEastWall)}**');

        // Pairwise gaps to other items
        final List<String> gapLines = [];
        it.pairwiseGaps.forEach((otherId, gapVal) {
          final otherItem = items.firstWhere((o) => o.id == otherId, orElse: () => it);
          if (otherItem.id != it.id) {
            gapLines.add('  - Distance to **${otherItem.itemName}**: **${dims.format(gapVal)}**');
          }
        });
        if (gapLines.isNotEmpty) {
          buffer.writeln('- **Gaps to Adjacent Furniture Items:**');
          gapLines.forEach(buffer.writeln);
        }

        buffer.writeln('- **Spatial & Ergonomic Rationale:** ${it.engineeringReason}\n');
      }
    }

    buffer.writeln('---');
    buffer.writeln('## 🎨 3. READY-TO-USE AI 3D RENDER PROMPTS');
    buffer.writeln('Copy and paste these calibrated prompts directly into Midjourney v6, DALL-E 3, Stable Diffusion, or Unreal Engine 5:\n');

    buffer.writeln('### 🌟 Prompt A: 3D Isometric Cutaway Master Plan');
    buffer.writeln('```');
    buffer.writeln(_buildIsometricPrompt(dims: dims, items: items));
    buffer.writeln('```\n');

    buffer.writeln('### 🌟 Prompt B: Eye-Level Master Interior Perspective');
    buffer.writeln('```');
    buffer.writeln(_buildEyeLevelPrompt(dims: dims, items: items));
    buffer.writeln('```\n');

    buffer.writeln('### 🌟 Prompt C: Axonometric Top-Down Spatial Layout');
    buffer.writeln('```');
    buffer.writeln(_buildTopDownPrompt(dims: dims, items: items));
    buffer.writeln('```\n');

    buffer.writeln('### 🌟 Prompt D: 2D Architectural CAD Floor Plan Specification');
    buffer.writeln('```');
    buffer.writeln(_buildCadPrompt(dims: dims, items: items));
    buffer.writeln('```\n');

    return buffer.toString();
  }

  static String _buildIsometricPrompt({
    required DynamicFloorDimensions dims,
    required List<RecalibratedSpatialItem> items,
  }) {
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);
    final itemsDesc = items.map((it) => '${it.itemName} [${dims.format(it.width)}W x ${dims.format(it.length)}D x ${dims.format(it.height)}H, placed on ${it.targetWall}, ${it.facingDirection}, exact coordinates X:${dims.format(it.x)} Y:${dims.format(it.y)}]').join(', ');

    return 'Ultra-detailed 3D isometric cutaway architectural visualization of a luxury master bedroom suite (${dims.format(dims.roomWidth)} Width x ${dims.format(dims.roomLength)} Length, finished ceiling height ${dims.format(dims.ceilingHeight)}). Exact recalibrated furniture layout: $itemsDesc. Attached ensuite bathroom (${dims.format(dims.bathWidth)} x ${dims.format(dims.bathLength)}) on South-West with top half inside bedroom featuring floating modern vanity and East gate entrance, bottom half with glass walk-in shower. Adjacent staircase core (${dims.format(dims.staircaseWidth)}) with warm oak treads. Architectural lighting: 3000K warm LED recessed ceiling spotlights, indirect cove headboard illumination, soft natural morning sunlight through ${dims.format(u(5.0))} North window. Modern Scandinavian-minimalist luxury aesthetic, white oak herringbone flooring, matte charcoal feature walls, brass fixtures, 8k resolution, ray-traced shadows, Unreal Engine 5 Lumen interior render, photorealistic architectural digest style --ar 16:9 --v 6.0';
  }

  static String _buildEyeLevelPrompt({
    required DynamicFloorDimensions dims,
    required List<RecalibratedSpatialItem> items,
  }) {
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);
    final itemsDesc = items.map((it) => '${it.itemName} on ${it.targetWall} (${it.facingDirection})').join(', ');

    return 'Eye-level cinematic interior architectural photograph standing at the room entrance doorway (at y = ${dims.format(dims.roomLength)} on East wall) looking into a modern master bedroom suite (${dims.format(dims.roomWidth)} x ${dims.format(dims.roomLength)}). Foreground shows the wide hardwood circulation walkway leading past the ensuite bathroom East door. In the main room: $itemsDesc. Large ${dims.format(u(5.0))} window on the North wall with sheer white linen curtains filtering soft daylight. High-end interior styling: textured linen bedding, bespoke fluted wood acoustic wall panels, floating vanity console with warm backlight, designer seating. Volumetric sun rays, shallow depth of field, f/2.8 24mm architectural lens, Hasselblad X2D 100C photo, hyper-realistic materials, award-winning interior design --ar 16:9 --v 6.0';
  }

  static String _buildTopDownPrompt({
    required DynamicFloorDimensions dims,
    required List<RecalibratedSpatialItem> items,
  }) {
    final itemsDesc = items.map((it) => '${it.itemName} (${dims.format(it.width)}x${dims.format(it.length)} at X:${dims.format(it.x)}, Y:${dims.format(it.y)})').join('; ');

    return 'Architectural 3D axonometric top-down render of complete floor plan: Master Bedroom (${dims.format(dims.roomWidth)} x ${dims.format(dims.roomLength)}), Ensuite Bathroom (${dims.format(dims.bathWidth)} x ${dims.format(dims.bathLength)}), Modular Kitchen (${dims.format(dims.kitchenWidth)} x ${dims.format(dims.kitchenLength)}), and Staircase Core (${dims.format(dims.staircaseWidth)}). Furniture layout: $itemsDesc. Crisp dimensional shadows, clean color zoning (periwinkle bedroom floor, mint bathroom tile, warm oak staircase), modern architectural CAD presentation render --ar 1:1 --v 6.0';
  }

  static String _buildCadPrompt({
    required DynamicFloorDimensions dims,
    required List<RecalibratedSpatialItem> items,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('AUTOCAD 2D TECHNICAL BLUEPRINT SPECIFICATION:');
    buffer.writeln('- Boundary: ${dims.format(dims.roomWidth)} (X) × ${dims.format(dims.roomLength)} (Y) | Ceiling: ${dims.format(dims.ceilingHeight)}');
    for (final it in items) {
      buffer.writeln('- ${it.itemName}: Bounding Box [${dims.format(it.x)}, ${dims.format(it.y)}] to [${dims.format(it.xMax)}, ${dims.format(it.yMax)}], Height: ${dims.format(it.height)}, Wall: ${it.targetWall}, Facing: ${it.facingDirection}');
    }
    return buffer.toString();
  }
}

class _RawSpatialData {
  final String id;
  final RoomItemPlacement placement;
  final String itemName;
  final String targetWall;
  final String facingDirection;
  final int rotationDegrees;
  final double x;
  final double y;
  final double z;
  final double width;
  final double length;
  final double? rawWidth;
  final double? rawLength;
  final double height;
  final String formula;
  final String engineeringReason;
  final bool isCustom;

  _RawSpatialData({
    required this.id,
    required this.placement,
    required this.itemName,
    required this.targetWall,
    required this.facingDirection,
    required this.rotationDegrees,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.length,
    this.rawWidth,
    this.rawLength,
    required this.height,
    required this.formula,
    required this.engineeringReason,
    required this.isCustom,
  });
}
