import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../../models/room_item.dart';
import '../../models/wall_opening.dart';

class Blueprint2DPainter extends CustomPainter {
  final RoomModel room;
  final bool showDimensions;
  final bool showClearances;
  final bool showGrid;
  final bool isDarkMode;
  final double scale; // pixels per meter

  Blueprint2DPainter({
    required this.room,
    this.showDimensions = true,
    this.showClearances = true,
    this.showGrid = true,
    this.isDarkMode = true,
    this.scale = 80.0, // 80 pixels = 1 meter
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final roomW = room.effectiveWidth * scale;
    final roomH = room.effectiveLength * scale;
    final roomRect = Rect.fromCenter(center: center, width: roomW, height: roomH);

    // 1. Draw Grid Background
    if (showGrid) {
      _drawBlueprintGrid(canvas, size);
    }

    // 2. Draw Floor Surface
    final floorPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(roomRect, floorPaint);

    // 3. Draw Floor Tile Tiling Pattern (Subtle)
    _drawFloorTiles(canvas, roomRect);

    // 4. Draw Furniture & Fixtures (Items + Clearances)
    final items = room.currentItems;
    for (final item in items) {
      _drawFurnitureItem2D(canvas, roomRect, item);
    }

    // 5. Draw Walls & Openings (Doors / Windows)
    _drawArchitecturalWalls(canvas, roomRect);

    // 6. Draw Dimension Strings & Rulers
    if (showDimensions) {
      _drawDimensionRulers(canvas, roomRect);
    }

    // 7. Draw North Compass
    _drawNorthCompass(canvas, size);
  }

  void _drawBlueprintGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF1E293B).withValues(alpha: 0.5)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    const gridSize = 20.0; // 25cm in 80px/m
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawFloorTiles(Canvas canvas, Rect roomRect) {
    final tilePaint = Paint()
      ..color = isDarkMode
          ? const Color(0xFF334155).withValues(alpha: 0.2)
          : const Color(0xFFCBD5E1).withValues(alpha: 0.3)
      ..strokeWidth = 0.8;

    final tileSize = 0.6 * scale; // 60x60 cm tiles
    for (double x = roomRect.left; x < roomRect.right; x += tileSize) {
      canvas.drawLine(Offset(x, roomRect.top), Offset(x, roomRect.bottom), tilePaint);
    }
    for (double y = roomRect.top; y < roomRect.bottom; y += tileSize) {
      canvas.drawLine(Offset(roomRect.left, y), Offset(roomRect.right, y), tilePaint);
    }
  }

  void _drawArchitecturalWalls(Canvas canvas, Rect roomRect) {
    const wallThick = 12.0; // wall thickness in px

    final wallPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0F172A)
      ..strokeWidth = wallThick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final innerFill = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = wallThick - 4;

    // Draw 4 main wall boundaries
    canvas.drawRect(roomRect, wallPaint);
    canvas.drawRect(roomRect, innerFill);

    // Draw Openings (Doors & Windows)
    for (final op in room.openings) {
      _drawWallOpening2D(canvas, roomRect, op);
    }
  }

  void _drawWallOpening2D(Canvas canvas, Rect roomRect, WallOpening op) {
    final opLengthPx = op.width * scale;
    final opOffsetPx = op.offsetFromCorner * scale;

    final bgPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;

    Offset start = Offset.zero;
    Offset end = Offset.zero;

    switch (op.wallIndex) {
      case 0: // Top wall (North)
        start = Offset(roomRect.left + opOffsetPx, roomRect.top);
        end = Offset(start.dx + opLengthPx, roomRect.top);
        break;
      case 1: // Right wall (East)
        start = Offset(roomRect.right, roomRect.top + opOffsetPx);
        end = Offset(roomRect.right, start.dy + opLengthPx);
        break;
      case 2: // Bottom wall (South)
        start = Offset(roomRect.left + opOffsetPx, roomRect.bottom);
        end = Offset(start.dx + opLengthPx, roomRect.bottom);
        break;
      case 3: // Left wall (West)
        start = Offset(roomRect.left, roomRect.top + opOffsetPx);
        end = Offset(roomRect.left, start.dy + opLengthPx);
        break;
    }

    // Clear the wall stroke in the opening gap
    final clearRect = Rect.fromPoints(start, end).inflate(8.0);
    canvas.drawRect(clearRect, bgPaint);

    if (op.type == OpeningType.door) {
      // Draw Door Swing Arc & Leaf
      final doorPaint = Paint()
        ..color = const Color(0xFFF59E0B)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final arcPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      if (op.wallIndex == 2) {
        // Bottom wall door swinging inward-up
        canvas.drawLine(start, Offset(start.dx, start.dy - opLengthPx), doorPaint);
        final arcRect = Rect.fromCircle(center: start, radius: opLengthPx);
        canvas.drawArc(arcRect, -math.pi / 2, -math.pi / 2, false, arcPaint);
      } else {
        canvas.drawLine(start, end, doorPaint);
      }
    } else {
      // Window / Ventilator: Double parallel lines with glass tint
      final winPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.0;

      final glassFill = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRect(clearRect, glassFill);
      canvas.drawLine(start, end, winPaint);
      
      // Secondary glass line
      if (op.wallIndex == 0 || op.wallIndex == 2) {
        canvas.drawLine(
          Offset(start.dx, start.dy - 3),
          Offset(end.dx, end.dy - 3),
          winPaint..strokeWidth = 1.0,
        );
      }
    }
  }

  void _drawFurnitureItem2D(Canvas canvas, Rect roomRect, RoomItem item) {
    final itemXPx = roomRect.left + (item.x * scale);
    final itemYPx = roomRect.top + (item.y * scale);
    final itemWPx = item.width * scale;
    final itemDPx = item.depth * scale;
    final itemRect = Rect.fromLTWH(itemXPx, itemYPx, itemWPx, itemDPx);

    // 1. Draw Clearance Zone (Buffer box)
    if (showClearances) {
      final clearancePaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final clearanceBorder = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final bufferRect = Rect.fromLTWH(
        itemXPx - (item.clearanceSides * scale),
        itemYPx,
        itemWPx + (2 * item.clearanceSides * scale),
        itemDPx + (item.clearanceFront * scale),
      );
      canvas.drawRRect(RRect.fromRectAndRadius(bufferRect, const Radius.circular(4)), clearancePaint);
      canvas.drawRRect(RRect.fromRectAndRadius(bufferRect, const Radius.circular(4)), clearanceBorder);
    }

    // 2. Draw Furniture Body
    final bodyPaint = Paint()
      ..color = item.primaryColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDarkMode ? Colors.white70 : Colors.black87
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(itemRect, const Radius.circular(3));
    canvas.drawRRect(rrect, bodyPaint);
    canvas.drawRRect(rrect, borderPaint);

    // 3. Category Specific CAD Details
    _drawItemSpecifics(canvas, itemRect, item);

    // 4. Label & Dimensions
    _drawItemLabel(canvas, itemRect, item);
  }

  void _drawItemSpecifics(Canvas canvas, Rect rect, RoomItem item) {
    final detailPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    switch (item.category) {
      case ItemCategory.bed:
        // Headboard
        final hbRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.12);
        canvas.drawRect(hbRect, Paint()..color = Colors.black26);
        // Pillows
        final pillowW = rect.width * 0.38;
        final pillowH = rect.height * 0.22;
        final p1 = Rect.fromLTWH(rect.left + rect.width * 0.08, rect.top + rect.height * 0.15, pillowW, pillowH);
        final p2 = Rect.fromLTWH(rect.right - rect.width * 0.08 - pillowW, rect.top + rect.height * 0.15, pillowW, pillowH);
        canvas.drawRRect(RRect.fromRectAndRadius(p1, const Radius.circular(3)), Paint()..color = Colors.white70);
        canvas.drawRRect(RRect.fromRectAndRadius(p2, const Radius.circular(3)), Paint()..color = Colors.white70);
        // Blanket fold
        canvas.drawLine(
          Offset(rect.left + 4, rect.top + rect.height * 0.5),
          Offset(rect.right - 4, rect.top + rect.height * 0.5),
          detailPaint,
        );
        break;

      case ItemCategory.wardrobe:
        // Sliding rails & clothes hangers
        final halfW = rect.width / 2;
        canvas.drawLine(Offset(rect.left + halfW, rect.top), Offset(rect.left + halfW, rect.bottom), detailPaint);
        // Hanger diagonal lines
        for (double i = rect.left + 10; i < rect.right - 10; i += 18) {
          canvas.drawLine(Offset(i, rect.top + 4), Offset(i + 8, rect.bottom - 4), detailPaint..color = Colors.white24);
        }
        break;

      case ItemCategory.studyDesk:
        // Monitor & Laptop on desk
        final monRect = Rect.fromCenter(
          center: Offset(rect.center.dx, rect.top + rect.height * 0.3),
          width: rect.width * 0.45,
          height: 6,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(monRect, const Radius.circular(2)), Paint()..color = Colors.white);
        // Ergonomic Chair outline behind desk
        final chairCenter = Offset(rect.center.dx, rect.bottom + 16);
        canvas.drawCircle(chairCenter, 12, detailPaint..color = const Color(0xFF0EA5E9));
        break;

      case ItemCategory.showerArea:
        // Diagonal drain lines
        canvas.drawLine(rect.topLeft, rect.bottomRight, detailPaint..color = Colors.white24);
        canvas.drawLine(rect.topRight, rect.bottomLeft, detailPaint..color = Colors.white24);
        // Floor drain circle
        canvas.drawCircle(rect.center, 5, Paint()..color = Colors.white70);
        break;

      case ItemCategory.commode:
        // Cistern tank + Oval seat
        final tankRect = Rect.fromLTWH(rect.left, rect.top, rect.width, rect.height * 0.3);
        canvas.drawRect(tankRect, Paint()..color = Colors.white54);
        final bowlRect = Rect.fromLTWH(rect.left + 4, rect.top + rect.height * 0.25, rect.width - 8, rect.height * 0.7);
        canvas.drawOval(bowlRect, detailPaint..color = Colors.white);
        break;

      case ItemCategory.washBasin:
        // Oval basin inside counter
        final basinRect = Rect.fromCenter(center: rect.center, width: rect.width * 0.7, height: rect.height * 0.6);
        canvas.drawOval(basinRect, detailPaint..color = Colors.white);
        canvas.drawCircle(Offset(rect.center.dx, rect.top + 6), 3, Paint()..color = Colors.white); // Faucet
        break;

      case ItemCategory.gasHob:
        // 4 Burners
        final bRad = 6.0;
        canvas.drawCircle(Offset(rect.left + rect.width * 0.28, rect.top + rect.height * 0.35), bRad, Paint()..color = Colors.white70);
        canvas.drawCircle(Offset(rect.right - rect.width * 0.28, rect.top + rect.height * 0.35), bRad, Paint()..color = Colors.white70);
        canvas.drawCircle(Offset(rect.left + rect.width * 0.28, rect.bottom - rect.height * 0.35), bRad, Paint()..color = Colors.white70);
        canvas.drawCircle(Offset(rect.right - rect.width * 0.28, rect.bottom - rect.height * 0.35), bRad, Paint()..color = Colors.white70);
        break;

      case ItemCategory.kitchenSink:
        // Dual sink bowls
        final b1 = Rect.fromLTWH(rect.left + 4, rect.top + 4, rect.width * 0.42, rect.height - 8);
        final b2 = Rect.fromLTWH(rect.right - rect.width * 0.42 - 4, rect.top + 4, rect.width * 0.42, rect.height - 8);
        canvas.drawRRect(RRect.fromRectAndRadius(b1, const Radius.circular(3)), detailPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(b2, const Radius.circular(3)), detailPaint);
        break;

      case ItemCategory.acUnit:
        // Airflow fan lines
        for (double y = rect.bottom + 4; y < rect.bottom + 20; y += 5) {
          canvas.drawLine(
            Offset(rect.left + 8, y),
            Offset(rect.right - 8, y),
            detailPaint..color = const Color(0xFF06B6D4).withValues(alpha: 0.5),
          );
        }
        break;

      default:
        break;
    }
  }

  void _drawItemLabel(Canvas canvas, Rect rect, RoomItem item) {
    final textSpan = TextSpan(
      text: '${item.name}\n${item.width.toStringAsFixed(1)}m × ${item.depth.toStringAsFixed(1)}m',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: rect.width + 20);
    textPainter.paint(
      canvas,
      Offset(rect.center.dx - textPainter.width / 2, rect.center.dy - textPainter.height / 2),
    );
  }

  void _drawDimensionRulers(Canvas canvas, Rect roomRect) {
    final textStyle = TextStyle(
      color: isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      backgroundColor: isDarkMode ? const Color(0xFF0F172A) : Colors.white,
    );

    // Top Wall Dimension
    _drawDimensionLine(
      canvas,
      Offset(roomRect.left, roomRect.top - 24),
      Offset(roomRect.right, roomRect.top - 24),
      'Wall A: ${room.wallTop.toStringAsFixed(2)} m (${_metersToFtIn(room.wallTop)})',
      textStyle,
    );

    // Right Wall Dimension
    _drawDimensionLine(
      canvas,
      Offset(roomRect.right + 24, roomRect.top),
      Offset(roomRect.right + 24, roomRect.bottom),
      'Wall B: ${room.wallRight.toStringAsFixed(2)} m',
      textStyle,
      isVertical: true,
    );

    // Bottom Wall Dimension
    _drawDimensionLine(
      canvas,
      Offset(roomRect.left, roomRect.bottom + 24),
      Offset(roomRect.right, roomRect.bottom + 24),
      'Wall C: ${room.wallBottom.toStringAsFixed(2)} m',
      textStyle,
    );

    // Left Wall Dimension
    _drawDimensionLine(
      canvas,
      Offset(roomRect.left - 24, roomRect.top),
      Offset(roomRect.left - 24, roomRect.bottom),
      'Wall D: ${room.wallLeft.toStringAsFixed(2)} m',
      textStyle,
      isVertical: true,
    );
  }

  void _drawDimensionLine(
    Canvas canvas,
    Offset start,
    Offset end,
    String label,
    TextStyle style, {
    bool isVertical = false,
  }) {
    final linePaint = Paint()
      ..color = isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)
      ..strokeWidth = 1.2;

    canvas.drawLine(start, end, linePaint);

    // End ticks
    if (isVertical) {
      canvas.drawLine(Offset(start.dx - 4, start.dy), Offset(start.dx + 4, start.dy), linePaint);
      canvas.drawLine(Offset(end.dx - 4, end.dy), Offset(end.dx + 4, end.dy), linePaint);
    } else {
      canvas.drawLine(Offset(start.dx, start.dy - 4), Offset(start.dx, start.dy + 4), linePaint);
      canvas.drawLine(Offset(end.dx, end.dy - 4), Offset(end.dx, end.dy + 4), linePaint);
    }

    final textSpan = TextSpan(text: ' $label ', style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    textPainter.paint(
      canvas,
      Offset(mid.dx - textPainter.width / 2, mid.dy - textPainter.height / 2),
    );
  }

  void _drawNorthCompass(Canvas canvas, Size size) {
    final compassCenter = Offset(size.width - 45, 45);
    final compassPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    // North triangle
    final pathNorth = Path()
      ..moveTo(compassCenter.dx, compassCenter.dy - 18)
      ..lineTo(compassCenter.dx - 6, compassCenter.dy)
      ..lineTo(compassCenter.dx + 6, compassCenter.dy)
      ..close();
    canvas.drawPath(pathNorth, compassPaint);

    // South triangle
    final pathSouth = Path()
      ..moveTo(compassCenter.dx, compassCenter.dy + 18)
      ..lineTo(compassCenter.dx - 6, compassCenter.dy)
      ..lineTo(compassCenter.dx + 6, compassCenter.dy)
      ..close();
    canvas.drawPath(pathSouth, Paint()..color = Colors.grey);

    final textSpan = const TextSpan(
      text: 'N',
      style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, Offset(compassCenter.dx - textPainter.width / 2, compassCenter.dy - 30));
  }

  String _metersToFtIn(double meters) {
    final totalInches = (meters * 39.3701).round();
    final ft = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$ft'$inches\"";
  }

  @override
  bool shouldRepaint(covariant Blueprint2DPainter oldDelegate) {
    return oldDelegate.room != room ||
        oldDelegate.showDimensions != showDimensions ||
        oldDelegate.showClearances != showClearances ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.scale != scale ||
        oldDelegate.isDarkMode != isDarkMode;
  }
}
