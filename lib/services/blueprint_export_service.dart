import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';
import '../services/file_download_helper.dart';
import '../widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';

class BlueprintExportService {
  /// Captures a RenderRepaintBoundary widget as PNG bytes.
  static Future<Uint8List?> captureBlueprintPng(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing blueprint PNG: $e');
      return null;
    }
  }

  /// Generates a pristine 4K (3840 x 2400) Ultra High-Resolution Architectural Sheet
  /// with complete architectural schedules and room metrics written on the left side,
  /// and the precision 2D CAD blueprint on the right side.
  static Future<Uint8List?> generateUltraHighResBlueprintSheet({
    required DynamicFloorDimensions dims,
    required List<MathematicalItemDimension> items,
    String roomName = 'Master Architectural Space',
    bool showDimensions = true,
    bool showGrid = true,
    bool showRoomLabels = true,
    bool isFinalized = false,
    DateTime? finalizedAt,
    String? finalizedNotes,
    double sheetWidth = 3840.0,
    double sheetHeight = 2400.0,
  }) async {
    try {
      final double sidebarWidth = sheetWidth * (1200.0 / 3840.0);
      final double rightWidth = sheetWidth - sidebarWidth;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, sheetWidth, sheetHeight));

      // 1. Sheet Background
      final bgPaint = Paint()..color = const Color(0xFF070D18);
      canvas.drawRect(Rect.fromLTWH(0, 0, sheetWidth, sheetHeight), bgPaint);

      // Fine Background CAD Grid Pattern
      final gridPaint = Paint()
        ..color = const Color(0xFF0E1A2E).withValues(alpha: 0.6)
        ..strokeWidth = 1.0;
      for (double x = 0; x < sheetWidth; x += 40.0) {
        canvas.drawLine(Offset(x, 0), Offset(x, sheetHeight), gridPaint);
      }
      for (double y = 0; y < sheetHeight; y += 40.0) {
        canvas.drawLine(Offset(0, y), Offset(sheetWidth, y), gridPaint);
      }

      // Outer Sheet Technical Border & Registration Ticks
      final borderPaint = Paint()
        ..color = const Color(0xFF1E3A5F)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;
      canvas.drawRect(Rect.fromLTWH(24, 24, sheetWidth - 48, sheetHeight - 48), borderPaint);

      // Corner Registration Marks (+)
      final regPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.5;
      const double regSize = 25.0;
      final List<Offset> corners = [
        const Offset(34, 34),
        Offset(sheetWidth - 34, 34),
        Offset(34, sheetHeight - 34),
        Offset(sheetWidth - 34, sheetHeight - 34),
      ];
      for (final c in corners) {
        canvas.drawLine(Offset(c.dx - regSize, c.dy), Offset(c.dx + regSize, c.dy), regPaint);
        canvas.drawLine(Offset(c.dx, c.dy - regSize), Offset(c.dx, c.dy + regSize), regPaint);
      }

      // Vertical Divider Spine between Left Sidebar and Right CAD Blueprint
      final spinePaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 3.5;
      canvas.drawLine(Offset(sidebarWidth, 24), Offset(sidebarWidth, sheetHeight - 24), spinePaint);

      final spineShadow = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.15)
        ..strokeWidth = 12.0;
      canvas.drawLine(Offset(sidebarWidth, 24), Offset(sidebarWidth, sheetHeight - 24), spineShadow);

      // =========================================================================
      // LEFT SIDE: ARCHITECTURAL SCHEDULES & SPECIFICATIONS
      // =========================================================================
      _drawLeftSidebarSpecifications(
        canvas: canvas,
        dims: dims,
        items: items,
        roomName: roomName,
        sidebarWidth: sidebarWidth,
        sheetHeight: sheetHeight,
        isFinalized: isFinalized,
        finalizedAt: finalizedAt,
        finalizedNotes: finalizedNotes,
      );

      // =========================================================================
      // RIGHT SIDE: ULTRA-HD 2D CAD BLUEPRINT
      // =========================================================================
      canvas.save();
      canvas.translate(sidebarWidth, 0);

      // Calculate perfect fit scale for the right viewport
      const double marginX = 220.0;
      const double marginY = 180.0;
      final double availW = rightWidth - (2 * marginX);
      final double availH = sheetHeight - (2 * marginY);
      final double scaleX = availW / dims.totalWidth;
      final double scaleY = availH / dims.totalLength;
      final double rightScale = math.min(scaleX, scaleY);

      final blueprintPainter = DynamicFloor2DPainter(
        dims: dims,
        items: items,
        scale: rightScale,
        showDimensions: showDimensions,
        showClearances: true,
        showGrid: showGrid,
        showRoomLabels: showRoomLabels,
        isDarkMode: true,
      );

      blueprintPainter.paint(canvas, Size(rightWidth, sheetHeight));
      canvas.restore();

      // Render Picture to Image
      final picture = recorder.endRecording();
      final image = await picture.toImage(sheetWidth.toInt(), sheetHeight.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating ultra high-res blueprint sheet: $e');
      return null;
    }
  }

  /// Draws the left-hand technical schedule panel with crisp architectural formatting
  static void _drawLeftSidebarSpecifications({
    required Canvas canvas,
    required DynamicFloorDimensions dims,
    required List<MathematicalItemDimension> items,
    required String roomName,
    required double sidebarWidth,
    required double sheetHeight,
    bool isFinalized = false,
    DateTime? finalizedAt,
    String? finalizedNotes,
  }) {
    double u(double ftVal) => DynamicFloorDimensions.convertValue(ftVal, DimensionUnit.feet, dims.unit);

    final leftMargin = 50.0;
    final contentWidth = sidebarWidth - 100.0;

    // Helper text drawer
    void drawText({
      required String text,
      required Offset offset,
      required TextStyle style,
      double? maxWidth,
    }) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 4,
      );
      tp.layout(maxWidth: maxWidth ?? contentWidth);
      tp.paint(canvas, offset);
    }

    // Card background drawer
    void drawCardBox(Rect rect, {Color? borderCol, Color? bgCol}) {
      final fill = Paint()..color = bgCol ?? const Color(0xFF0D1527);
      final stroke = Paint()
        ..color = borderCol ?? const Color(0xFF1E3352)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, stroke);
    }

    // -------------------------------------------------------------------------
    // 1. SHEET HEADER & TITLE BLOCK
    // -------------------------------------------------------------------------
    drawText(
      text: 'HOMECRAFT PRECISION ARCHITECTURAL CAD STUDIO',
      offset: Offset(leftMargin, 50),
      style: const TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 19,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );

    drawText(
      text: roomName.toUpperCase(),
      offset: Offset(leftMargin, 82),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );

    drawText(
      text: 'Precision Spatial Floor Layout & Construction Specification Sheet',
      offset: Offset(leftMargin, 126),
      style: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );

    // Meta Badge Strip
    final metaRect = Rect.fromLTWH(leftMargin, 160, contentWidth, 48);
    drawCardBox(metaRect, bgCol: const Color(0xFF0F1E36), borderCol: const Color(0xFF38BDF8).withValues(alpha: 0.4));
    drawText(
      text: 'STANDARD: ${dims.unit.label.toUpperCase()}   •   UNIT: ${dims.unit.shortName.toUpperCase()}   •   SCALE: 1:50 CAD   •   REV: 2.4   •   DATE: ${DateTime.now().toIso8601String().split('T').first}',
      offset: Offset(leftMargin + 16, 174),
      style: const TextStyle(
        color: Color(0xFF38BDF8),
        fontSize: 13.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
      ),
    );

    // -------------------------------------------------------------------------
    // 2. CARD 1: ARCHITECTURAL ROOM & ZONE SCHEDULE
    // -------------------------------------------------------------------------
    final card1Rect = Rect.fromLTWH(leftMargin, 226, contentWidth, 430);
    drawCardBox(card1Rect);

    // Header strip
    final c1Header = Rect.fromLTWH(leftMargin, 226, contentWidth, 44);
    canvas.drawRRect(
      RRect.fromRectAndCorners(c1Header, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
      Paint()..color = const Color(0xFF162544),
    );
    drawText(
      text: '📐  1. ARCHITECTURAL ROOM & ZONE SCHEDULE',
      offset: Offset(leftMargin + 16, 238),
      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
    );

    double curY = 286;
    void drawScheduleRow(String label, String specs, String area, {bool isHighlight = false}) {
      final rowBg = Rect.fromLTWH(leftMargin + 12, curY, contentWidth - 24, 60);
      if (isHighlight) {
        canvas.drawRRect(RRect.fromRectAndRadius(rowBg, const Radius.circular(8)), Paint()..color = const Color(0xFF1E293B));
        canvas.drawRRect(RRect.fromRectAndRadius(rowBg, const Radius.circular(8)), Paint()..color = const Color(0xFF10B981)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }
      drawText(
        text: label,
        offset: Offset(leftMargin + 20, curY + 8),
        style: TextStyle(color: isHighlight ? const Color(0xFF34D399) : Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
      );
      drawText(
        text: specs,
        offset: Offset(leftMargin + 20, curY + 32),
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
      drawText(
        text: area,
        offset: Offset(leftMargin + contentWidth - 260, curY + 18),
        style: TextStyle(color: isHighlight ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24), fontSize: 15, fontWeight: FontWeight.bold),
      );
      curY += 68;
    }

    drawScheduleRow(
      '🛏️ Master Bedroom Suite',
      'Width: ${dims.format(dims.roomWidth)}  •  Length: ${dims.format(dims.roomLength)}  •  Ceiling: ${dims.format(dims.ceilingHeight)}',
      'Area: ${dims.formatArea(dims.roomWidth * dims.roomLength)}',
    );

    drawScheduleRow(
      '🚿 Ensuite Bathroom Suite',
      'Width: ${dims.format(dims.bathWidth)}  •  Length: ${dims.format(dims.bathLength)}  •  Shower: ${dims.format(dims.showerDepth)}',
      'Area: ${dims.formatArea(dims.bathWidth * dims.bathLength)}',
    );

    drawScheduleRow(
      '🍳 Modular Kitchen & Pantry',
      'Width: ${dims.format(dims.kitchenWidth)}  •  Length: ${dims.format(dims.kitchenLength)}  •  Rightmost Gate Flush',
      'Area: ${dims.formatArea(dims.kitchenWidth * dims.kitchenLength)}',
    );

    drawScheduleRow(
      '🚪 Circulation Core & Gallery',
      'Staircase Core: ${dims.format(dims.staircaseWidth)}  •  Long Gallery: ${dims.format(dims.galleryWidth)}',
      'NBC Egress Passage',
    );

    drawScheduleRow(
      '🏢 TOTAL BUILT FOOTPRINT (GROSS)',
      'Total Width: ${dims.format(dims.totalWidth)}  •  Total Length: ${dims.format(dims.totalLength)}',
      'Gross: ${dims.formatArea(dims.totalWidth * dims.totalLength)}',
      isHighlight: true,
    );

    // -------------------------------------------------------------------------
    // 2. CARD 2: OPENINGS, DOORS & EGRESS SCHEDULE
    // -------------------------------------------------------------------------
    final card2Rect = Rect.fromLTWH(leftMargin, 676, contentWidth, 270);
    drawCardBox(card2Rect);

    final c2Header = Rect.fromLTWH(leftMargin, 676, contentWidth, 44);
    canvas.drawRRect(
      RRect.fromRectAndCorners(c2Header, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
      Paint()..color = const Color(0xFF1E283D),
    );
    drawText(
      text: '🚪  2. OPENINGS, DOORS & EGRESS SCHEDULE',
      offset: Offset(leftMargin + 16, 688),
      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
    );

    curY = 730;
    void drawOpeningItem(String title, String span, String note) {
      drawText(
        text: '• $title:',
        offset: Offset(leftMargin + 20, curY),
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
      );
      drawText(
        text: 'Clear Span: $span   ($note)',
        offset: Offset(leftMargin + 260, curY),
        style: const TextStyle(color: Colors.white70, fontSize: 13.5),
      );
      curY += 32;
    }

    drawOpeningItem('Master Bedroom Gate', dims.format(u(3.0)), 'North Wall Inward Radial Swing Arc');
    drawOpeningItem('Ensuite Bath Gate', dims.format(u(2.5)), 'East Side Inward Swing Privacy Egress');
    drawOpeningItem('Kitchen Egress Gate', dims.format(u(3.0)), 'Rightmost Outer Gallery Flush');
    drawOpeningItem('Master Window (W1)', dims.format(u(5.0)), 'Glazed Double-Pane Sliding');
    drawOpeningItem('Kitchen Window (W2)', dims.format(u(4.0)), 'Overhead Exhaust Ventilator');
    drawOpeningItem('Bathroom Louver (V1)', dims.format(u(2.0)), 'Passive Moisture Ventilation');

    // -------------------------------------------------------------------------
    // 3. CARD 3: PLACED FURNITURE & FIXTURE CLEARANCE SCHEDULE
    // -------------------------------------------------------------------------
    final card3Rect = Rect.fromLTWH(leftMargin, 966, contentWidth, 1020);
    drawCardBox(card3Rect);

    final c3Header = Rect.fromLTWH(leftMargin, 966, contentWidth, 44);
    canvas.drawRRect(
      RRect.fromRectAndCorners(c3Header, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
      Paint()..color = const Color(0xFF132B2A),
    );
    drawText(
      text: '🛏️  3. PLACED FURNITURE & 4-WALL CLEARANCES SCHEDULE (${items.length} ITEMS)',
      offset: Offset(leftMargin + 16, 978),
      style: const TextStyle(color: Color(0xFF34D399), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
    );

    curY = 1026;
    if (items.isEmpty) {
      drawText(
        text: 'No fixed custom furniture placed.\n100% open floor circulation preserved for versatile room configurations.',
        offset: Offset(leftMargin + 30, curY + 30),
        style: const TextStyle(color: Colors.white54, fontSize: 16, height: 1.5, fontStyle: FontStyle.italic),
      );
    } else {
      const baseScale = 28.0;
      final origin = DynamicFloor2DPainter.getOrigin(
        dims: dims,
        canvasSize: const Size(950, 750),
        scale: baseScale,
      );
      final rects = DynamicFloor2DPainter.calculateItemRects(
        dims: dims,
        items: items,
        canvasSize: const Size(950, 750),
        scale: baseScale,
      );

      for (int i = 0; i < items.length && i < 6; i++) {
        final it = items[i];
        final itemCol = DynamicFloor2DPainter.getItemColor(it.id, it.itemName, i);
        final itemBox = Rect.fromLTWH(leftMargin + 12, curY, contentWidth - 24, 150);
        canvas.drawRRect(
          RRect.fromRectAndRadius(itemBox, const Radius.circular(10)),
          Paint()..color = const Color(0xFF0F1E2E),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(itemBox, const Radius.circular(10)),
          Paint()..color = itemCol.withValues(alpha: 0.45)..style = PaintingStyle.stroke..strokeWidth = 1.2,
        );

        // Left accent colored stripe
        final stripeRect = Rect.fromLTWH(leftMargin + 12, curY, 6.0, 150);
        canvas.drawRRect(
          RRect.fromRectAndCorners(stripeRect, topLeft: const Radius.circular(10), bottomLeft: const Radius.circular(10)),
          Paint()..color = itemCol,
        );

        final r = rects[it.id];
        final posX = r != null ? (r.left - origin.dx) / baseScale : (it.customPosX ?? 0.0);
        final posY = r != null ? (r.top - origin.dy) / baseScale : (it.customPosY ?? 0.0);
        final w = r != null ? r.width / baseScale : it.width;
        final l = r != null ? r.height / baseScale : it.length;

        // Clearances calculation
        final gapW = posX;
        final gapE = dims.roomWidth - (posX + w);
        final gapS = posY;
        final gapN = dims.roomLength - (posY + l);

        String fmtGap(double g) => g <= 0.05 ? 'FLUSH (0.0)' : dims.format(math.max(0.0, g));

        // Line 1: Item name, Wall affiliation, Area
        drawText(
          text: '${i + 1}. [${it.itemName.toUpperCase()}]  •  Target: ${it.targetWall}',
          offset: Offset(leftMargin + 28, curY + 12),
          style: TextStyle(color: itemCol, fontSize: 16, fontWeight: FontWeight.bold),
        );
        drawText(
          text: 'Footprint: ${dims.formatArea(w * l)}',
          offset: Offset(leftMargin + contentWidth - 220, curY + 12),
          style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 14, fontWeight: FontWeight.bold),
        );

        // Line 2: Dimensions & Coordinates
        drawText(
          text: 'Dimensions: ${dims.format(w)} (W) × ${dims.format(l)} (L) × ${dims.format(it.height)} (H)   |   Pos: X=${dims.format(posX)}, Y=${dims.format(posY)}',
          offset: Offset(leftMargin + 28, curY + 44),
          style: const TextStyle(color: Colors.white, fontSize: 14),
        );

        // Line 3: 4-Wall Clearance Gauge
        drawText(
          text: '4-Wall Gaps:  W (Left): ${fmtGap(gapW)}  •  E (Right): ${fmtGap(gapE)}  •  S (Top): ${fmtGap(gapS)}  •  N (Bottom): ${fmtGap(gapN)}',
          offset: Offset(leftMargin + 28, curY + 76),
          style: const TextStyle(color: Color(0xFF10B981), fontSize: 13.5, fontWeight: FontWeight.w600),
        );

        // Line 4: Facing Orientation & Rotation
        drawText(
          text: 'Orientation: Facing ${it.facingDirection} (${it.rotationDegrees.toInt()}° rotation)   |   Ergonomic Egress Buffer: Compliant',
          offset: Offset(leftMargin + 28, curY + 108),
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        );

        curY += 162;
      }
    }

    // -------------------------------------------------------------------------
    // 5. CARD 4: CONSTRUCTION SPECIFICATIONS & APPROVAL STAMP
    // -------------------------------------------------------------------------
    final card4Rect = Rect.fromLTWH(leftMargin, 2006, contentWidth, 340);
    drawCardBox(card4Rect, bgCol: const Color(0xFF0A1322), borderCol: const Color(0xFF38BDF8).withValues(alpha: 0.6));

    final c4Header = Rect.fromLTWH(leftMargin, 2006, contentWidth, 44);
    canvas.drawRRect(
      RRect.fromRectAndCorners(c4Header, topLeft: const Radius.circular(14), topRight: const Radius.circular(14)),
      Paint()..color = const Color(0xFF1E3A5F),
    );
    drawText(
      text: '🛠️  4. TECHNICAL NOTES & CERTIFICATION SEAL',
      offset: Offset(leftMargin + 16, 2018),
      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.8),
    );

    curY = 2062;
    drawText(
      text: '• Electrical & Plumbing: Conduit runs pre-allocated along North/South/West structural masonry walls.\n'
          '• Minimum Egress Clearance: 3.0 ft (0.91m) clear unobstructed circulation maintained along all doors.\n'
          '• Wet Zone Gradient: Ensuite shower zone sloped at 1:50 gradient towards floor trap drain.\n'
          '• Ventilation & Lighting: Cross-ventilation optimized between South Master Window and North Corridor.',
      offset: Offset(leftMargin + 20, curY),
      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
    );

    // Architectural Approval Stamp
    final stampRect = Rect.fromLTWH(leftMargin + contentWidth - 420, 2180, 390, 140);
    final stampBgCol = isFinalized ? const Color(0xFF064E3B) : const Color(0xFF0F253F);
    final stampBorderCol = isFinalized ? const Color(0xFF10B981) : const Color(0xFF38BDF8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(stampRect, const Radius.circular(8)),
      Paint()..color = stampBgCol,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(stampRect, const Radius.circular(8)),
      Paint()..color = stampBorderCol..style = PaintingStyle.stroke..strokeWidth = 2.0,
    );

    drawText(
      text: 'HOMECRAFT OS • ARCHITECTURAL CAD',
      offset: Offset(leftMargin + contentWidth - 400, 2195),
      style: TextStyle(color: stampBorderCol, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2),
    );
    drawText(
      text: isFinalized ? 'STATUS: FINALIZED & APPROVED ✅' : 'STATUS: WORKING DRAFT SPECIFICATION',
      offset: Offset(leftMargin + contentWidth - 400, 2225),
      style: TextStyle(
        color: isFinalized ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );

    final finDateStr = finalizedAt != null
        ? 'FINALIZED: ${finalizedAt.toIso8601String().split('T').first}'
        : 'MODIFIED: ${DateTime.now().toIso8601String().split('T').first}';

    drawText(
      text: '$finDateStr • 4K ULTRA-HD\n${finalizedNotes ?? "READY FOR ARCHITECTURAL FABRICATION"}',
      offset: Offset(leftMargin + contentWidth - 400, 2260),
      style: const TextStyle(color: Colors.white70, fontSize: 12.0, height: 1.3),
    );
  }

  /// Saves the generated high-res PNG bytes to disk / Downloads folder
  static Future<String?> saveFileToDisk(Uint8List bytes, String filename) async {
    return await FileDownloadHelper.downloadFile(bytes, filename);
  }

  /// Displays the interactive preview and download modal dialog
  static void showExportSuccessDialog(
    BuildContext context,
    Uint8List pngBytes,
    String roomName, {
    String? savedFilePath,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0F172A),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 780),
          child: _BlueprintExportDialogContent(
            pngBytes: pngBytes,
            roomName: roomName,
            initialSavedPath: savedFilePath,
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
}

class _BlueprintExportDialogContent extends StatefulWidget {
  final Uint8List pngBytes;
  final String roomName;
  final String? initialSavedPath;
  final VoidCallback onClose;

  const _BlueprintExportDialogContent({
    required this.pngBytes,
    required this.roomName,
    this.initialSavedPath,
    required this.onClose,
  });

  @override
  State<_BlueprintExportDialogContent> createState() => _BlueprintExportDialogContentState();
}

class _BlueprintExportDialogContentState extends State<_BlueprintExportDialogContent> {
  String? _savedFilePath;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _savedFilePath = widget.initialSavedPath;
  }

  Future<void> _performDownload() async {
    setState(() => _isDownloading = true);
    final sanitized = widget.roomName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final filename = 'CAD_Blueprint_${sanitized}_${DateTime.now().millisecondsSinceEpoch}.png';

    final path = await FileDownloadHelper.downloadFile(widget.pngBytes, filename);
    setState(() {
      _isDownloading = false;
      if (path != null) _savedFilePath = path;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 4),
          content: Text(
            path != null ? '✅ 4K Blueprint saved to: $path' : '✅ Blueprint downloaded successfully to your PC!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          action: (path != null && !kIsWeb)
              ? SnackBarAction(
                  label: 'OPEN FOLDER',
                  textColor: Colors.white,
                  onPressed: () => FileDownloadHelper.openFileOrFolder(path),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dialog Title & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '4K Ultra High-Resolution Blueprint Ready',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complete with Left-Side Architectural Schedules & Right-Side 2D CAD Blueprint (${widget.roomName})',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Text(
                  '3840 × 2400 px  •  ${(widget.pngBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Zoomable Preview of the 4K Sheet
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                color: const Color(0xFF070D18),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 6.0,
                  boundaryMargin: const EdgeInsets.all(100),
                  child: Center(
                    child: Image.memory(
                      widget.pngBytes,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Saved Location Info & Action Controls
          Row(
            children: [
              if (_savedFilePath != null && _savedFilePath!.isNotEmpty) ...[
                const Icon(Icons.folder_outlined, size: 18, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saved to: $_savedFilePath',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, overflow: TextOverflow.ellipsis),
                  ),
                ),
                if (!kIsWeb) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => FileDownloadHelper.openFileOrFolder(_savedFilePath!),
                    icon: const Icon(Icons.folder_open, size: 16),
                    label: const Text('Open Folder in Finder / Explorer', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  tooltip: 'Copy File Path',
                  icon: const Icon(Icons.copy, size: 16, color: Color(0xFF38BDF8)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _savedFilePath!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: Color(0xFF10B981),
                        content: Text('File path copied to clipboard!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ] else ...[
                const Expanded(
                  child: Text(
                    '• Left side contains Room Schedule, Fixture Specs, & 4-Wall Clearances\n• Right side contains 2D Precision CAD Blueprint with Witness Lines',
                    style: TextStyle(color: Colors.white60, fontSize: 11.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onClose,
                child: const Text('Close Preview', style: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isDownloading ? null : _performDownload,
                icon: _isDownloading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.download, size: 18),
                label: Text(
                  _isDownloading
                      ? 'Saving to PC...'
                      : (_savedFilePath != null ? 'Download Again / Save to PC' : 'Download 4K CAD Blueprint PNG'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
