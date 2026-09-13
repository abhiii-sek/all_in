import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/dynamic_floor_model.dart';
import '../models/cad_hover_detail.dart';
import '../services/architectural_prompt_service.dart';
import '../widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';

class CadHoverHitTestService {
  static CadHoverDetail? hitTest({
    required Offset localPos,
    required DynamicFloorDimensions dims,
    required List<MathematicalItemDimension> items,
    required String? selectedItemId,
    required Size canvasSize,
    required double scale,
  }) {
    final origin = DynamicFloor2DPainter.getOrigin(dims: dims, canvasSize: canvasSize, scale: scale);
    final rwPx = dims.roomWidth * scale;
    final rlPx = dims.roomLength * scale;
    final twPx = dims.totalWidth * scale;
    final tlPx = dims.totalLength * scale;
    final bwPx = dims.bathWidth * scale;
    final blPx = dims.bathLength * scale;
    final kwPx = dims.kitchenWidth * scale;
    final klPx = dims.kitchenLength * scale;
    final galXPx = origin.dx + twPx - (dims.galleryWidth * scale);
    final stairW = (origin.dx + twPx - (dims.galleryWidth * scale)) - (origin.dx + rwPx);

    final rectMap = DynamicFloor2DPainter.calculateItemRects(
      dims: dims,
      items: items,
      canvasSize: canvasSize,
      scale: scale,
    );

    // 1. Check Selected Item Handles (Topmost priority)
    if (selectedItemId != null && rectMap.containsKey(selectedItemId)) {
      final sRect = rectMap[selectedItemId]!;
      final sItem = items.firstWhere((it) => it.id == selectedItemId, orElse: () => items.first);

      // Rotate handle
      final rotatePos = Offset(sRect.center.dx, sRect.top - 16.0);
      if ((localPos - rotatePos).distance <= 12.0) {
        return CadHoverDetail(
          title: 'Rotate 90° Clockwise',
          subtitle: 'Currently facing ${sItem.facingDirection} (${sItem.rotationDegrees}°)',
          category: 'CONTROL HANDLE',
          icon: Icons.rotate_right,
          accentColor: const Color(0xFFF59E0B),
          keyMetrics: {
            'Current Angle': '${sItem.rotationDegrees}°',
            'Target Wall': sItem.targetWall,
          },
          interactionTip: '💡 Click to rotate item 90° clockwise instantaneously.',
          targetRect: Rect.fromCircle(center: rotatePos, radius: 10.0),
          pointerPosition: localPos,
        );
      }

      // Edge Stretch Handles
      final rightPill = Rect.fromCenter(center: sRect.centerRight, width: 14.0, height: 26.0);
      if (rightPill.contains(localPos)) {
        return CadHoverDetail(
          title: 'East Breadth Stretch Handle (↔)',
          subtitle: 'Stretches item width towards East (Right)',
          category: 'CONTROL HANDLE',
          icon: Icons.unfold_more,
          accentColor: const Color(0xFF38BDF8),
          keyMetrics: {
            'Breadth (X-Span)': dims.format(sItem.width),
            'Length (Y-Span)': dims.format(sItem.length),
          },
          interactionTip: '💡 Drag horizontally to stretch width freely without size limits.',
          targetRect: rightPill,
          pointerPosition: localPos,
        );
      }

      final leftPill = Rect.fromCenter(center: sRect.centerLeft, width: 14.0, height: 26.0);
      if (leftPill.contains(localPos)) {
        return CadHoverDetail(
          title: 'West Breadth Stretch Handle (↔)',
          subtitle: 'Stretches item width towards West (Left)',
          category: 'CONTROL HANDLE',
          icon: Icons.unfold_more,
          accentColor: const Color(0xFF38BDF8),
          keyMetrics: {
            'Breadth (X-Span)': dims.format(sItem.width),
            'Length (Y-Span)': dims.format(sItem.length),
          },
          interactionTip: '💡 Drag leftwards to expand width while anchoring the right side.',
          targetRect: leftPill,
          pointerPosition: localPos,
        );
      }

      final topPill = Rect.fromCenter(center: sRect.topCenter, width: 26.0, height: 14.0);
      if (topPill.contains(localPos)) {
        return CadHoverDetail(
          title: 'South Length Stretch Handle (↕)',
          subtitle: 'Stretches item length upwards towards South',
          category: 'CONTROL HANDLE',
          icon: Icons.unfold_more,
          accentColor: const Color(0xFF38BDF8),
          keyMetrics: {
            'Length (Y-Span)': dims.format(sItem.length),
            'Breadth (X-Span)': dims.format(sItem.width),
          },
          interactionTip: '💡 Drag upwards to expand length while anchoring the bottom edge.',
          targetRect: topPill,
          pointerPosition: localPos,
        );
      }

      final bottomPill = Rect.fromCenter(center: sRect.bottomCenter, width: 26.0, height: 14.0);
      if (bottomPill.contains(localPos)) {
        return CadHoverDetail(
          title: 'North Length Stretch Handle (↕)',
          subtitle: 'Stretches item length downwards towards North',
          category: 'CONTROL HANDLE',
          icon: Icons.unfold_more,
          accentColor: const Color(0xFF38BDF8),
          keyMetrics: {
            'Length (Y-Span)': dims.format(sItem.length),
            'Breadth (X-Span)': dims.format(sItem.width),
          },
          interactionTip: '💡 Drag downwards to expand length towards the entry wall.',
          targetRect: bottomPill,
          pointerPosition: localPos,
        );
      }

      // Corner handles
      final corners = {
        'Top-Left Corner Resize (↖)': sRect.topLeft,
        'Top-Right Corner Resize (↗)': sRect.topRight,
        'Bottom-Left Corner Resize (↙)': sRect.bottomLeft,
        'Bottom-Right Corner Resize (↘)': sRect.bottomRight,
      };
      for (final entry in corners.entries) {
        if ((localPos - entry.value).distance <= 10.0) {
          return CadHoverDetail(
            title: entry.key,
            subtitle: 'Diagonal 2D continuous resizing',
            category: 'CONTROL HANDLE',
            icon: Icons.aspect_ratio,
            accentColor: const Color(0xFF38BDF8),
            keyMetrics: {
              'Width': dims.format(sItem.width),
              'Length': dims.format(sItem.length),
            },
            interactionTip: '💡 Drag diagonally to scale both width and length simultaneously.',
            targetRect: Rect.fromCenter(center: entry.value, width: 14, height: 14),
            pointerPosition: localPos,
          );
        }
      }
    }

    // 2. Check Placed Furniture Items
    for (int i = items.length - 1; i >= 0; i--) {
      final item = items[i];
      final rect = rectMap[item.id];
      if (rect != null && rect.contains(localPos)) {
        final posX = item.customPosX ?? ((rect.left - origin.dx) / scale);
        final posY = item.customPosY ?? ((rect.top - origin.dy) / scale);

        final gapWest = posX;
        final gapEast = (dims.roomWidth - (posX + item.width)).clamp(0.0, dims.roomWidth);
        final gapSouth = posY;
        final gapNorth = (dims.roomLength - (posY + item.length)).clamp(0.0, dims.roomLength);

        final isBed = item.itemName.toLowerCase().contains('bed');
        final isWardrobe = item.itemName.toLowerCase().contains('wardrobe');
        final isDesk = item.itemName.toLowerCase().contains('study') || item.itemName.toLowerCase().contains('desk');

        IconData icon = Icons.chair;
        final Color accent = DynamicFloor2DPainter.getItemColor(item.id, item.itemName, i);
        if (isBed) {
          icon = Icons.bed;
        } else if (isWardrobe) {
          icon = Icons.door_sliding;
        } else if (isDesk) {
          icon = Icons.desk;
        }

        final area = item.width * item.length;

        return CadHoverDetail(
          title: item.itemName,
          subtitle: 'Master Suite Furniture • ${item.targetWall}',
          category: 'FURNITURE ITEM',
          icon: icon,
          accentColor: accent,
          keyMetrics: {
            'Width (W-E)': dims.format(item.width),
            'Length (S-N)': dims.format(item.length),
            'Height': dims.format(item.height),
            'Footprint Area': dims.formatArea(area),
          },
          wallClearances: {
            'West (Left)': gapWest < 0.05 ? 'FLUSH' : dims.format(gapWest),
            'East (Right)': gapEast < 0.05 ? 'FLUSH' : dims.format(gapEast),
            'South (Top)': gapSouth < 0.05 ? 'FLUSH' : dims.format(gapSouth),
            'North (Bottom)': gapNorth < 0.05 ? 'FLUSH' : dims.format(gapNorth),
          },
          position: 'X: ${dims.format(posX)}, Y: ${dims.format(posY)}',
          orientation: '${item.facingDirection} (${item.rotationDegrees}°)',
          engineeringReason: item.engineeringReason,
          formula: item.formula,
          interactionTip: '💡 Click to select • Drag anywhere to move • Drag handles to stretch • No forced margins!',
          targetRect: rect,
          pointerPosition: localPos,
          amazonUrl: item.amazonUrl,
          imageUrl: item.imageUrl,
          productPrice: item.productPrice,
        );
      }
    }

    // Ensuite Bathroom Top Wall Gate (at y = bathTop, on top partition)
    final halfBathL = blPx / 2.0;
    final bathTop = origin.dy + rlPx - halfBathL;
    final bathDoorW = math.min(2.5 * scale, bwPx * 0.55);
    final bathDoorPivot = Offset(origin.dx + bwPx, bathTop);
    final bathDoorRect = Rect.fromLTWH(origin.dx + bwPx - bathDoorW - 4, bathTop - 8, bathDoorW + 8, bathDoorW + 16);
    if (localPos.dx <= origin.dx + bwPx + 4 &&
        (bathDoorRect.contains(localPos) || (localPos - bathDoorPivot).distance <= bathDoorW * 1.1)) {
      return CadHoverDetail(
        title: 'Ensuite Bathroom Gate',
        subtitle: 'Inward swinging acoustic sealed door on North partition wall into bathroom',
        category: 'OPENING & EGRESS',
        icon: Icons.door_front_door,
        accentColor: const Color(0xFFEAB308),
        keyMetrics: {
          'Clear Width': dims.format(2.5 * (dims.unit == DimensionUnit.feet ? 1.0 : DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, dims.unit))),
          'Swing Direction': 'Inward Bathroom Radial Arc',
          'Location': 'Top Bathroom Partition Wall',
        },
        engineeringReason: 'Positioned on the top partition wall for convenient ensuite access directly from the master bedroom vestibule.',
        interactionTip: '💡 Standard architectural ensuite door swing.',
        targetRect: Rect.fromCircle(center: bathDoorPivot, radius: bathDoorW),
        pointerPosition: localPos,
      );
    }

    // Master Bedroom Entrance Door (at end of East room wall at y = origin.dy + rlPx)
    final roomDoorW = math.min(3.0 * scale, (rwPx - bwPx) * 0.85);
    final roomDoorPivot = Offset(origin.dx + rwPx, origin.dy + rlPx);
    final roomDoorRect = Rect.fromLTWH(origin.dx + rwPx - roomDoorW - 8, origin.dy + rlPx - roomDoorW - 8, roomDoorW + 16, roomDoorW + 16);
    if (localPos.dx >= origin.dx + bwPx - 8 &&
        localPos.dx <= origin.dx + rwPx + 8 &&
        ((localPos - roomDoorPivot).distance <= roomDoorW * 1.15 || roomDoorRect.contains(localPos))) {
      return CadHoverDetail(
        title: 'Master Bedroom Door',
        subtitle: 'Main architectural entrance to the bedroom suite at end of East wall',
        category: 'OPENING & EGRESS',
        icon: Icons.meeting_room,
        accentColor: const Color(0xFFEAB308),
        keyMetrics: {
          'Clear Span': dims.format(3.0 * (dims.unit == DimensionUnit.feet ? 1.0 : DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, dims.unit))),
          'Door Swing Arc': '90° Inward Radial Sweep',
          'Wall Location': 'East (E) Dividing Wall End',
        },
        engineeringReason: 'Main entrance door positioned at the end of the 18.50 ft East wall leading into the private bedroom suite.',
        interactionTip: '💡 Main entry door into the suite.',
        targetRect: Rect.fromCircle(center: roomDoorPivot, radius: roomDoorW),
        pointerPosition: localPos,
      );
    }

    // Kitchen Rightmost Gate
    final kGateWidth = 3.0 * scale;
    final kGateLeft = origin.dx + twPx - kGateWidth;
    final kGatePivot = Offset(kGateLeft, origin.dy + klPx);
    if ((localPos - kGatePivot).distance <= 3.2 * scale) {
      return CadHoverDetail(
        title: 'Modular Kitchen Entrance Gate',
        subtitle: 'Shifted flush to the far rightmost corridor edge',
        category: 'OPENING & EGRESS',
        icon: Icons.sensor_door,
        accentColor: const Color(0xFFEAB308),
        keyMetrics: {
          'Clear Span': dims.format(3.0 * (dims.unit == DimensionUnit.feet ? 1.0 : DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, dims.unit))),
          'Location': 'Far Right Gallery Wall Boundary',
          'Access Flow': 'Direct unhindered access from Circulation Core',
        },
        engineeringReason: 'Flush rightmost positioning eliminates walking bottlenecks and integrates seamlessly with the gallery corridor.',
        targetRect: Rect.fromCircle(center: kGatePivot, radius: 3.0 * scale),
        pointerPosition: localPos,
      );
    }

    // Windows (No window on bedroom South wall)
    // Window W1 (Kitchen East Window)
    final win2Rect = Rect.fromPoints(Offset(origin.dx + rwPx + 15, origin.dy - 14), Offset(origin.dx + twPx - 15, origin.dy + 14));
    if (win2Rect.contains(localPos)) {
      return CadHoverDetail(
        title: 'Kitchen Casement Window (W1)',
        subtitle: 'High-clearance exhaust and ventilation window',
        category: 'OPENING & EGRESS',
        icon: Icons.window,
        accentColor: const Color(0xFFF87171),
        keyMetrics: {
          'Clear Width': dims.format(4.0 * (dims.unit == DimensionUnit.feet ? 1.0 : DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, dims.unit))),
          'Ventilation': 'Exhaust Hood Integration Ready',
          'Wall Alignment': 'North-East Exterior Boundary Wall',
        },
        engineeringReason: 'Facilitates smoke and moisture exhaust away from the living quarters.',
        targetRect: win2Rect,
        pointerPosition: localPos,
      );
    }

    // Bath Vent V1 (at bottom exterior wall of bathroom)
    final ventRect = Rect.fromPoints(Offset(origin.dx + bwPx * 0.20, origin.dy + tlPx - 14), Offset(origin.dx + bwPx * 0.70, origin.dy + tlPx + 14));
    if (ventRect.contains(localPos)) {
      return CadHoverDetail(
        title: 'Bathroom Louvered Ventilator (V1)',
        subtitle: 'Exterior moisture exhaust ventilator',
        category: 'OPENING & EGRESS',
        icon: Icons.air,
        accentColor: const Color(0xFF22D3EE),
        keyMetrics: {
          'Vent Span': dims.format(2.0 * (dims.unit == DimensionUnit.feet ? 1.0 : DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, dims.unit))),
          'Location': 'South Exterior Wall (S)',
        },
        engineeringReason: 'Continuous passive airflow for humidity and odor dispersion.',
        targetRect: ventRect,
        pointerPosition: localPos,
      );
    }

    // 4. Check Bathroom Wet/Dry Fixtures
    // Shower Enclosure
    final showerRect = Rect.fromLTWH(origin.dx, origin.dy + tlPx - dims.showerDepth * scale, bwPx, dims.showerDepth * scale);
    if (showerRect.contains(localPos)) {
      return CadHoverDetail(
        title: 'Walk-In Shower Wet Zone',
        subtitle: 'Tempered glass separated anti-skid wet zone',
        category: 'SANITARY FIXTURE',
        icon: Icons.shower,
        accentColor: const Color(0xFF06B6D4),
        keyMetrics: {
          'Shower Depth': dims.format(dims.showerDepth),
          'Width': dims.format(dims.bathWidth),
          'Slope Drainage': '1:50 Gradient to linear drain',
        },
        engineeringReason: 'Wet-dry separation keeps the commode and vanity dry and slip-free.',
        targetRect: showerRect,
        pointerPosition: localPos,
      );
    }

    // 5. Check Architectural Room Zones & Slabs
    // Ensuite Bathroom
    final bathRect = Rect.fromLTWH(origin.dx, bathTop, bwPx, blPx);
    if (bathRect.contains(localPos)) {
      final bathArea = dims.bathWidth * dims.bathLength;
      return CadHoverDetail(
        title: 'Ensuite Bathroom Suite',
        subtitle: '3-Fixture layout with dedicated wet/dry zoning',
        category: 'ROOM ZONE',
        icon: Icons.bathtub,
        accentColor: const Color(0xFF22D3EE),
        keyMetrics: {
          'Width': dims.format(dims.bathWidth),
          'Length': dims.format(dims.bathLength),
          'Carpet Area': dims.formatArea(bathArea),
          'Shower Depth': dims.format(dims.showerDepth),
        },
        engineeringReason: 'Ergonomic 3-zone layout: Walk-in shower, wall-hung commode, and floating wash basin.',
        targetRect: bathRect,
        pointerPosition: localPos,
      );
    }
    if (bathRect.contains(localPos)) {
      final bathArea = dims.bathWidth * dims.bathLength;
      return CadHoverDetail(
        title: 'Ensuite Bathroom Suite',
        subtitle: '3-Fixture layout with dedicated wet/dry zoning',
        category: 'ROOM ZONE',
        icon: Icons.bathtub,
        accentColor: const Color(0xFF22D3EE),
        keyMetrics: {
          'Width': dims.format(dims.bathWidth),
          'Length': dims.format(dims.bathLength),
          'Carpet Area': dims.formatArea(bathArea),
          'Shower Depth': dims.format(dims.showerDepth),
        },
        engineeringReason: 'Ergonomic 3-zone layout: Walk-in shower, wall-hung commode, and floating wash basin.',
        targetRect: bathRect,
        pointerPosition: localPos,
      );
    }

    // Modular Kitchen
    final kitchRect = Rect.fromLTWH(origin.dx + rwPx, origin.dy, kwPx, klPx);
    if (kitchRect.contains(localPos)) {
      final kitchArea = dims.kitchenWidth * dims.kitchenLength;
      return CadHoverDetail(
        title: 'Modular Kitchen & Pantry',
        subtitle: 'L-Shaped counter with Golden Ergonomic Triangle',
        category: 'ROOM ZONE',
        icon: Icons.kitchen,
        accentColor: const Color(0xFFF87171),
        keyMetrics: {
          'Width': dims.format(dims.kitchenWidth),
          'Length': dims.format(dims.kitchenLength),
          'Carpet Area': dims.formatArea(kitchArea),
          'Counter Depth': dims.format(dims.kitchenCounterDepth),
        },
        engineeringReason: 'Efficient cooking work triangle connecting Cooking Range (Hob), Wet Sink, and Cold Storage Refrigerator.',
        targetRect: kitchRect,
        pointerPosition: localPos,
      );
    }

    // Staircase Core
    final stairRect = Rect.fromLTWH(origin.dx + rwPx, origin.dy + klPx, stairW, tlPx - klPx);
    if (stairRect.contains(localPos)) {
      return CadHoverDetail(
        title: 'Circulation Staircase Core',
        subtitle: 'Dog-legged vertical transit core',
        category: 'ROOM ZONE',
        icon: Icons.stairs,
        accentColor: const Color(0xFFFBBF24),
        keyMetrics: {
          'Stair Flight Width': dims.format(dims.staircaseWidth),
          'Tread Spacing': '10.0" Ergonomic Tread',
          'Clearance': 'Unrestricted vertical egress flight',
        },
        engineeringReason: 'Structural core connecting all vertical floor levels with fire-rated masonry walls.',
        targetRect: stairRect,
        pointerPosition: localPos,
      );
    }

    // Long Gallery Corridor
    final galRect = Rect.fromLTWH(galXPx, origin.dy + klPx, dims.galleryWidth * scale, tlPx - klPx);
    if (galRect.contains(localPos)) {
      return CadHoverDetail(
        title: 'Long Gallery Access Corridor',
        subtitle: 'Primary circulation and transit artery',
        category: 'ROOM ZONE',
        icon: Icons.view_column,
        accentColor: const Color(0xFF94A3B8),
        keyMetrics: {
          'Clear Passage Width': dims.format(dims.galleryWidth),
          'Transit Flow': 'Connects Main Entry to Modular Kitchen',
        },
        engineeringReason: 'Meets building egress codes ensuring minimum unobstructed circulation width.',
        targetRect: galRect,
        pointerPosition: localPos,
      );
    }

    // Master Bedroom & Living Suite
    final bedRoomRect = Rect.fromLTWH(origin.dx, origin.dy, rwPx, rlPx);
    if (bedRoomRect.contains(localPos)) {
      final bedArea = dims.roomWidth * dims.roomLength;
      return CadHoverDetail(
        title: 'Master Bedroom & Living Suite',
        subtitle: 'Primary spatial habitat zone',
        category: 'ROOM ZONE',
        icon: Icons.king_bed,
        accentColor: const Color(0xFF818CF8),
        keyMetrics: {
          'Room Width': dims.format(dims.roomWidth),
          'Room Length': dims.format(dims.roomLength),
          'Ceiling Height': dims.format(dims.ceilingHeight),
          'Total Area': dims.formatArea(bedArea),
        },
        engineeringReason: 'Spacious rectangular aspect ratio supporting king bed suite, built-in wardrobes, executive workstation, and central circulation.',
        interactionTip: '💡 Add furniture using the quick input below or drag placed items freely to any coordinate.',
        targetRect: bedRoomRect,
        pointerPosition: localPos,
      );
    }

    // Compass Rose (Top Right)
    final compassCenter = Offset(canvasSize.width - 60, 60);
    if ((localPos - compassCenter).distance <= 35) {
      return CadHoverDetail(
        title: '4-Point Architectural Compass Rose',
        subtitle: 'Cardinal site orientation & Vastu alignment',
        category: 'CAD ANNOTATION',
        icon: Icons.explore,
        accentColor: const Color(0xFF38BDF8),
        keyMetrics: {
          'North (N)': '↓ Pointing Down (Entry Corridor Side)',
          'South (S)': '↑ Pointing Up (Solid Wall)',
          'East (E)': '→ Pointing Right (Kitchen & Stair Core)',
          'West (W)': '← Pointing Left (Master Bed Wall)',
        },
        engineeringReason: 'Architectural cardinal orientation calibrated to physical floor plan openings.',
        targetRect: Rect.fromCircle(center: compassCenter, radius: 30),
        pointerPosition: localPos,
      );
    }

    return null;
  }
}
