import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../../models/wall_opening.dart';
import '../../services/project_state.dart';
import '../../services/blueprint_export_service.dart';
import '../../widgets/blueprint_canvas/blueprint_interactive_viewer.dart';
import '../../widgets/blueprint_canvas/layout_selection_sheet.dart';
import 'wizard/room_wizard_screen.dart';
import 'bedroom_simulation_screen.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';

class BlueprintStudioScreen extends StatefulWidget {
  final RoomModel room;
  final ProjectState projectState;

  const BlueprintStudioScreen({
    super.key,
    required this.room,
    required this.projectState,
  });

  @override
  State<BlueprintStudioScreen> createState() => _BlueprintStudioScreenState();
}

class _BlueprintStudioScreenState extends State<BlueprintStudioScreen> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isExporting = false;

  Future<void> _exportBlueprint() async {
    setState(() => _isExporting = true);
    final pngBytes = await BlueprintExportService.captureBlueprintPng(_repaintBoundaryKey);
    setState(() => _isExporting = false);

    if (pngBytes != null && mounted) {
      BlueprintExportService.showExportSuccessDialog(context, pngBytes, widget.room.name);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Failed to render blueprint image. Please try again.'),
        ),
      );
    }
  }

  void _open3DSimulation() {
    final room = widget.room;
    final dims = DynamicFloorDimensions(
      unit: DimensionUnit.meters,
      roomWidth: room.effectiveWidth,
      roomLength: room.effectiveLength,
      ceilingHeight: room.ceilingHeight,
    );

    final placements = room.requestedItems.map((item) {
      return RoomItemPlacement(
        id: item.id,
        itemName: item.name,
        targetWall: 'West Wall (W)',
        facingDirection: 'Auto (Inward)',
        customWidth: item.width,
        customLength: item.depth,
        customHeight: item.height,
        customPosX: item.x,
        customPosY: item.y,
        customNotes: item.notes,
        amazonUrl: item.amazonUrl,
        imageUrl: item.imageUrl,
        productPrice: item.productPrice,
        productBrand: item.productBrand,
      );
    }).toList();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BedroomSimulationScreen(
          dims: dims,
          placements: placements,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${room.floorAreaSqFt.toStringAsFixed(1)} sq.ft | ${room.effectiveWidth.toStringAsFixed(2)}m × ${room.effectiveLength.toStringAsFixed(2)}m',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9900),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _open3DSimulation,
            icon: const Icon(Icons.view_in_ar, size: 16),
            label: const Text('🌟 3D Simulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Edit Dimensions & Openings',
            icon: const Icon(Icons.edit_note, color: Color(0xFF38BDF8)),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => RoomWizardScreen(
                    projectState: widget.projectState,
                    existingRoom: room,
                  ),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _isExporting ? null : _exportBlueprint,
            icon: _isExporting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export Blueprint', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Left Main Canvas (2D CAD Viewer)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: BlueprintInteractiveViewer(
                room: room,
                repaintBoundaryKey: _repaintBoundaryKey,
              ),
            ),
          ),

          // Right Sidebar (Layout Suggestions & Architectural Openings Schedule)
          Container(
            width: 380,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(left: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Layout Options Switcher
                LayoutSelectionSheet(
                  room: room,
                  projectState: widget.projectState,
                ),
                const SizedBox(height: 16),

                // Dimension & Metric Schedule Card
                _buildMetricsCard(room),
                const SizedBox(height: 16),

                // Architectural Openings Schedule Card
                _buildOpeningScheduleCard(room),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCard(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 6),
              Text(
                'Engineering & Spatial Metrics',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _metricRow('Wall A (North)', '${room.wallTop.toStringAsFixed(2)} m'),
          _metricRow('Wall B (East)', '${room.wallRight.toStringAsFixed(2)} m'),
          _metricRow('Wall C (South)', '${room.wallBottom.toStringAsFixed(2)} m'),
          _metricRow('Wall D (West)', '${room.wallLeft.toStringAsFixed(2)} m'),
          const Divider(color: Color(0xFF334155), height: 16),
          _metricRow('Floor Area', '${room.floorAreaSqFt.toStringAsFixed(1)} sq.ft (${room.floorAreaSqM.toStringAsFixed(2)} m²)'),
          _metricRow('Room Volume', '${room.roomVolumeCuM.toStringAsFixed(1)} m³ (${(room.roomVolumeCuM * 35.3147).toStringAsFixed(0)} cu.ft)'),
          _metricRow('Net Paint/Tile Area', '${room.netWallAreaSqM.toStringAsFixed(1)} m²'),
          _metricRow('Recommended AC Capacity', '${(room.floorAreaSqFt / 100 * 0.8).clamp(0.8, 2.5).toStringAsFixed(1)} Ton Split AC'),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5)),
        ],
      ),
    );
  }

  Widget _buildOpeningScheduleCard(RoomModel room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.door_sliding_outlined, color: Color(0xFF38BDF8), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Door & Window Schedule',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Text('${room.openings.length} Openings', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          ...room.openings.map((op) {
            final isDoor = op.type == OpeningType.door;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isDoor ? Icons.door_front_door_outlined : Icons.window_outlined,
                    color: isDoor ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDoor ? 'Main Entry Door' : 'Natural Light Window / Vent',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Width: ${op.width.toStringAsFixed(2)}m • Corner Offset: ${op.offsetFromCorner.toStringAsFixed(2)}m',
                          style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
