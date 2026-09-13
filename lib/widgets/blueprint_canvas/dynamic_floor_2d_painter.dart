import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dynamic_floor_model.dart';
import '../../services/architectural_prompt_service.dart';

class DynamicFloor2DPainter extends CustomPainter {
  final DynamicFloorDimensions dims;
  final List<MathematicalItemDimension> items;
  final String? selectedItemId;
  final bool showDimensions;
  final bool showClearances;
  final bool showGrid;
  final bool showRoomLabels;
  final bool isDarkMode;
  final double scale; // pixels per unit (feet or meter)
  final Rect? hoveredTargetRect;
  final Color? hoveredAccentColor;

  DynamicFloor2DPainter({
    required this.dims,
    this.items = const [],
    this.selectedItemId,
    this.showDimensions = true,
    this.showClearances = true,
    this.showGrid = true,
    this.showRoomLabels = true,
    this.isDarkMode = true,
    this.scale = 28.0,
    this.hoveredTargetRect,
    this.hoveredAccentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Solid Pure White Background Outside House
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    // Snap origin exactly to CAD grid intersection so all walls align with the grid lines
    final origin = getOrigin(dims: dims, canvasSize: size, scale: scale);

    // 1. Grid Across Full Canvas Viewport
    if (showGrid) {
      _drawGrid(canvas, size);
    }

    // 2. Floor Room Slabs & Built-in Fixtures (Zoned fills)
    _drawFloorSlabs(canvas, origin);

    // 3. Dynamic Placed Furniture Items (Bed on West Wall, Wardrobe on East Wall, Study, etc.)
    _drawPlacedFurnitureItems(canvas, origin, size);

    // 4. Architectural Walls & Openings (Doors / Windows / Open Corridors)
    _drawWallsAndOpenings(canvas, origin);

    // 5. Room Tags / Labels (Dimensions & Calculated Area)
    if (showRoomLabels) {
      _drawRoomTags(canvas, origin);
    }

    // 6. Dimension Callouts
    if (showDimensions) {
      _drawDimensionAnnotations(canvas, origin);
    }

    // 7. North Compass & Architectural Scale Stamp
    _drawCompassAndScale(canvas, size, origin);

    // 8. Hover Highlight Outline
    if (hoveredTargetRect != null) {
      _drawHoverHighlight(canvas, hoveredTargetRect!, hoveredAccentColor ?? const Color(0xFF38BDF8));
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    // Architectural Blueprint CAD Grid lines (Steel Blue / Slate)
    final gridPaint = Paint()
      ..color = const Color(0xFF94A3B8).withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    final majorGridPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.70)
      ..strokeWidth = 1.3;

    const step = 20.0;
    int count = 0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), (count % 5 == 0) ? majorGridPaint : gridPaint);
      count++;
    }
    count = 0;
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), (count % 5 == 0) ? majorGridPaint : gridPaint);
      count++;
    }
  }

  void _drawFloorSlabs(Canvas canvas, Offset origin) {
    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;
    final twPx = dims.totalWidth * scale;
    final tlPx = dims.totalLength * scale;
    final bwPx = dims.bathWidth * scale;
    final blPx = dims.bathLength * scale;
    final kwPx = dims.kitchenWidth * scale;
    final klPx = dims.kitchenLength * scale;
    final galXPx = origin.dx + twPx - (dims.galleryWidth * scale);

    // Half of bathroom is inside the 18.50 ft room (top half), half is outside (bottom half)
    final halfBathL = blPx / 2.0; // 3.75 ft
    final bathTop = origin.dy + rlPx - halfBathL; // 18.50 - 3.75 = 14.75 ft
    final bathBottom = bathTop + blPx; // 14.75 + 7.50 = 22.25 ft

    // 1. MASTER BEDROOM SUITE & ENTRY PASSAGE FLOOR: Soft Architectural Periwinkle Slate (#DCE7FE)
    final bedFloorPaint = Paint()
      ..color = const Color(0xFFDCE7FE)
      ..style = PaintingStyle.fill;
    // Main bedroom floor area above bathroom top wall
    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy, rwPx, rlPx - halfBathL), bedFloorPaint);
    // Entry passage vestibule inside room next to top half of bathroom
    canvas.drawRect(Rect.fromLTWH(origin.dx + bwPx, bathTop, rwPx - bwPx, halfBathL), bedFloorPaint);

    // 2. MODULAR KITCHEN FLOOR: Warm Terracotta-Peach (#FED7AA)
    final kitchenFloorPaint = Paint()
      ..color = const Color(0xFFFED7AA)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy, kwPx, klPx), kitchenFloorPaint);

    // 3. ENSUITE BATHROOM FLOOR: Cool Aqua-Mint Tile (#A7F3D0)
    final bathFloorPaint = Paint()
      ..color = const Color(0xFFA7F3D0)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(origin.dx, bathTop, bwPx, blPx), bathFloorPaint);

    // Bathroom Shower Wet Area (#5EEAD4) at bottom of bathroom
    final showerDepthPx = dims.showerDepth * scale;
    final showerTop = bathBottom - showerDepthPx;
    final showerPaint = Paint()
      ..color = const Color(0xFF5EEAD4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(origin.dx, showerTop, bwPx, showerDepthPx), showerPaint);

    // 4. STAIRCASE CORE FLOOR: Warm Cedar / Amber Wood (#FEF3C7)
    final stairW = (origin.dx + twPx - (dims.galleryWidth * scale)) - (origin.dx + rwPx);
    final stairFloorPaint = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy + klPx, stairW, tlPx - klPx), stairFloorPaint);

    // 5. GALLERY & REMAINING CIRCULATION LANDING FLOOR: Soft Sandstone Gray (#E2E8F0)
    // All remaining floor space lying outside the bedroom (y >= 18.50 ft) and outside the bathroom
    final galleryFloorPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    // East circulation gallery run
    canvas.drawRect(Rect.fromLTWH(galXPx, origin.dy + klPx, dims.galleryWidth * scale, tlPx - klPx), galleryFloorPaint);
    // Landing & circulation vestibule outside bathroom and bedroom
    canvas.drawRect(Rect.fromLTWH(origin.dx + bwPx, origin.dy + rlPx, rwPx - bwPx, tlPx - rlPx), galleryFloorPaint);

    // Fine floor boundary divider lines between functional zones
    final zoneDividerPaint = Paint()
      ..color = const Color(0xFF64748B).withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy, rwPx, rlPx - halfBathL), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + bwPx, bathTop, rwPx - bwPx, halfBathL), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy, kwPx, klPx), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx, bathTop, bwPx, blPx), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy + klPx, stairW, tlPx - klPx), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(galXPx, origin.dy + klPx, dims.galleryWidth * scale, tlPx - klPx), zoneDividerPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + bwPx, origin.dy + rlPx, rwPx - bwPx, tlPx - rlPx), zoneDividerPaint);

    // Bathroom Shower Glass Dividing Line & Drain
    final fixturePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(origin.dx, showerTop),
      Offset(origin.dx + bwPx, showerTop),
      fixturePaint..strokeWidth = 2.0,
    );
    // Shower Drain
    canvas.drawCircle(
      Offset(origin.dx + bwPx / 2, showerTop + showerDepthPx / 2),
      4.0,
      fixturePaint..strokeWidth = 1.2,
    );

    // Floating Vanity Wash Basin in top half (inside room area)
    final vanityTop = bathTop + 6.0;
    final vanityRect = Rect.fromLTWH(origin.dx + bwPx * 0.52, vanityTop, bwPx * 0.42, 16.0);
    final basinOval = Rect.fromLTWH(origin.dx + bwPx * 0.56, vanityTop + 3.0, bwPx * 0.34, 10.0);
    canvas.drawRRect(RRect.fromRectAndRadius(vanityRect, const Radius.circular(3)), fixturePaint);
    canvas.drawOval(basinOval, fixturePaint);

    // Commode (WC) Fixture in middle zone
    final wcTop = bathTop + halfBathL + 4.0;
    final wcTank = Rect.fromLTWH(origin.dx + 4, wcTop, bwPx * 0.42, 6.0);
    final wcBowl = Rect.fromLTWH(origin.dx + 7, wcTop + 6.0, bwPx * 0.32, 12.0);
    canvas.drawRRect(RRect.fromRectAndRadius(wcTank, const Radius.circular(2)), fixturePaint);
    canvas.drawOval(wcBowl, fixturePaint);

    // Kitchen Countertop L-Shape & Fixtures
    final kCounterPaint = Paint()
      ..color = const Color(0xFFFEF3C7)
      ..style = PaintingStyle.fill;
    final kBorderPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final kCounterDepth = dims.kitchenCounterDepth * scale;
    // Top counter run
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy, kwPx, kCounterDepth), kCounterPaint);
    canvas.drawRect(Rect.fromLTWH(origin.dx + rwPx, origin.dy, kwPx, kCounterDepth), kBorderPaint);

    // 4-Burner Hob
    final hobW = kwPx * 0.35;
    final hobRect = Rect.fromLTWH(origin.dx + rwPx + kwPx * 0.15, origin.dy + 3, hobW, kCounterDepth - 6);
    canvas.drawRRect(RRect.fromRectAndRadius(hobRect, const Radius.circular(2)), kBorderPaint);
    const burnerRadius = 2.5;
    canvas.drawCircle(Offset(hobRect.left + hobW * 0.3, hobRect.top + hobRect.height * 0.3), burnerRadius, kBorderPaint);
    canvas.drawCircle(Offset(hobRect.left + hobW * 0.7, hobRect.top + hobRect.height * 0.3), burnerRadius, kBorderPaint);
    canvas.drawCircle(Offset(hobRect.left + hobW * 0.3, hobRect.top + hobRect.height * 0.7), burnerRadius, kBorderPaint);
    canvas.drawCircle(Offset(hobRect.left + hobW * 0.7, hobRect.top + hobRect.height * 0.7), burnerRadius, kBorderPaint);

    // Kitchen Sink
    final sinkW = kwPx * 0.32;
    final sinkRect = Rect.fromLTWH(origin.dx + rwPx + kwPx * 0.58, origin.dy + 4, sinkW, kCounterDepth - 8);
    canvas.drawRRect(RRect.fromRectAndRadius(sinkRect, const Radius.circular(2)), kBorderPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(sinkRect.deflate(2), const Radius.circular(2)), kBorderPaint);

    // Refrigerator footprint
    final fridgeRect = Rect.fromLTWH(origin.dx + rwPx + 4, origin.dy + klPx - 2.8 * scale, kCounterDepth, 2.4 * scale);
    canvas.drawRRect(RRect.fromRectAndRadius(fridgeRect, const Radius.circular(3)), kBorderPaint);

    // Breakfast Counter Run with Barstools
    final bCounterW = dims.breakfastCounterRun * scale;
    final bCounterRect = Rect.fromLTWH(origin.dx + rwPx, origin.dy + klPx - 8.0, bCounterW, 8.0);
    canvas.drawRRect(RRect.fromRectAndRadius(bCounterRect, const Radius.circular(2)), kBorderPaint);

    // Staircase Treads Pattern (Amber-Brown wood tones on sand floor)
    final treadPaint = Paint()
      ..color = const Color(0xFFD97706)
      ..strokeWidth = 1.2;
    const treadSpacing = 10.0;
    final topLandingH = 3.2 * scale;
    final bottomLandingH = 3.8 * scale;
    for (double y = origin.dy + klPx + topLandingH; y < origin.dy + tlPx - bottomLandingH; y += treadSpacing) {
      canvas.drawLine(Offset(origin.dx + rwPx, y), Offset(galXPx, y), treadPaint);
    }
  }

  void _drawWallsAndOpenings(Canvas canvas, Offset origin) {
    // Walls: Architectural Deep Charcoal Slate (#1E293B) with 6.5px stroke
    const wallThick = 6.5;
    final wallPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = wallThick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;
    final twPx = dims.totalWidth * scale;
    final tlPx = dims.totalLength * scale;
    final bwPx = dims.bathWidth * scale;
    final blPx = dims.bathLength * scale;
    final klPx = dims.kitchenLength * scale;
    final galXPx = origin.dx + twPx - (dims.galleryWidth * scale);

    final halfBathL = blPx / 2.0; // 3.75 ft
    final bathTop = origin.dy + rlPx - halfBathL; // 18.50 - 3.75 = 14.75 ft
    final bathBottom = bathTop + blPx; // 22.25 ft

    final topClearance = 3.2 * scale; // Clearance at top for Kitchen Gate entry
    final bottomClearance = 3.8 * scale; // Clearance at bottom for Floor & Room entry

    // 1. Exterior Perimeter Walls (Solid Deep Charcoal - 6.5px)
    // Top exterior wall (South exterior)
    canvas.drawLine(Offset(origin.dx, origin.dy), Offset(origin.dx + twPx, origin.dy), wallPaint);
    // Left exterior wall (West exterior - ends at bottom of bathroom)
    canvas.drawLine(Offset(origin.dx, origin.dy), Offset(origin.dx, origin.dy + tlPx), wallPaint);
    // Right exterior wall (East exterior - ends at bottom of house)
    canvas.drawLine(Offset(origin.dx + twPx, origin.dy), Offset(origin.dx + twPx, origin.dy + tlPx), wallPaint);
    // Bottom exterior wall (North exterior - continuous solid wall along the entire bottom of the house)
    canvas.drawLine(Offset(origin.dx, origin.dy + tlPx), Offset(origin.dx + twPx, origin.dy + tlPx), wallPaint);

    // 2. Central Dividing Wall (Left Suite vs Right Wing)
    // Master Room East wall strictly runs from top to y = origin.dy + rlPx (18.50 ft)
    canvas.drawLine(
      Offset(origin.dx + rwPx, origin.dy),
      Offset(origin.dx + rwPx, origin.dy + rlPx),
      wallPaint,
    );

    // 3. North Wall of Ensuite Bathroom inside room (at y = bathTop = 14.75 ft)
    // Solid wall from West exterior to doorway opening: from origin.dx to origin.dx + bwPx - bathDoorW
    final bathDoorW = math.min(2.5 * scale, bwPx * 0.55);
    canvas.drawLine(
      Offset(origin.dx, bathTop),
      Offset(origin.dx + bwPx - bathDoorW, bathTop),
      wallPaint,
    );

    // 4. Bathroom East Partition Wall (at x = origin.dx + bwPx)
    // Solid partition wall running from bathTop + bathDoorW down to bathBottom
    canvas.drawLine(
      Offset(origin.dx + bwPx, bathTop + bathDoorW),
      Offset(origin.dx + bwPx, bathBottom),
      wallPaint,
    );

    // 5. Kitchen Bottom Dividing Partition (With doorway gap on the far rightmost side)
    final kGateWidth = 3.0 * scale;
    final kGateLeft = origin.dx + twPx - kGateWidth;
    canvas.drawLine(
      Offset(origin.dx + rwPx, origin.dy + klPx),
      Offset(kGateLeft, origin.dy + klPx),
      wallPaint,
    );

    // 6. Gallery Corridor Partition Wall (Solid Slate)
    canvas.drawLine(
      Offset(galXPx, origin.dy + klPx + topClearance),
      Offset(galXPx, origin.dy + tlPx - bottomClearance),
      wallPaint..strokeWidth = 4.5,
    );

    // --- ARCHITECTURAL DOORS / GATES (YELLOW #EAB308 / #FACC15) ---
    // 1. Master Bedroom Door (Hinged at end of Room East Wall at y = 18.50 ft, swinging UP into bedroom)
    final doorPivot = Offset(origin.dx + rwPx, origin.dy + rlPx);
    final roomDoorW = math.min(3.0 * scale, (rwPx - bwPx) * 0.85);
    double doorStartAngle = -math.pi; // From horizontal left towards pivot
    double doorSweepAngle = math.pi / 2; // Swings UP into bedroom
    Offset doorTagOffset = Offset(origin.dx + rwPx - roomDoorW * 0.85, origin.dy + rlPx + 6);

    switch (dims.roomDoorSwingQuadrant % 4) {
      case 0: // Inward NW into bedroom (Standard as shown in user screenshot)
        doorStartAngle = -math.pi;
        doorSweepAngle = math.pi / 2;
        doorTagOffset = Offset(origin.dx + rwPx - roomDoorW * 0.85, origin.dy + rlPx + 6);
        break;
      case 1: // Inward SW into passage
        doorStartAngle = -math.pi;
        doorSweepAngle = -math.pi / 2;
        doorTagOffset = Offset(origin.dx + rwPx - roomDoorW * 0.85, origin.dy + rlPx - 18);
        break;
      case 2: // Outward SE into staircase / corridor
        doorStartAngle = 0;
        doorSweepAngle = math.pi / 2;
        doorTagOffset = Offset(origin.dx + rwPx + 8, origin.dy + rlPx + 6);
        break;
      case 3: // Outward NE into kitchen
        doorStartAngle = 0;
        doorSweepAngle = -math.pi / 2;
        doorTagOffset = Offset(origin.dx + rwPx + 8, origin.dy + rlPx - 18);
        break;
    }

    _drawDoorSwing(
      canvas,
      pivot: doorPivot,
      doorLength: roomDoorW,
      startAngle: doorStartAngle,
      sweepAngle: doorSweepAngle,
      label: 'ROOM DOOR (${dims.format(3.0)})',
      labelOffset: doorTagOffset,
    );

    // 2. Bathroom Gate (On Horizontal Top Partition Wall of Bathroom, swinging DOWN into bathroom)
    _drawDoorSwing(
      canvas,
      pivot: Offset(origin.dx + bwPx, bathTop),
      doorLength: bathDoorW,
      startAngle: -math.pi,
      sweepAngle: -math.pi / 2,
      label: 'BATH GATE (2.5 ft)',
      labelOffset: Offset(origin.dx + bwPx - bathDoorW + 4, bathTop + 8),
    );

    // 3. Kitchen Entry Gate (Shifted to Far Rightmost Side)
    _drawDoorSwing(
      canvas,
      pivot: Offset(kGateLeft, origin.dy + klPx),
      doorLength: kGateWidth,
      startAngle: 0,
      sweepAngle: math.pi / 2,
      label: 'KITCHEN GATE (3.0 ft)',
      labelOffset: Offset(kGateLeft + 4, origin.dy + klPx + 10),
    );

    // --- ARCHITECTURAL WINDOWS ---
    // (Master Bedroom South/Top Wall has NO window per specification)

    // 1. Bathroom Window / Ventilator (Bottom Exterior Wall)
    _drawWindow(
      canvas,
      p1: Offset(origin.dx + bwPx * 0.20, origin.dy + tlPx),
      p2: Offset(origin.dx + bwPx * 0.70, origin.dy + tlPx),
      label: 'V1: Bath Vent (2.0 ft)',
    );

    // 2. Kitchen Window (Top Right Exterior Wall)
    _drawWindow(
      canvas,
      p1: Offset(origin.dx + rwPx + 15, origin.dy),
      p2: Offset(origin.dx + twPx - 15, origin.dy),
      label: 'W1: Kitchen Window (4.0 ft)',
    );
  }

  void _drawDoorSwing(
    Canvas canvas, {
    required Offset pivot,
    required double doorLength,
    required double startAngle,
    required double sweepAngle,
    required String label,
    Offset? labelOffset,
  }) {
    // Gates / Doors: Vibrant Yellow (#EAB308 / #FACC15)
    final doorPaint = Paint()
      ..color = const Color(0xFFEAB308)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;

    final arcPaint = Paint()
      ..color = const Color(0xFFFACC15)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Door Leaf line (Open position)
    final openAngle = startAngle + sweepAngle;
    final leafEnd = Offset(
      pivot.dx + doorLength * math.cos(openAngle),
      pivot.dy + doorLength * math.sin(openAngle),
    );
    canvas.drawLine(pivot, leafEnd, doorPaint);

    // Swing Arc
    final arcRect = Rect.fromCircle(center: pivot, radius: doorLength);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    // Red Hinge Pin at Pivot (Prominent Red Anchor Dot)
    canvas.drawCircle(pivot, 4.0, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(pivot, 4.0, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.2);

    // Door Tag Badge (Solid Yellow Badge with Dark/Black Text for 100% clarity)
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF713F12), fontSize: 8.5, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();

    final badgeOffset = labelOffset ?? Offset(pivot.dx + 4, pivot.dy - 16);
    final tagRect = Rect.fromLTWH(badgeOffset.dx - 3, badgeOffset.dy - 2, tp.width + 6, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFEF08A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFFEAB308)..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    tp.paint(canvas, badgeOffset);
  }

  void _drawWindow(Canvas canvas, {required Offset p1, required Offset p2, required String label}) {
    final winPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.2;

    final bgFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final clearRect = Rect.fromPoints(
      Offset(p1.dx, p1.dy - 4),
      Offset(p2.dx, p2.dy + 4),
    );
    canvas.drawRect(clearRect, bgFill);

    // Double glass lines
    canvas.drawLine(Offset(p1.dx, p1.dy - 2), Offset(p2.dx, p2.dy - 2), winPaint);
    canvas.drawLine(Offset(p1.dx, p1.dy + 2), Offset(p2.dx, p2.dy + 2), winPaint);

    // End jambs (Black)
    final jambPaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 3.5;
    canvas.drawLine(Offset(p1.dx, p1.dy - 4), Offset(p1.dx, p1.dy + 4), jambPaint);
    canvas.drawLine(Offset(p2.dx, p2.dy - 4), Offset(p2.dx, p2.dy + 4), jambPaint);

    // Label Badge
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: Color(0xFF0369A1), fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final badgeCenter = Offset((p1.dx + p2.dx) / 2, p1.dy - 14);
    final badgeRect = Rect.fromCenter(center: badgeCenter, width: tp.width + 8, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), Paint()..color = Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), Paint()..color = const Color(0xFF0284C7)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    tp.paint(canvas, Offset(badgeCenter.dx - tp.width / 2, badgeCenter.dy - tp.height / 2));
  }

  void _drawRoomTags(Canvas canvas, Offset origin) {
    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;
    final twPx = dims.totalWidth * scale;
    final tlPx = dims.totalLength * scale;
    final bwPx = dims.bathWidth * scale;
    final kwPx = dims.kitchenWidth * scale;
    final klPx = dims.kitchenLength * scale;
    final galXPx = origin.dx + twPx - (dims.galleryWidth * scale);

    // Master Bedroom Stamp
    final bedSqFt = dims.roomWidth * dims.roomLength;
    _drawCadStamp(
      canvas,
      center: Offset(origin.dx + rwPx / 2, origin.dy + rlPx / 2),
      roomName: 'MASTER BEDROOM SUITE',
      dimsText: '${dims.format(dims.roomWidth)} × ${dims.format(dims.roomLength)}',
      areaText: '${bedSqFt.toStringAsFixed(1)} sq.ft (${(bedSqFt * 0.092903).toStringAsFixed(1)} m²)',
      accentColor: const Color(0xFF2563EB),
    );

    // Ensuite Bathroom Stamp
    final bathSqFt = dims.bathWidth * dims.bathLength;
    _drawCadStamp(
      canvas,
      center: Offset(origin.dx + bwPx / 2, origin.dy + rlPx),
      roomName: 'ENSUITE BATHROOM',
      dimsText: '${dims.format(dims.bathWidth)} × ${dims.format(dims.bathLength)}',
      areaText: '${bathSqFt.toStringAsFixed(1)} sq.ft',
      accentColor: const Color(0xFF0891B2),
      compact: true,
    );

    // Modular Kitchen Stamp
    final kitchSqFt = dims.kitchenWidth * dims.kitchenLength;
    _drawCadStamp(
      canvas,
      center: Offset(origin.dx + rwPx + kwPx / 2, origin.dy + klPx / 2),
      roomName: 'MODULAR KITCHEN',
      dimsText: '${dims.format(dims.kitchenWidth)} × ${dims.format(dims.kitchenLength)}',
      areaText: '${kitchSqFt.toStringAsFixed(1)} sq.ft',
      accentColor: const Color(0xFFDC2626),
    );

    // Staircase Stamp
    final stairW = (origin.dx + twPx - (dims.galleryWidth * scale)) - (origin.dx + rwPx);
    _drawCadStamp(
      canvas,
      center: Offset(origin.dx + rwPx + stairW / 2, origin.dy + klPx + (tlPx - klPx) / 2),
      roomName: 'STAIRCASE CORE',
      dimsText: 'Width: ${dims.format(dims.staircaseWidth)}',
      areaText: 'Circulation Core',
      accentColor: const Color(0xFFD97706),
      compact: true,
    );

    // Gallery Corridor Stamp
    _drawCadStamp(
      canvas,
      center: Offset(galXPx + (dims.galleryWidth * scale) / 2, origin.dy + klPx + (tlPx - klPx) / 2),
      roomName: 'GALLERY',
      dimsText: 'W: ${dims.format(dims.galleryWidth)}',
      areaText: 'Corridor',
      accentColor: const Color(0xFF475569),
      compact: true,
    );
  }

  void _drawCadStamp(
    Canvas canvas, {
    required Offset center,
    required String roomName,
    required String dimsText,
    required String areaText,
    required Color accentColor,
    bool compact = false,
  }) {
    final titleSpan = TextSpan(
      text: roomName,
      style: TextStyle(
        color: accentColor,
        fontSize: compact ? 9.5 : 11.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
    final dimSpan = TextSpan(
      text: '\n$dimsText',
      style: TextStyle(
        color: const Color(0xFF0F172A),
        fontSize: compact ? 8.5 : 10.0,
        fontWeight: FontWeight.bold,
      ),
    );
    final areaSpan = TextSpan(
      text: '\n$areaText',
      style: TextStyle(
        color: const Color(0xFF475569),
        fontSize: compact ? 8.0 : 9.0,
        fontWeight: FontWeight.w600,
      ),
    );

    final tp = TextPainter(
      text: TextSpan(children: [titleSpan, dimSpan, areaSpan]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: 180);

    final bgRect = Rect.fromCenter(
      center: center,
      width: tp.width + 16,
      height: tp.height + 12,
    );

    // Crisp White card on white floor with clean colored border (no blurry drop shadow)
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(6)), borderPaint);

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawDimensionAnnotations(Canvas canvas, Offset origin) {
    // High-visibility glowing dimension text styles
    const roomStyle = TextStyle(
      color: Color(0xFF38BDF8), // Electric Cyan
      fontSize: 10.0,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    );

    const totalStyle = TextStyle(
      color: Color(0xFF34D399), // Emerald Green
      fontSize: 10.5,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.3,
    );

    const lineCyan = Color(0xFF38BDF8);
    const lineGreen = Color(0xFF34D399);

    // Room Width Dimension (Top Left)
    _drawDimLine(
      canvas,
      Offset(origin.dx, origin.dy - 24),
      Offset(origin.dx + dims.roomWidth * scale, origin.dy - 24),
      'Room: ${dims.format(dims.roomWidth)}',
      roomStyle,
      lineColor: lineCyan,
    );

    // Kitchen Width Dimension (Top Right)
    _drawDimLine(
      canvas,
      Offset(origin.dx + dims.roomWidth * scale, origin.dy - 24),
      Offset(origin.dx + dims.totalWidth * scale, origin.dy - 24),
      'Kitchen: ${dims.format(dims.kitchenWidth)}',
      roomStyle.copyWith(color: const Color(0xFFF59E0B)),
      lineColor: const Color(0xFFF59E0B),
    );

    // Total Width Dimension (Further Top)
    _drawDimLine(
      canvas,
      Offset(origin.dx, origin.dy - 48),
      Offset(origin.dx + dims.totalWidth * scale, origin.dy - 48),
      'Total Width: ${dims.format(dims.totalWidth)}',
      totalStyle,
      lineColor: lineGreen,
    );

    // Master Room Length Dimension (Left Side)
    _drawDimLine(
      canvas,
      Offset(origin.dx - 24, origin.dy),
      Offset(origin.dx - 24, origin.dy + dims.roomLength * scale),
      'Room: ${dims.format(dims.roomLength)}',
      roomStyle,
      lineColor: lineCyan,
      isVertical: true,
    );

    // Bathroom Length Dimension (Left Side from bathTop to bottom of house)
    final halfBathL = dims.bathLength / 2.0;
    final bathTopY = origin.dy + (dims.roomLength - halfBathL) * scale;
    _drawDimLine(
      canvas,
      Offset(origin.dx - 24, bathTopY),
      Offset(origin.dx - 24, origin.dy + dims.totalLength * scale),
      'Bath: ${dims.format(dims.bathLength)}',
      roomStyle.copyWith(color: const Color(0xFF06B6D4)),
      lineColor: const Color(0xFF06B6D4),
      isVertical: true,
    );

    // Total Length Dimension (Further Left)
    _drawDimLine(
      canvas,
      Offset(origin.dx - 50, origin.dy),
      Offset(origin.dx - 50, origin.dy + dims.totalLength * scale),
      'Total Length: ${dims.format(dims.totalLength)}',
      totalStyle,
      lineColor: lineGreen,
      isVertical: true,
    );
  }

  void _drawDimLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    String text,
    TextStyle style, {
    bool isVertical = false,
    Color lineColor = const Color(0xFF38BDF8),
  }) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.6;
    canvas.drawLine(p1, p2, linePaint);

    // End ticks
    final tickPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0;
    if (isVertical) {
      canvas.drawLine(Offset(p1.dx - 5, p1.dy), Offset(p1.dx + 5, p1.dy), tickPaint);
      canvas.drawLine(Offset(p2.dx - 5, p2.dy), Offset(p2.dx + 5, p2.dy), tickPaint);
    } else {
      canvas.drawLine(Offset(p1.dx, p1.dy - 5), Offset(p1.dx, p1.dy + 5), tickPaint);
      canvas.drawLine(Offset(p2.dx, p2.dy - 5), Offset(p2.dx, p2.dy + 5), tickPaint);
    }

    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    final badgeRect = Rect.fromCenter(center: mid, width: tp.width + 12, height: tp.height + 6);
    
    // High contrast dark pill with glowing colored border
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      Paint()..color = const Color(0xFF0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(5)),
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(canvas, Offset(mid.dx - tp.width / 2, mid.dy - tp.height / 2));
  }

  void _drawCompassAndScale(Canvas canvas, Size size, Offset origin) {
    // 4-Point Architectural Cardinal Compass Rose on Top Right
    final compassCenter = Offset(size.width - 60, 60);

    // Compass Ring
    canvas.drawCircle(
      compassCenter,
      22,
      Paint()
        ..color = const Color(0xFF1E293B).withValues(alpha: 0.8)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      compassCenter,
      22,
      Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // 1. North Arrow (Red, Pointing Downwards)
    final pathNorth = Path()
      ..moveTo(compassCenter.dx, compassCenter.dy + 18)
      ..lineTo(compassCenter.dx - 6, compassCenter.dy)
      ..lineTo(compassCenter.dx + 6, compassCenter.dy)
      ..close();
    canvas.drawPath(pathNorth, Paint()..color = const Color(0xFFEF4444)..style = PaintingStyle.fill);

    // 2. South Arrow (White/Grey, Pointing Upwards)
    final pathSouth = Path()
      ..moveTo(compassCenter.dx, compassCenter.dy - 18)
      ..lineTo(compassCenter.dx - 6, compassCenter.dy)
      ..lineTo(compassCenter.dx + 6, compassCenter.dy)
      ..close();
    canvas.drawPath(pathSouth, Paint()..color = Colors.white70..style = PaintingStyle.fill);

    // 3. East Arrow (Cyan, Pointing Right)
    final pathEast = Path()
      ..moveTo(compassCenter.dx + 18, compassCenter.dy)
      ..lineTo(compassCenter.dx, compassCenter.dy - 6)
      ..lineTo(compassCenter.dx, compassCenter.dy + 6)
      ..close();
    canvas.drawPath(pathEast, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill);

    // 4. West Arrow (Cyan, Pointing Left)
    final pathWest = Path()
      ..moveTo(compassCenter.dx - 18, compassCenter.dy)
      ..lineTo(compassCenter.dx, compassCenter.dy - 6)
      ..lineTo(compassCenter.dx, compassCenter.dy + 6)
      ..close();
    canvas.drawPath(pathWest, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill);

    // Center Crosshair Dot
    canvas.drawCircle(compassCenter, 2.5, Paint()..color = const Color(0xFF0F172A));

    // 'N' Label (Bottom)
    final tpN = TextPainter(
      text: const TextSpan(text: 'N', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpN.paint(canvas, Offset(compassCenter.dx - tpN.width / 2, compassCenter.dy + 24));

    // 'S' Label (Top)
    final tpS = TextPainter(
      text: const TextSpan(text: 'S', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpS.paint(canvas, Offset(compassCenter.dx - tpS.width / 2, compassCenter.dy - 34));

    // 'E' Label (Right)
    final tpE = TextPainter(
      text: const TextSpan(text: 'E', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpE.paint(canvas, Offset(compassCenter.dx + 26, compassCenter.dy - tpE.height / 2));

    // 'W' Label (Left)
    final tpW = TextPainter(
      text: const TextSpan(text: 'W', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tpW.paint(canvas, Offset(compassCenter.dx - tpW.width - 26, compassCenter.dy - tpW.height / 2));

    // Scale Ruler (Bottom Left)
    final scalePos = Offset(30, size.height - 35);
    final scalePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.0;

    final rulerLengthPx = 5 * scale; // 5 units
    canvas.drawLine(scalePos, Offset(scalePos.dx + rulerLengthPx, scalePos.dy), scalePaint);
    canvas.drawLine(scalePos, Offset(scalePos.dx, scalePos.dy - 5), scalePaint);
    canvas.drawLine(Offset(scalePos.dx + rulerLengthPx, scalePos.dy), Offset(scalePos.dx + rulerLengthPx, scalePos.dy - 5), scalePaint);

    final tpScale = TextPainter(
      text: TextSpan(
        text: '0                5 ${dims.unit.symbol} (Scale 1:50 CAD)',
        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    tpScale.layout();
    tpScale.paint(canvas, Offset(scalePos.dx, scalePos.dy + 4));
  }

  static Offset getOrigin({
    required DynamicFloorDimensions dims,
    required Size canvasSize,
    double scale = 28.0,
  }) {
    final center = Offset(canvasSize.width / 2.0, canvasSize.height / 2.0);
    final totalW = dims.totalWidth * scale;
    final totalL = dims.totalLength * scale;
    const gridStep = 20.0;
    final rawX = center.dx - totalW / 2.0;
    final rawY = center.dy - totalL / 2.0;
    final snappedX = (rawX / gridStep).roundToDouble() * gridStep;
    final snappedY = (rawY / gridStep).roundToDouble() * gridStep;
    return Offset(snappedX, snappedY);
  }

  static Map<String, Rect> calculateItemRects({
    required DynamicFloorDimensions dims,
    required List<MathematicalItemDimension> items,
    required Size canvasSize,
    double scale = 28.0,
  }) {
    final Map<String, Rect> rectMap = {};
    if (items.isEmpty) return rectMap;

    final origin = getOrigin(dims: dims, canvasSize: canvasSize, scale: scale);
    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;

    double westWallY = origin.dy;
    double eastWallY = origin.dy;
    double northWallX = origin.dx;
    double southWallX = origin.dx;

    for (final item in items) {
      final target = item.targetWall.toLowerCase();
      final nameLower = item.itemName.toLowerCase();

      String facing = item.facingDirection;
      if (facing == 'Auto (Inward)' || facing.isEmpty) {
        if (target.contains('north') || target.contains('top') || target.contains('(n)')) {
          facing = 'Facing South (↓)';
        } else if (target.contains('south') || target.contains('bottom') || target.contains('(s)')) {
          facing = 'Facing North (↑)';
        } else if (target.contains('west') || target.contains('left') || target.contains('(w)')) {
          facing = 'Facing East (→)';
        } else if (target.contains('east') || target.contains('right') || target.contains('(e)')) {
          facing = 'Facing West (←)';
        } else {
          facing = 'Facing South (↓)';
        }
      }

      final bool isNorthOrSouthFacing = facing.contains('South') ||
          facing.contains('North') ||
          facing.contains('↓') ||
          facing.contains('↑');

      final bool isFullWall = nameLower.contains('full') ||
          nameLower.contains('wall to wall') ||
          nameLower.contains('entire') ||
          nameLower.contains('complete') ||
          nameLower.contains('all wall') ||
          nameLower.contains('whole wall');

      double itemW;
      double itemH;

      if (item.isCustom) {
        // Direct custom dimensions: width = Breadth (X-span), length = Length (Y-span)
        itemW = (item.width * scale).clamp(5.0, rwPx);
        itemH = (item.length * scale).clamp(5.0, rlPx);
      } else if (nameLower.contains('bed')) {
        if (isNorthOrSouthFacing) {
          itemW = (item.width * scale).clamp(10.0, rwPx);
          itemH = (item.length * scale).clamp(10.0, rlPx);
        } else {
          itemW = (item.length * scale).clamp(10.0, rwPx);
          itemH = (item.width * scale).clamp(10.0, rlPx);
        }
      } else {
        if (isNorthOrSouthFacing) {
          itemW = (item.length * scale).clamp(10.0, rwPx);
          itemH = (item.width * scale).clamp(10.0, rlPx);
        } else {
          itemW = (item.width * scale).clamp(10.0, rwPx);
          itemH = (item.length * scale).clamp(10.0, rlPx);
        }
      }

      // If rotation is 90 or 270 and not custom, swap itemW and itemH
      if (!item.isCustom && (item.rotationDegrees == 90 || item.rotationDegrees == 270)) {
        final temp = itemW;
        itemW = itemH;
        itemH = temp;
      }

      Rect rect;

      if (item.customPosX != null && item.customPosY != null) {
        rect = Rect.fromLTWH(
          origin.dx + item.customPosX! * scale,
          origin.dy + item.customPosY! * scale,
          itemW.clamp(5.0, rwPx),
          itemH.clamp(5.0, rlPx),
        );
      } else if (target.contains('north-west') || target.contains('n-w')) {
        rect = Rect.fromLTWH(origin.dx, origin.dy + rlPx - itemH, itemW, itemH);
      } else if (target.contains('north-east') || target.contains('n-e')) {
        rect = Rect.fromLTWH(origin.dx + rwPx - itemW, origin.dy + rlPx - itemH, itemW, itemH);
      } else if (target.contains('south-west') || target.contains('s-w')) {
        rect = Rect.fromLTWH(origin.dx, origin.dy, itemW, itemH);
      } else if (target.contains('south-east') || target.contains('s-e')) {
        rect = Rect.fromLTWH(origin.dx + rwPx - itemW, origin.dy, itemW, itemH);
      } else if (target.contains('west') || target.contains('left') || target.contains('(w)')) {
        if (isFullWall) {
          rect = Rect.fromLTWH(origin.dx, origin.dy, itemW, rlPx);
        } else {
          rect = Rect.fromLTWH(origin.dx, westWallY, itemW.clamp(10.0, rwPx), itemH.clamp(10.0, rlPx));
          westWallY += itemH;
        }
      } else if (target.contains('east') || target.contains('right') || target.contains('(e)')) {
        if (isFullWall) {
          rect = Rect.fromLTWH(origin.dx + rwPx - itemW, origin.dy, itemW, rlPx);
        } else {
          rect = Rect.fromLTWH(origin.dx + rwPx - itemW, eastWallY, itemW.clamp(10.0, rwPx), itemH.clamp(10.0, rlPx));
          eastWallY += itemH;
        }
      } else if (target.contains('north') || target.contains('(n)') || target.contains('bottom')) {
        if (isFullWall) {
          rect = Rect.fromLTWH(origin.dx, origin.dy + rlPx - itemH, rwPx, itemH);
        } else {
          rect = Rect.fromLTWH(northWallX, origin.dy + rlPx - itemH, itemW.clamp(10.0, rwPx), itemH.clamp(10.0, rlPx));
          northWallX += itemW;
        }
      } else if (target.contains('south') || target.contains('(s)') || target.contains('top')) {
        if (isFullWall) {
          rect = Rect.fromLTWH(origin.dx, origin.dy, rwPx, itemH);
        } else {
          rect = Rect.fromLTWH(southWallX, origin.dy, itemW.clamp(10.0, rwPx), itemH.clamp(10.0, rlPx));
          southWallX += itemW;
        }
      } else {
        rect = Rect.fromCenter(
          center: Offset(origin.dx + rwPx / 2, origin.dy + rlPx / 2),
          width: itemW.clamp(20.0, rwPx),
          height: itemH.clamp(20.0, rlPx),
        );
      }

      rectMap[item.id] = rect;
    }
    return rectMap;
  }

  void _drawPlacedFurnitureItems(Canvas canvas, Offset origin, [Size canvasSize = const Size(1800, 1500)]) {
    if (items.isEmpty) return;

    final rectMap = calculateItemRects(
      dims: dims,
      items: items,
      canvasSize: canvasSize,
      scale: scale,
    );

    for (final item in items) {
      final rect = rectMap[item.id];
      if (rect == null) continue;

      final isSelected = selectedItemId != null && item.id == selectedItemId;
      final target = item.targetWall.toLowerCase();
      final nameLower = item.itemName.toLowerCase();

      String facing = item.facingDirection;
      if (facing == 'Auto (Inward)' || facing.isEmpty) {
        if (target.contains('north') || target.contains('top') || target.contains('(n)')) {
          facing = 'Facing South (↓)';
        } else if (target.contains('south') || target.contains('bottom') || target.contains('(s)')) {
          facing = 'Facing North (↑)';
        } else if (target.contains('west') || target.contains('left') || target.contains('(w)')) {
          facing = 'Facing East (→)';
        } else if (target.contains('east') || target.contains('right') || target.contains('(e)')) {
          facing = 'Facing West (←)';
        } else {
          facing = 'Facing South (↓)';
        }
      }

      _drawSingleFurnitureItem(canvas, origin, rect, item, nameLower, isSelected, facing);
    }
  }

  static Color getItemColor(String itemId, String itemName, [int index = 0]) {
    final nameLower = itemName.toLowerCase();
    if (nameLower.contains('bed')) return const Color(0xFF2563EB); // Royal Blue
    if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
      return const Color(0xFF059669); // Emerald Green
    }
    if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
      return const Color(0xFF7C3AED); // Deep Violet
    }
    if (nameLower.contains('dress') || nameLower.contains('vanity') || nameLower.contains('mirror') || nameLower.contains('fram') || nameLower.contains('makeup')) {
      return const Color(0xFFE11D48); // Rose Pink
    }
    if (nameLower.contains('bar') || nameLower.contains('dining')) {
      return const Color(0xFFDC2626); // Crimson Red
    }
    if (nameLower.contains('study') || nameLower.contains('desk') || nameLower.contains('table') || nameLower.contains('work')) {
      return const Color(0xFFD97706); // Amber Orange
    }
    if (nameLower.contains('sofa') || nameLower.contains('couch') || nameLower.contains('seating') || nameLower.contains('chair')) {
      return const Color(0xFF0891B2); // Cyan Teal
    }
    if (nameLower.contains('book') || nameLower.contains('shelf') || nameLower.contains('cabinet')) {
      return const Color(0xFF4F46E5); // Indigo
    }

    const List<Color> fallbackPalette = [
      Color(0xFF2563EB),
      Color(0xFF059669),
      Color(0xFF7C3AED),
      Color(0xFFE11D48),
      Color(0xFFD97706),
      Color(0xFF0891B2),
      Color(0xFFDC2626),
      Color(0xFF4F46E5),
      Color(0xFF0D9488),
      Color(0xFFC026D3),
    ];
    final hash = (itemId.isNotEmpty ? itemId.hashCode : nameLower.hashCode).abs();
    return fallbackPalette[(hash + index) % fallbackPalette.length];
  }

  void _drawSingleFurnitureItem(
    Canvas canvas,
    Offset origin,
    Rect rect,
    MathematicalItemDimension item,
    String nameLower,
    bool isSelected,
    String facing,
  ) {
    // If selected, draw real-time 4-wall clearance witness lines
    if (isSelected) {
      _drawWallClearanceWitnessLines(canvas, origin, rect);
    }

    final itemColor = getItemColor(item.id, item.itemName);

    // 1. Base Footprint Fill & Border (Vibrant floor color per item for distinct occupancy identification)
    final fillPaint = Paint()
      ..color = itemColor.withValues(alpha: isSelected ? 0.45 : 0.35)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isSelected ? const Color(0xFF38BDF8) : itemColor
      ..strokeWidth = isSelected ? 2.8 : 2.2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), fillPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), borderPaint);

    if (isSelected) {
      // Draw outer glowing halo
      final glowPaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
        ..strokeWidth = 6.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(6)), glowPaint);

      // Draw 4 corner resize handles (Generous 12x12 white squares with blue borders)
      final handlePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final handleBorder = Paint()
        ..color = const Color(0xFF0284C7)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
      for (final corner in corners) {
        final hRect = Rect.fromCenter(center: corner, width: 12.0, height: 12.0);
        canvas.drawRect(hRect, handlePaint);
        canvas.drawRect(hRect, handleBorder);
      }

      // Draw 4 Side/Edge Stretch Handles (Breadth & Length stretch pills)
      final edgeHandleFill = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.fill;
      final edgeHandleBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      // Top Edge stretch pill (Length ↕)
      final topPill = Rect.fromCenter(center: rect.topCenter, width: 22.0, height: 8.0);
      canvas.drawRRect(RRect.fromRectAndRadius(topPill, const Radius.circular(4)), edgeHandleFill);
      canvas.drawRRect(RRect.fromRectAndRadius(topPill, const Radius.circular(4)), edgeHandleBorder);

      // Bottom Edge stretch pill (Length ↕)
      final bottomPill = Rect.fromCenter(center: rect.bottomCenter, width: 22.0, height: 8.0);
      canvas.drawRRect(RRect.fromRectAndRadius(bottomPill, const Radius.circular(4)), edgeHandleFill);
      canvas.drawRRect(RRect.fromRectAndRadius(bottomPill, const Radius.circular(4)), edgeHandleBorder);

      // Left Edge stretch pill (Breadth ↔)
      final leftPill = Rect.fromCenter(center: rect.centerLeft, width: 8.0, height: 22.0);
      canvas.drawRRect(RRect.fromRectAndRadius(leftPill, const Radius.circular(4)), edgeHandleFill);
      canvas.drawRRect(RRect.fromRectAndRadius(leftPill, const Radius.circular(4)), edgeHandleBorder);

      // Right Edge stretch pill (Breadth ↔)
      final rightPill = Rect.fromCenter(center: rect.centerRight, width: 8.0, height: 22.0);
      canvas.drawRRect(RRect.fromRectAndRadius(rightPill, const Radius.circular(4)), edgeHandleFill);
      canvas.drawRRect(RRect.fromRectAndRadius(rightPill, const Radius.circular(4)), edgeHandleBorder);

      // Draw top rotation connector and handle (Always visible!)
      final bool hasTopClearance = rect.top - origin.dy >= 22.0;
      final rotatePos = hasTopClearance ? Offset(rect.center.dx, rect.top - 18.0) : Offset(rect.center.dx, rect.bottom + 18.0);
      final connectStart = hasTopClearance ? Offset(rect.center.dx, rect.top) : Offset(rect.center.dx, rect.bottom);

      canvas.drawLine(
        connectStart,
        rotatePos,
        Paint()
          ..color = const Color(0xFF38BDF8)
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(
        rotatePos,
        7.5,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        rotatePos,
        7.5,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );

      // Rotation icon '⟳'
      final rotPainter = TextPainter(
        text: const TextSpan(
          text: '⟳',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rotPainter.paint(canvas, Offset(rotatePos.dx - rotPainter.width / 2, rotatePos.dy - rotPainter.height / 2));
    }

    // 2. Specialized CAD Linework Details (rendered in item's dedicated single color)
    final detailPaint = Paint()
      ..color = itemColor
      ..strokeWidth = 1.2;

    if (nameLower.contains('bed')) {
      if (facing.contains('South') || facing.contains('↓')) {
        // Headboard on North (Top edge), facing South
        final headboardRect = Rect.fromLTWH(rect.left, rect.top, rect.width, math.min(10.0, rect.height * 0.15));
        canvas.drawRect(headboardRect, Paint()..color = itemColor.withValues(alpha: 0.35));
        canvas.drawRect(headboardRect, detailPaint);

        final pillowW = rect.width * 0.35;
        final pillowH = rect.height * 0.22;
        final p1 = Rect.fromLTWH(rect.left + 6, rect.top + 10, pillowW, pillowH);
        final p2 = Rect.fromLTWH(rect.right - pillowW - 6, rect.top + 10, pillowW, pillowH);
        canvas.drawRRect(RRect.fromRectAndRadius(p1, const Radius.circular(2)), detailPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(p2, const Radius.circular(2)), detailPaint);

        canvas.drawLine(
          Offset(rect.left, rect.top + rect.height * 0.45),
          Offset(rect.right, rect.top + rect.height * 0.45),
          detailPaint..strokeWidth = 1.2,
        );
      } else if (facing.contains('North') || facing.contains('↑')) {
        // Headboard on South (Bottom edge), facing North
        final headboardRect = Rect.fromLTWH(rect.left, rect.bottom - math.min(10.0, rect.height * 0.15), rect.width, math.min(10.0, rect.height * 0.15));
        canvas.drawRect(headboardRect, Paint()..color = itemColor.withValues(alpha: 0.35));
        canvas.drawRect(headboardRect, detailPaint);

        final pillowW = rect.width * 0.35;
        final pillowH = rect.height * 0.22;
        final p1 = Rect.fromLTWH(rect.left + 6, rect.bottom - pillowH - 10, pillowW, pillowH);
        final p2 = Rect.fromLTWH(rect.right - pillowW - 6, rect.bottom - pillowH - 10, pillowW, pillowH);
        canvas.drawRRect(RRect.fromRectAndRadius(p1, const Radius.circular(2)), detailPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(p2, const Radius.circular(2)), detailPaint);

        canvas.drawLine(
          Offset(rect.left, rect.bottom - rect.height * 0.45),
          Offset(rect.right, rect.bottom - rect.height * 0.45),
          detailPaint..strokeWidth = 1.2,
        );
      } else if (facing.contains('West') || facing.contains('←')) {
        // Headboard on East (Right edge), facing West
        final headboardRect = Rect.fromLTWH(rect.right - math.min(10.0, rect.width * 0.15), rect.top, math.min(10.0, rect.width * 0.15), rect.height);
        canvas.drawRect(headboardRect, Paint()..color = itemColor.withValues(alpha: 0.35));
        canvas.drawRect(headboardRect, detailPaint);

        final pillowH = rect.height * 0.35;
        final pillowW = rect.width * 0.22;
        final p1 = Rect.fromLTWH(rect.right - pillowW - 10, rect.top + 6, pillowW, pillowH);
        final p2 = Rect.fromLTWH(rect.right - pillowW - 10, rect.bottom - pillowH - 6, pillowW, pillowH);
        canvas.drawRRect(RRect.fromRectAndRadius(p1, const Radius.circular(2)), detailPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(p2, const Radius.circular(2)), detailPaint);

        canvas.drawLine(
          Offset(rect.right - rect.width * 0.45, rect.top),
          Offset(rect.right - rect.width * 0.45, rect.bottom),
          detailPaint..strokeWidth = 1.2,
        );
      } else {
        // Headboard on West (Left edge), facing East
        final headboardRect = Rect.fromLTWH(rect.left, rect.top, math.min(10.0, rect.width * 0.15), rect.height);
        canvas.drawRect(headboardRect, Paint()..color = itemColor.withValues(alpha: 0.35));
        canvas.drawRect(headboardRect, detailPaint);

        final pillowH = rect.height * 0.35;
        final pillowW = rect.width * 0.22;
        final p1 = Rect.fromLTWH(rect.left + 10, rect.top + 6, pillowW, pillowH);
        final p2 = Rect.fromLTWH(rect.left + 10, rect.bottom - pillowH - 6, pillowW, pillowH);
        canvas.drawRRect(RRect.fromRectAndRadius(p1, const Radius.circular(2)), detailPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(p2, const Radius.circular(2)), detailPaint);

        canvas.drawLine(
          Offset(rect.left + rect.width * 0.45, rect.top),
          Offset(rect.left + rect.width * 0.45, rect.bottom),
          detailPaint..strokeWidth = 1.2,
        );
      }
    } else if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
      if (rect.width >= rect.height) {
        // Horizontal along North/South wall
        canvas.drawLine(Offset(rect.left, rect.top + rect.height * 0.5), Offset(rect.right, rect.top + rect.height * 0.5), detailPaint);
        for (double x = rect.left + 8; x < rect.right - 8; x += 12) {
          canvas.drawLine(Offset(x, rect.top + 3), Offset(x + 4, rect.bottom - 3), detailPaint..strokeWidth = 0.9);
        }
      } else {
        // Vertical along West/East wall
        canvas.drawLine(Offset(rect.left + rect.width * 0.5, rect.top), Offset(rect.left + rect.width * 0.5, rect.bottom), detailPaint);
        for (double y = rect.top + 8; y < rect.bottom - 8; y += 12) {
          canvas.drawLine(Offset(rect.left + 3, y), Offset(rect.right - 3, y + 4), detailPaint..strokeWidth = 0.9);
        }
      }
    } else if (nameLower.contains('dress') || nameLower.contains('desiss') || nameLower.contains('vanity') || nameLower.contains('mirror') || nameLower.contains('fram') || nameLower.contains('makeup')) {
      // Dressing Frame / Full Height Vanity Mirror CAD Details
      final mirrorRect = rect.deflate(2.0);
      canvas.drawRect(mirrorRect, Paint()..color = itemColor.withValues(alpha: 0.15)..style = PaintingStyle.fill);
      canvas.drawRect(mirrorRect, detailPaint);

      // Reflection diagonal slashes across mirror surface
      if (rect.width >= rect.height) {
        canvas.drawLine(Offset(rect.left + rect.width * 0.3, rect.top + 3), Offset(rect.left + rect.width * 0.45, rect.bottom - 3), detailPaint);
        canvas.drawLine(Offset(rect.left + rect.width * 0.6, rect.top + 3), Offset(rect.left + rect.width * 0.75, rect.bottom - 3), detailPaint);
      } else {
        canvas.drawLine(Offset(rect.left + 3, rect.top + rect.height * 0.3), Offset(rect.right - 3, rect.top + rect.height * 0.45), detailPaint);
        canvas.drawLine(Offset(rect.left + 3, rect.top + rect.height * 0.6), Offset(rect.right - 3, rect.top + rect.height * 0.75), detailPaint);
      }
    } else if (nameLower.contains('study') || nameLower.contains('table') || nameLower.contains('desk')) {
      // Laptop / monitor icon rectangle
      final lapW = math.min(rect.width * 0.4, 20.0);
      final lapH = math.min(rect.height * 0.35, 14.0);
      final lapRect = Rect.fromCenter(center: rect.center, width: lapW, height: lapH);
      canvas.drawRRect(RRect.fromRectAndRadius(lapRect, const Radius.circular(2)), detailPaint);

      // Chair footprint circle behind desk on facing side
      if (showClearances) {
        Offset chairCenter;
        if (facing.contains('South') || facing.contains('↓')) {
          chairCenter = Offset(rect.center.dx, rect.bottom + 10);
        } else if (facing.contains('North') || facing.contains('↑')) {
          chairCenter = Offset(rect.center.dx, rect.top - 10);
        } else if (facing.contains('West') || facing.contains('←')) {
          chairCenter = Offset(rect.left - 10, rect.center.dy);
        } else {
          chairCenter = Offset(rect.right + 10, rect.center.dy);
        }

        canvas.drawCircle(
          chairCenter,
          7.5,
          Paint()
            ..color = itemColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          chairCenter,
          7.5,
          Paint()
            ..color = itemColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
      // TV Mount bar
      if (rect.width >= rect.height) {
        canvas.drawLine(
          Offset(rect.left + 2, rect.center.dy),
          Offset(rect.right - 2, rect.center.dy),
          detailPaint..strokeWidth = 2.2,
        );
      } else {
        canvas.drawLine(
          Offset(rect.center.dx, rect.top + 2),
          Offset(rect.center.dx, rect.bottom - 2),
          detailPaint..strokeWidth = 2.2,
        );
      }
    } else {
      // Generic CAD diagonal corner ticks
      canvas.drawLine(rect.topLeft, Offset(rect.left + 6, rect.top + 6), detailPaint);
      canvas.drawLine(rect.bottomRight, Offset(rect.right - 6, rect.bottom - 6), detailPaint);
    }

    // 3. Item Name & Calculated Dimension Badge (Solid item color pill with white text)
    final tp = TextPainter(
      text: TextSpan(
        text: '${item.itemName}\n${dims.format(item.width)} × ${dims.format(item.length)}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.8,
          fontWeight: FontWeight.bold,
          height: 1.15,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: rect.width + 20);

    final bgPill = Rect.fromCenter(
      center: rect.center,
      width: tp.width + 8,
      height: tp.height + 6,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgPill, const Radius.circular(4)),
      Paint()..color = itemColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgPill, const Radius.circular(4)),
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0,
    );
    // 4. If selected, draw Glowing Handles & Live Dimension/Position HUD on Canvas
    if (isSelected) {
      _drawSelectionHandles(canvas, origin, rect, item, itemColor);
    }
  }

  void _drawSelectionHandles(
    Canvas canvas,
    Offset origin,
    Rect rect,
    MathematicalItemDimension item,
    Color itemColor,
  ) {
    // 1. Glowing outer halo
    final glowPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect.inflate(2.0), glowPaint);

    // 2. High-contrast selection outline
    final selBorder = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, selBorder);

    // 3. Top Rotation Handle Stem & Grip
    final rotHandlePos = Offset(rect.center.dx, rect.top - 18.0);
    canvas.drawLine(
      Offset(rect.center.dx, rect.top),
      rotHandlePos,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2.2,
    );
    canvas.drawCircle(
      rotHandlePos,
      8.0,
      Paint()..color = const Color(0xFFF59E0B)..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      rotHandlePos,
      8.0,
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5,
    );
    final rotTp = TextPainter(
      text: const TextSpan(
        text: '⟳',
        style: TextStyle(color: Colors.black, fontSize: 10.0, fontWeight: FontWeight.w900),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rotTp.paint(canvas, Offset(rotHandlePos.dx - rotTp.width / 2, rotHandlePos.dy - rotTp.height / 2));

    // 4. Four Corner Stretch/Resize Grips
    final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
    for (final c in corners) {
      canvas.drawCircle(c, 6.0, Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawCircle(c, 6.0, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 2.2);
    }

    // 5. Four Edge Stretch Grips (Green for Length ↕, Cyan for Breadth ↔)
    _drawEdgeStretchPill(canvas, rect.topCenter, const Color(0xFF10B981));
    _drawEdgeStretchPill(canvas, rect.bottomCenter, const Color(0xFF10B981));
    _drawEdgeStretchPill(canvas, rect.centerLeft, const Color(0xFF38BDF8));
    _drawEdgeStretchPill(canvas, rect.centerRight, const Color(0xFF38BDF8));

    // 6. Live Coordinates & Dimensions Tag Badge (below the item)
    final posXFt = (rect.left - origin.dx) / scale;
    final posYFt = (rect.top - origin.dy) / scale;
    final tagText = '📐 ${dims.format(item.width)} × ${dims.format(item.length)}  •  📍 Pos: (${dims.format(posXFt)}, ${dims.format(posYFt)})';
    final tagTp = TextPainter(
      text: TextSpan(
        text: tagText,
        style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final tagRect = Rect.fromCenter(
      center: Offset(rect.center.dx, rect.bottom + 14.0),
      width: tagTp.width + 12,
      height: tagTp.height + 6,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(4)), Paint()..color = const Color(0xFF0F172A));
    canvas.drawRRect(RRect.fromRectAndRadius(tagRect, const Radius.circular(4)), Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    tagTp.paint(canvas, Offset(tagRect.center.dx - tagTp.width / 2, tagRect.center.dy - tagTp.height / 2));
  }

  void _drawEdgeStretchPill(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 5.5, Paint()..color = color..style = PaintingStyle.fill);
    canvas.drawCircle(center, 5.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _drawWallClearanceWitnessLines(Canvas canvas, Offset origin, Rect rect) {
    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;

    final leftGapPx = (rect.left - origin.dx).clamp(0.0, rwPx);
    final rightGapPx = ((origin.dx + rwPx) - rect.right).clamp(0.0, rwPx);
    final topGapPx = (rect.top - origin.dy).clamp(0.0, rlPx);
    final bottomGapPx = ((origin.dy + rlPx) - rect.bottom).clamp(0.0, rlPx);

    final leftFt = leftGapPx / scale;
    final rightFt = rightGapPx / scale;
    final topFt = topGapPx / scale;
    final bottomFt = bottomGapPx / scale;

    final dashPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.2;

    final textBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final textBorderPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 1. West / Left Clearance Line
    if (leftGapPx > 1.5) {
      final p1 = Offset(origin.dx, rect.center.dy);
      final p2 = Offset(rect.left, rect.center.dy);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset((p1.dx + p2.dx) / 2, p1.dy), 'W: ${dims.format(leftFt)}', textBgPaint, textBorderPaint);
    }

    // 2. East / Right Clearance Line
    if (rightGapPx > 1.5) {
      final p1 = Offset(rect.right, rect.center.dy);
      final p2 = Offset(origin.dx + rwPx, rect.center.dy);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset((p1.dx + p2.dx) / 2, p1.dy), 'E: ${dims.format(rightFt)}', textBgPaint, textBorderPaint);
    }

    // 3. South / Top Clearance Line
    if (topGapPx > 1.5) {
      final p1 = Offset(rect.center.dx, origin.dy);
      final p2 = Offset(rect.center.dx, rect.top);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset(p1.dx, (p1.dy + p2.dy) / 2), 'S: ${dims.format(topFt)}', textBgPaint, textBorderPaint);
    }

    // 4. North / Bottom Clearance Line
    if (bottomGapPx > 1.5) {
      final p1 = Offset(rect.center.dx, rect.bottom);
      final p2 = Offset(rect.center.dx, origin.dy + rlPx);
      _drawDashedLine(canvas, p1, p2, dashPaint);
      _drawClearanceBadge(canvas, Offset(p1.dx, (p1.dy + p2.dy) / 2), 'N: ${dims.format(bottomFt)}', textBgPaint, textBorderPaint);
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 3.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 2.0) return;

    final count = (dist / (dashWidth + dashSpace)).floor();
    final unitX = dx / dist;
    final unitY = dy / dist;

    for (int i = 0; i < count; i++) {
      final start = Offset(p1.dx + (unitX * i * (dashWidth + dashSpace)), p1.dy + (unitY * i * (dashWidth + dashSpace)));
      final end = Offset(start.dx + (unitX * dashWidth), start.dy + (unitY * dashWidth));
      canvas.drawLine(start, end, paint);
    }
  }

  void _drawClearanceBadge(Canvas canvas, Offset center, String text, Paint bgPaint, Paint borderPaint) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Color(0xFF0284C7), fontSize: 8.0, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromCenter(center: center, width: tp.width + 6, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(badgeRect, const Radius.circular(3)), borderPaint);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  void _drawHoverHighlight(Canvas canvas, Rect targetRect, Color color) {
    // 1. Subtle glowing outer halo
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect.inflate(3.0), const Radius.circular(6)), glowPaint);

    // 2. High-precision border
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(targetRect.inflate(1.0), const Radius.circular(5)), borderPaint);

    // 3. Technical Corner Brackets
    final bracketPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const bLen = 7.0;
    final r = targetRect.inflate(1.0);

    // Top-Left bracket
    canvas.drawLine(r.topLeft, Offset(r.left + bLen, r.top), bracketPaint);
    canvas.drawLine(r.topLeft, Offset(r.left, r.top + bLen), bracketPaint);

    // Top-Right bracket
    canvas.drawLine(r.topRight, Offset(r.right - bLen, r.top), bracketPaint);
    canvas.drawLine(r.topRight, Offset(r.right, r.top + bLen), bracketPaint);

    // Bottom-Left bracket
    canvas.drawLine(r.bottomLeft, Offset(r.left + bLen, r.bottom), bracketPaint);
    canvas.drawLine(r.bottomLeft, Offset(r.left, r.bottom - bLen), bracketPaint);

    // Bottom-Right bracket
    canvas.drawLine(r.bottomRight, Offset(r.right - bLen, r.bottom), bracketPaint);
    canvas.drawLine(r.bottomRight, Offset(r.right, r.bottom - bLen), bracketPaint);
  }

  @override
  bool shouldRepaint(covariant DynamicFloor2DPainter oldDelegate) {
    return oldDelegate.dims != dims ||
        oldDelegate.items != items ||
        oldDelegate.selectedItemId != selectedItemId ||
        oldDelegate.showDimensions != showDimensions ||
        oldDelegate.showClearances != showClearances ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showRoomLabels != showRoomLabels ||
        oldDelegate.scale != scale ||
        oldDelegate.isDarkMode != isDarkMode ||
        oldDelegate.hoveredTargetRect != hoveredTargetRect ||
        oldDelegate.hoveredAccentColor != hoveredAccentColor;
  }
}
