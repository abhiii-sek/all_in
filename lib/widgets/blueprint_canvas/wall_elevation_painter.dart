import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dynamic_floor_model.dart';
import '../../services/architectural_prompt_service.dart';
import 'dynamic_floor_2d_painter.dart';

class WallElevationItem {
  final RoomItemPlacement placement;
  final MathematicalItemDimension calcItem;
  final double wallPosX; // Horizontal distance from left corner of this wall
  final double wallWidth; // Span along this wall
  final double elevation; // Height above floor (AFF)
  final double height; // Vertical height of item
  final Color color;

  WallElevationItem({
    required this.placement,
    required this.calcItem,
    required this.wallPosX,
    required this.wallWidth,
    required this.elevation,
    required this.height,
    required this.color,
  });
}

class WallSectionInfo {
  final String wallKey;
  final String title;
  final double span;
  final Offset origin;

  WallSectionInfo({
    required this.wallKey,
    required this.title,
    required this.span,
    required this.origin,
  });
}

class WallElevationPainter extends CustomPainter {
  final DynamicFloorDimensions dims;
  final String wallKey; // 'All Walls (4-Wall Panoramic)', 'East Wall (E)', 'West Wall (W)', 'North Wall (N)', 'South Wall (S)'
  final List<MathematicalItemDimension> items;
  final List<RoomItemPlacement> placements;
  final String? selectedItemId;
  final bool isDarkMode;
  final double scale;
  final Rect? hoveredTargetRect;
  final Color? hoveredAccentColor;

  WallElevationPainter({
    required this.dims,
    required this.wallKey,
    required this.items,
    required this.placements,
    this.selectedItemId,
    this.isDarkMode = true,
    this.scale = 32.0,
    this.hoveredTargetRect,
    this.hoveredAccentColor,
  });

  static bool checkIsAllWalls(String key) {
    final k = key.toLowerCase();
    return k.startsWith('all') || k.contains('panoramic') || k.contains('4-wall');
  }

  bool get isAllWalls => checkIsAllWalls(wallKey);

  /// Total span of the selected wall or all 4 walls combined
  double get totalWallSpan {
    if (isAllWalls) {
      return (dims.roomLength * 2.0) + (dims.roomWidth * 2.0); // 58.0 ft
    }
    final w = wallKey.toLowerCase();
    if (w.contains('east') || w.contains('west') || w.contains('(e)') || w.contains('(w)')) {
      return dims.roomLength; // Longitudinal wall span (18.5 ft)
    } else {
      return dims.roomWidth; // Transverse wall span (10.5 ft)
    }
  }

  /// Total ceiling height
  double get totalWallHeight => dims.ceilingHeight;

  /// Gap between wall sections in All Walls View (in feet)
  static const double wallGapFeet = 1.5;

  /// Origin offset for the wall elevation box on the canvas
  static Offset getOrigin({
    required DynamicFloorDimensions dims,
    required String wallKey,
    required Size canvasSize,
    double scale = 32.0,
  }) {
    final bool isAll = checkIsAllWalls(wallKey);
    final double wallSpan;
    if (isAll) {
      wallSpan = (dims.roomLength * 2.0) + (dims.roomWidth * 2.0) + (3 * wallGapFeet);
    } else {
      final w = wallKey.toLowerCase();
      wallSpan = (w.contains('east') || w.contains('west') || w.contains('(e)') || w.contains('(w)'))
          ? dims.roomLength
          : dims.roomWidth;
    }

    final wallSpanPx = wallSpan * scale;
    final wallHeightPx = dims.ceilingHeight * scale;

    final center = Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);
    return Offset(center.dx - wallSpanPx / 2.0, center.dy - wallHeightPx / 2.0);
  }

  /// Gets the list of wall sections and their origins
  static List<WallSectionInfo> getWallSections({
    required DynamicFloorDimensions dims,
    required String wallKey,
    required Size canvasSize,
    double scale = 32.0,
  }) {
    final baseOrigin = getOrigin(dims: dims, wallKey: wallKey, canvasSize: canvasSize, scale: scale);
    final isAll = checkIsAllWalls(wallKey);

    if (!isAll) {
      final w = wallKey.toLowerCase();
      final span = (w.contains('east') || w.contains('west') || w.contains('(e)') || w.contains('(w)'))
          ? dims.roomLength
          : dims.roomWidth;
      return [
        WallSectionInfo(
          wallKey: wallKey,
          title: wallKey.toUpperCase(),
          span: span,
          origin: baseOrigin,
        ),
      ];
    }

    // Panoramic 4-Wall sequence: West (18.5') -> South (10.5') -> East (18.5') -> North (10.5')
    final gapPx = wallGapFeet * scale;
    double currentX = baseOrigin.dx;

    final sections = <WallSectionInfo>[];

    // 1. West Wall
    sections.add(WallSectionInfo(
      wallKey: 'West Wall (W)',
      title: 'WEST ELEVATION (${dims.format(dims.roomLength)})',
      span: dims.roomLength,
      origin: Offset(currentX, baseOrigin.dy),
    ));
    currentX += (dims.roomLength * scale) + gapPx;

    // 2. South Wall
    sections.add(WallSectionInfo(
      wallKey: 'South Wall (S)',
      title: 'SOUTH ELEVATION (${dims.format(dims.roomWidth)})',
      span: dims.roomWidth,
      origin: Offset(currentX, baseOrigin.dy),
    ));
    currentX += (dims.roomWidth * scale) + gapPx;

    // 3. East Wall
    sections.add(WallSectionInfo(
      wallKey: 'East Wall (E)',
      title: 'EAST ELEVATION (${dims.format(dims.roomLength)})',
      span: dims.roomLength,
      origin: Offset(currentX, baseOrigin.dy),
    ));
    currentX += (dims.roomLength * scale) + gapPx;

    // 4. North Wall
    sections.add(WallSectionInfo(
      wallKey: 'North Wall (N)',
      title: 'NORTH ELEVATION (${dims.format(dims.roomWidth)})',
      span: dims.roomWidth,
      origin: Offset(currentX, baseOrigin.dy),
    ));

    return sections;
  }

  /// Calculate screen Rects for all items on the active wall (or all walls in panoramic view)
  static Map<String, Rect> calculateWallItemRects({
    required DynamicFloorDimensions dims,
    required String wallKey,
    required List<MathematicalItemDimension> items,
    required List<RoomItemPlacement> placements,
    required Size canvasSize,
    double scale = 32.0,
  }) {
    final Map<String, Rect> rectMap = {};
    final wallSections = getWallSections(dims: dims, wallKey: wallKey, canvasSize: canvasSize, scale: scale);
    final wallH = dims.ceilingHeight;

    for (final section in wallSections) {
      final sKeyLower = section.wallKey.toLowerCase();
      final origin = section.origin;

      for (final p in placements) {
        final target = p.targetWall.toLowerCase();
        final bool matchesWall = _isItemOnWall(target, sKeyLower);
        if (!matchesWall) continue;

        final calcItem = items.firstWhere(
          (it) => it.id == p.id,
          orElse: () => MathematicalItemDimension(
            id: p.id,
            itemName: p.itemName,
            targetWall: p.targetWall,
            width: p.customWidth ?? 3.0,
            length: p.customLength ?? 2.0,
            height: p.customHeight ?? 7.0,
            clearance: 0.0,
            formula: '',
            engineeringReason: '',
          ),
        );

        final wallProps = getWallItemProperties(dims, section.wallKey, p, calcItem);

        // Screen Y is measured from top: floor line is at (origin.dy + wallH * scale)
        final floorY = origin.dy + wallH * scale;
        final itemTopY = floorY - ((wallProps.elevation + wallProps.height) * scale);
        final itemLeftX = origin.dx + (wallProps.wallPosX * scale);
        final itemWidthPx = wallProps.wallWidth * scale;
        final itemHeightPx = wallProps.height * scale;

        rectMap[p.id] = Rect.fromLTWH(itemLeftX, itemTopY, itemWidthPx, itemHeightPx);
      }
    }

    return rectMap;
  }

  static bool _isItemOnWall(String itemTarget, String wallKeyLower) {
    if (wallKeyLower.contains('east') || wallKeyLower.contains('(e)')) {
      return itemTarget.contains('east') || itemTarget.contains('(e)') || itemTarget.contains('right');
    } else if (wallKeyLower.contains('west') || wallKeyLower.contains('(w)')) {
      return itemTarget.contains('west') || itemTarget.contains('(w)') || itemTarget.contains('left');
    } else if (wallKeyLower.contains('north') || wallKeyLower.contains('(n)')) {
      return itemTarget.contains('north') || itemTarget.contains('(n)') || itemTarget.contains('bottom') || itemTarget.contains('entry');
    } else {
      return itemTarget.contains('south') || itemTarget.contains('(s)') || itemTarget.contains('top');
    }
  }

  static WallElevationItem getWallItemProperties(
    DynamicFloorDimensions dims,
    String wallKey,
    RoomItemPlacement p,
    MathematicalItemDimension calcItem,
  ) {
    final wKeyLower = wallKey.toLowerCase();
    final nameLower = p.itemName.toLowerCase();
    final isEastWest = wKeyLower.contains('east') || wKeyLower.contains('west') || wKeyLower.contains('(e)') || wKeyLower.contains('(w)');
    final totalSpan = isEastWest ? dims.roomLength : dims.roomWidth;

    double wallPosX;
    double wallWidth;

    if (isEastWest) {
      wallPosX = p.customPosY ?? (calcItem.customPosY ?? 0.0);
      wallWidth = p.customLength ?? calcItem.length;
    } else {
      wallPosX = p.customPosX ?? (calcItem.customPosX ?? 0.0);
      wallWidth = p.customWidth ?? calcItem.width;
    }

    // Default height and elevation rules
    double defaultH;
    double defaultElev;

    if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
      defaultH = (dims.ceilingHeight * 0.90).clamp(7.5, dims.ceilingHeight);
      defaultElev = 0.0;
    } else if (nameLower.contains('ac') || nameLower.contains('air conditioner') || nameLower.contains('split')) {
      defaultH = 1.15;
      defaultElev = (dims.ceilingHeight - 1.8).clamp(7.0, dims.ceilingHeight - 1.3);
      if (wallWidth < 1.0 || wallWidth > 4.5) wallWidth = 3.2;
    } else if (nameLower.contains('bed')) {
      defaultH = 4.5; // Headboard height
      defaultElev = 0.0;
    } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('entertainment')) {
      defaultH = 4.8; // TV screen + fluted panel
      defaultElev = 2.0;
    } else if (nameLower.contains('dress') || nameLower.contains('mirror') || nameLower.contains('vanity')) {
      defaultH = 6.0;
      defaultElev = 1.5;
    } else if (nameLower.contains('study') || nameLower.contains('desk') || nameLower.contains('table')) {
      defaultH = 2.5;
      defaultElev = 0.0;
    } else if (nameLower.contains('door') || nameLower.contains('gate')) {
      defaultH = 7.0;
      defaultElev = 0.0;
    } else if (nameLower.contains('window')) {
      defaultH = 4.5;
      defaultElev = 3.0;
    } else {
      defaultH = 3.0;
      defaultElev = 0.0;
    }

    final finalH = (p.customHeight ?? defaultH).clamp(0.5, dims.ceilingHeight).toDouble();
    final finalElev = (p.customElevation ?? defaultElev).clamp(0.0, dims.ceilingHeight - finalH).toDouble();
    final finalPosX = wallPosX.clamp(0.0, math.max(0.0, totalSpan - wallWidth).toDouble()).toDouble();

    final color = DynamicFloor2DPainter.getItemColor(p.id, p.itemName);

    return WallElevationItem(
      placement: p,
      calcItem: calcItem,
      wallPosX: finalPosX,
      wallWidth: wallWidth,
      elevation: finalElev,
      height: finalH,
      color: color,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sections = getWallSections(dims: dims, wallKey: wallKey, canvasSize: size, scale: scale);
    final rectMap = calculateWallItemRects(dims: dims, wallKey: wallKey, items: items, placements: placements, canvasSize: size, scale: scale);

    for (final section in sections) {
      final origin = section.origin;
      final spanPx = section.span * scale;
      final heightPx = totalWallHeight * scale;

      // 1. Draw Architectural Grid & Wall Background Slabs
      _drawWallBackground(canvas, origin, spanPx, heightPx, section.span);

      // 2. Draw Architectural Level Lines (FFL 0.0', Lintel 7.0', Ceiling Level)
      _drawArchitecturalLevelLines(canvas, origin, spanPx, heightPx);

      // 3. Draw Doors and Windows belonging to this wall
      _drawWallOpenings(canvas, origin, spanPx, heightPx, section.wallKey, section.span);

      // 4. Draw Furniture & Wall-Mounted Items
      _drawSectionItems(canvas, section, rectMap);

      // 5. Draw Dimension Annotations & Wall Title Block
      _drawWallTitleAndAnnotations(canvas, origin, spanPx, heightPx, section.title, section.span);
    }

    // 6. Draw Selected Item Witness Lines & ONLY Height Resizing Handle
    if (selectedItemId != null && rectMap.containsKey(selectedItemId)) {
      final selectedRect = rectMap[selectedItemId]!;
      final pIndex = placements.indexWhere((p) => p.id == selectedItemId);
      if (pIndex != -1) {
        final p = placements[pIndex];
        final calcItem = items.firstWhere((it) => it.id == p.id, orElse: () => items.first);
        // Find which section this item belongs to
        final section = sections.firstWhere(
          (s) => _isItemOnWall(p.targetWall.toLowerCase(), s.wallKey.toLowerCase()),
          orElse: () => sections.first,
        );
        final wallProps = getWallItemProperties(dims, section.wallKey, p, calcItem);
        _drawElevationWitnessLines(canvas, section.origin, selectedRect, wallProps, section.span);
        _drawOnlyHeightElevationHandle(canvas, selectedRect, wallProps);
      }
    }

    // 7. Draw Hover Highlight
    if (hoveredTargetRect != null) {
      _drawHoverHighlight(canvas, hoveredTargetRect!, hoveredAccentColor ?? const Color(0xFF38BDF8));
    }
  }

  void _drawWallBackground(Canvas canvas, Offset origin, double spanPx, double heightPx, double wallSpan) {
    // Pure White Wall Surface for crisp CAD blueprint linework
    final wallRect = Rect.fromLTWH(origin.dx, origin.dy, spanPx, heightPx);
    canvas.drawRect(wallRect, Paint()..color = Colors.white);

    // Architectural Elevation Grid (1 ft squares)
    final gridPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 0.8;

    for (double x = 0; x <= wallSpan; x += 1.0) {
      final xPx = origin.dx + x * scale;
      canvas.drawLine(Offset(xPx, origin.dy), Offset(xPx, origin.dy + heightPx), gridPaint);
    }
    for (double y = 0; y <= totalWallHeight; y += 1.0) {
      final yPx = origin.dy + heightPx - (y * scale);
      canvas.drawLine(Offset(origin.dx, yPx), Offset(origin.dx + spanPx, yPx), gridPaint);
    }

    // Top Concrete Ceiling Slab Hash
    final slabPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    final slabBorder = Paint()
      ..color = Colors.black
      ..strokeWidth = 3.0;

    // Ceiling Structural Beam (12px thick at top)
    canvas.drawRect(Rect.fromLTWH(origin.dx - 10, origin.dy - 12, spanPx + 20, 12), slabPaint);
    canvas.drawLine(Offset(origin.dx, origin.dy), Offset(origin.dx + spanPx, origin.dy), slabBorder);

    // Finished Floor Level Slab (16px thick at bottom)
    final floorY = origin.dy + heightPx;
    canvas.drawRect(Rect.fromLTWH(origin.dx - 10, floorY, spanPx + 20, 16), slabPaint);
    canvas.drawLine(Offset(origin.dx, floorY), Offset(origin.dx + spanPx, floorY), slabBorder..strokeWidth = 4.0);

    // Left and Right Wall Corners (Solid Black 4px Jambs)
    final jambPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4.0;
    canvas.drawLine(Offset(origin.dx, origin.dy), Offset(origin.dx, floorY), jambPaint);
    canvas.drawLine(Offset(origin.dx + spanPx, origin.dy), Offset(origin.dx + spanPx, floorY), jambPaint);
  }

  void _drawArchitecturalLevelLines(Canvas canvas, Offset origin, double spanPx, double heightPx) {
    final floorY = origin.dy + heightPx;

    final levelDashPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.0;

    // 1. 0.00' FFL (Finished Floor Level) Mark
    _drawLevelTag(canvas, Offset(origin.dx - 12, floorY), '±0.00\' FFL', Colors.black, const Color(0xFF0F172A));

    // 2. 3.00' Window Sill Level (if relevant)
    if (totalWallHeight > 4.0) {
      final sillY = floorY - 3.0 * scale;
      _drawDashedHorizontal(canvas, Offset(origin.dx, sillY), Offset(origin.dx + spanPx, sillY), levelDashPaint);
      _drawLevelTag(canvas, Offset(origin.dx - 12, sillY), '+3.00\' SILL', const Color(0xFF0284C7), const Color(0xFF0369A1));
    }

    // 3. 7.00' Lintel Beam Level (Standard Door / Window Top)
    if (totalWallHeight > 7.2) {
      final lintelY = floorY - 7.0 * scale;
      _drawDashedHorizontal(canvas, Offset(origin.dx, lintelY), Offset(origin.dx + spanPx, lintelY), levelDashPaint..color = const Color(0xFFEAB308));
      _drawLevelTag(canvas, Offset(origin.dx - 12, lintelY), '+7.00\' LINTEL', const Color(0xFFD97706), const Color(0xFFB45309));
    }

    // 4. Ceiling Height Level (CLG)
    _drawLevelTag(canvas, Offset(origin.dx - 12, origin.dy), '+${dims.format(totalWallHeight)} CLG', const Color(0xFF7C3AED), const Color(0xFF6D28D9));
  }

  void _drawLevelTag(Canvas canvas, Offset rightCenter, String label, Color textColor, Color markerColor) {
    final path = Path()
      ..moveTo(rightCenter.dx, rightCenter.dy)
      ..lineTo(rightCenter.dx - 8, rightCenter.dy - 5)
      ..lineTo(rightCenter.dx - 8, rightCenter.dy + 5)
      ..close();
    canvas.drawPath(path, Paint()..color = markerColor);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: textColor, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.3),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(rightCenter.dx - 12 - tp.width, rightCenter.dy - tp.height / 2));
  }

  void _drawDashedHorizontal(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashW = 4.0;
    const spaceW = 3.0;
    double curX = p1.dx;
    while (curX < p2.dx) {
      final nextX = math.min(curX + dashW, p2.dx);
      canvas.drawLine(Offset(curX, p1.dy), Offset(nextX, p1.dy), paint);
      curX += dashW + spaceW;
    }
  }

  void _drawWallOpenings(Canvas canvas, Offset origin, double spanPx, double heightPx, String currentWallKey, double wallSpan) {
    final floorY = origin.dy + heightPx;
    final wKeyLower = currentWallKey.toLowerCase();

    // 1. Master Bedroom Door at Far End of East Wall (E) (at y = 18.50 ft end)
    if (wKeyLower.contains('east') || wKeyLower.contains('(e)')) {
      const doorW = 3.0;
      const doorH = 7.0;
      final doorPosX = (wallSpan - doorW) * scale;
      final doorRect = Rect.fromLTWH(origin.dx + doorPosX, floorY - doorH * scale, doorW * scale, doorH * scale);

      final doorPaint = Paint()
        ..color = const Color(0xFFEAB308).withValues(alpha: 0.15)
        ..style = PaintingStyle.fill;
      final doorBorder = Paint()
        ..color = const Color(0xFFCA8A04)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawRect(doorRect, doorPaint);
      canvas.drawRect(doorRect, doorBorder);

      final handleY = floorY - 3.3 * scale;
      final handleX = doorRect.left + 10;
      canvas.drawCircle(Offset(handleX, handleY), 3.0, Paint()..color = const Color(0xFF854D0E));
      canvas.drawLine(Offset(handleX, handleY), Offset(handleX + 8, handleY), Paint()..color = const Color(0xFF854D0E)..strokeWidth = 2.0);

      _drawItemBadge(canvas, doorRect, 'Room Door (3.0\' × 7.0\')', const Color(0xFFEAB308), Colors.black);
    }

    // 2. Ensuite Bathroom Partition & Gate on North Wall (N)
    if (wKeyLower.contains('north') || wKeyLower.contains('(n)')) {
      const doorW = 2.5;
      const doorH = 7.0;
      final doorPosX = 0.5 * scale;
      final doorRect = Rect.fromLTWH(origin.dx + doorPosX, floorY - doorH * scale, doorW * scale, doorH * scale);

      canvas.drawRect(doorRect, Paint()..color = const Color(0xFFEAB308).withValues(alpha: 0.18));
      canvas.drawRect(doorRect, Paint()..color = const Color(0xFFCA8A04)..strokeWidth = 2.2..style = PaintingStyle.stroke);

      final handleY = floorY - 3.3 * scale;
      canvas.drawCircle(Offset(doorRect.right - 10, handleY), 3.0, Paint()..color = const Color(0xFF854D0E));
      canvas.drawLine(Offset(doorRect.right - 18, handleY), Offset(doorRect.right - 10, handleY), Paint()..color = const Color(0xFF854D0E)..strokeWidth = 2.0);

      _drawItemBadge(canvas, doorRect, 'Bath Gate (2.5\' × 7.0\')', const Color(0xFFEAB308), Colors.black);
    }
  }

  void _drawSectionItems(Canvas canvas, WallSectionInfo section, Map<String, Rect> rectMap) {
    final sKeyLower = section.wallKey.toLowerCase();

    for (final p in placements) {
      if (!_isItemOnWall(p.targetWall.toLowerCase(), sKeyLower)) continue;
      final rect = rectMap[p.id];
      if (rect == null) continue;

      final isSelected = selectedItemId != null && p.id == selectedItemId;
      final calcItem = items.firstWhere(
        (it) => it.id == p.id,
        orElse: () => MathematicalItemDimension(
          id: p.id,
          itemName: p.itemName,
          targetWall: p.targetWall,
          width: p.customWidth ?? 3.0,
          length: p.customLength ?? 2.0,
          height: p.customHeight ?? 7.0,
          clearance: 0.0,
          formula: '',
          engineeringReason: '',
        ),
      );

      final wallProps = getWallItemProperties(dims, section.wallKey, p, calcItem);
      _drawSingleElevationItem(canvas, section.origin, rect, wallProps, isSelected);
    }
  }

  void _drawSingleElevationItem(
    Canvas canvas,
    Offset origin,
    Rect rect,
    WallElevationItem item,
    bool isSelected,
  ) {
    final nameLower = item.placement.itemName.toLowerCase();

    // Fill Item Silhouette
    final itemFill = Paint()
      ..color = isSelected ? item.color.withValues(alpha: 0.35) : item.color.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), itemFill);

    // Architectural Perimeter Stroke (Dark Navy / Solid Color)
    final itemStroke = Paint()
      ..color = isSelected ? item.color : const Color(0xFF0F172A)
      ..strokeWidth = isSelected ? 2.5 : 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), itemStroke);

    // Internal architectural detailing
    if (nameLower.contains('wardrobe') || nameLower.contains('closet')) {
      final doorCount = math.max(2, (item.wallWidth / 2.2).round());
      final doorW = rect.width / doorCount;
      for (int i = 1; i < doorCount; i++) {
        final x = rect.left + i * doorW;
        canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), itemStroke..strokeWidth = 1.0);
        canvas.drawCircle(Offset(x - 4, rect.center.dy), 2.5, Paint()..color = const Color(0xFF0F172A));
      }
    } else if (nameLower.contains('bed')) {
      final mattressH = math.min(1.8 * scale, rect.height * 0.4);
      final matRect = Rect.fromLTWH(rect.left, rect.bottom - mattressH, rect.width, mattressH);
      canvas.drawRRect(RRect.fromRectAndRadius(matRect, const Radius.circular(3)), Paint()..color = const Color(0xFF6366F1).withValues(alpha: 0.4));
      canvas.drawRRect(RRect.fromRectAndRadius(matRect, const Radius.circular(3)), itemStroke..strokeWidth = 1.2);
    } else if (nameLower.contains('ac') || nameLower.contains('air conditioner')) {
      for (double y = rect.top + 5; y < rect.bottom - 4; y += 4.0) {
        canvas.drawLine(Offset(rect.left + 6, y), Offset(rect.right - 6, y), itemStroke..strokeWidth = 0.8);
      }
    } else if (nameLower.contains('tv') || nameLower.contains('media')) {
      final tvBorder = rect.deflate(6);
      canvas.drawRRect(RRect.fromRectAndRadius(tvBorder, const Radius.circular(3)), Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.6));
    }

    // Name & Height Tag inside item
    _drawItemBadge(
      canvas,
      rect,
      '${item.placement.itemName} (H: ${dims.format(item.height)})',
      isSelected ? item.color : Colors.white,
      isSelected ? Colors.black : const Color(0xFF0F172A),
    );
  }

  void _drawItemBadge(Canvas canvas, Rect rect, String text, Color bgColor, Color textColor) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.center.dy),
      width: tp.width + 10,
      height: tp.height + 6,
    );

    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), Paint()..color = bgColor);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), Paint()..color = Colors.white..strokeWidth = 1.0..style = PaintingStyle.stroke);
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  void _drawElevationWitnessLines(Canvas canvas, Offset origin, Rect rect, WallElevationItem item, double wallSpan) {
    final floorY = origin.dy + totalWallHeight * scale;
    final spanPx = wallSpan * scale;

    final dashPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.2;
    final textBg = Paint()..color = Colors.white;
    final textBorder = Paint()..color = const Color(0xFF0284C7)..strokeWidth = 1.0..style = PaintingStyle.stroke;

    // 1. Left Wall Corner Clearance Line
    final leftGapPx = (rect.left - origin.dx).clamp(0.0, spanPx);
    if (leftGapPx > 1.5) {
      final p1 = Offset(origin.dx, rect.center.dy);
      final p2 = Offset(rect.left, rect.center.dy);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset((p1.dx + p2.dx) / 2, p1.dy), 'Left: ${dims.format(leftGapPx / scale)}', textBg, textBorder);
    }

    // 2. Right Wall Corner Clearance Line
    final rightGapPx = ((origin.dx + spanPx) - rect.right).clamp(0.0, spanPx);
    if (rightGapPx > 1.5) {
      final p1 = Offset(rect.right, rect.center.dy);
      final p2 = Offset(origin.dx + spanPx, rect.center.dy);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset((p1.dx + p2.dx) / 2, p1.dy), 'Right: ${dims.format(rightGapPx / scale)}', textBg, textBorder);
    }

    // 3. Elevation above floor (AFF) Witness Line
    final elevGapPx = (floorY - rect.bottom).clamp(0.0, totalWallHeight * scale);
    if (elevGapPx > 1.5) {
      final p1 = Offset(rect.center.dx, rect.bottom);
      final p2 = Offset(rect.center.dx, floorY);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset(p1.dx, (p1.dy + p2.dy) / 2), 'AFF: ${dims.format(elevGapPx / scale)}', textBg, textBorder);
    }

    // 4. Distance to Ceiling Line
    final clgGapPx = (rect.top - origin.dy).clamp(0.0, totalWallHeight * scale);
    if (clgGapPx > 1.5) {
      final p1 = Offset(rect.center.dx, origin.dy);
      final p2 = Offset(rect.center.dx, rect.top);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset(p1.dx, (p1.dy + p2.dy) / 2), 'CLG: ${dims.format(clgGapPx / scale)}', textBg, textBorder);
    }
  }

  /// Draws ONLY the Top Height Resizing Handle (↕) so user exclusively increases/decreases Height in Elevation View.
  void _drawOnlyHeightElevationHandle(Canvas canvas, Rect rect, WallElevationItem item) {
    // Glowing Halo around selected item
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(6)), glowPaint);

    final handleFill = Paint()..color = const Color(0xFF38BDF8);
    final handleBorder = Paint()..color = Colors.white..strokeWidth = 1.4..style = PaintingStyle.stroke;

    // 1. Top Height Stretch Pill (↕ Increase/Decrease Height)
    final topPill = Rect.fromCenter(center: rect.topCenter, width: 34.0, height: 12.0);
    canvas.drawRRect(RRect.fromRectAndRadius(topPill, const Radius.circular(6.0)), handleFill);
    canvas.drawRRect(RRect.fromRectAndRadius(topPill, const Radius.circular(6.0)), handleBorder);

    // Arrow icon text on handle: ↕
    final tpArrow = TextPainter(
      text: const TextSpan(
        text: '↕ HEIGHT',
        style: TextStyle(color: Color(0xFF0F172A), fontSize: 7.5, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpArrow.paint(canvas, Offset(topPill.center.dx - tpArrow.width / 2, topPill.center.dy - tpArrow.height / 2));
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLength = 4.0;
    const spaceLength = 3.0;
    final totalDist = (p2 - p1).distance;
    final dx = (p2.dx - p1.dx) / totalDist;
    final dy = (p2.dy - p1.dy) / totalDist;

    double curDist = 0.0;
    while (curDist < totalDist) {
      final start = Offset(p1.dx + dx * curDist, p1.dy + dy * curDist);
      final nextDist = math.min(curDist + dashLength, totalDist);
      final end = Offset(p1.dx + dx * nextDist, p1.dy + dy * nextDist);
      canvas.drawLine(start, end, paint);
      curDist += dashLength + spaceLength;
    }
  }

  void _drawClearanceBadge(Canvas canvas, Offset center, String label, Paint bg, Paint border) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF0369A1), fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(center: center, width: tp.width + 8, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), bg);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), border);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawWallTitleAndAnnotations(Canvas canvas, Offset origin, double spanPx, double heightPx, String titleText, double wallSpan) {
    final floorY = origin.dy + heightPx;

    // Dimension Line spanning entire wall width
    final dimPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.6;
    final dimY = floorY + 28.0;

    canvas.drawLine(Offset(origin.dx, dimY), Offset(origin.dx + spanPx, dimY), dimPaint);
    canvas.drawLine(Offset(origin.dx, dimY - 6), Offset(origin.dx, dimY + 6), dimPaint..strokeWidth = 2.0);
    canvas.drawLine(Offset(origin.dx + spanPx, dimY - 6), Offset(origin.dx + spanPx, dimY + 6), dimPaint..strokeWidth = 2.0);

    // Dimension text badge
    final tpDim = TextPainter(
      text: TextSpan(
        text: 'Total Wall Span: ${dims.format(wallSpan)} (Ceiling Height: ${dims.format(dims.ceilingHeight)})',
        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.0, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeCenter = Offset(origin.dx + spanPx / 2.0, dimY);
    final badgeRect = Rect.fromCenter(center: badgeCenter, width: tpDim.width + 12, height: tpDim.height + 6);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)), Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tpDim.paint(canvas, Offset(badgeCenter.dx - tpDim.width / 2, badgeCenter.dy - tpDim.height / 2));

    // Architectural Elevation Title Stamp
    final tpTitle = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: titleText, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13.0, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
          TextSpan(text: '\nMASTER BEDROOM SUITE ELEVATION • SCALE 1:30 ARCHITECTURAL CAD', style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w600)),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final titleCenter = Offset(origin.dx + spanPx / 2.0, origin.dy - 34.0);
    final titleRect = Rect.fromCenter(center: titleCenter, width: tpTitle.width + 20, height: tpTitle.height + 10);
    canvas.drawRRect(RRect.fromRectAndRadius(titleRect, const Radius.circular(6)), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(RRect.fromRectAndRadius(titleRect, const Radius.circular(6)), Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tpTitle.paint(canvas, Offset(titleCenter.dx - tpTitle.width / 2, titleCenter.dy - tpTitle.height / 2));
  }

  void _drawHoverHighlight(Canvas canvas, Rect targetRect, Color color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(targetRect.inflate(3), const Radius.circular(6)),
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(covariant WallElevationPainter oldDelegate) => true;
}
