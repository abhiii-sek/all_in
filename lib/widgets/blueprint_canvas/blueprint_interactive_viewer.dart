import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import 'blueprint_2d_painter.dart';

class BlueprintInteractiveViewer extends StatefulWidget {
  final RoomModel room;
  final GlobalKey repaintBoundaryKey;

  const BlueprintInteractiveViewer({
    super.key,
    required this.room,
    required this.repaintBoundaryKey,
  });

  @override
  State<BlueprintInteractiveViewer> createState() =>
      _BlueprintInteractiveViewerState();
}

class _BlueprintInteractiveViewerState extends State<BlueprintInteractiveViewer> {
  bool _showDimensions = true;
  bool _showClearances = true;
  bool _showGrid = true;
  final TransformationController _transController = TransformationController();

  void _zoomIn() {
    final matrix = _transController.value.clone();
    matrix.scale(1.25);
    _transController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transController.value.clone();
    matrix.scale(0.8);
    _transController.value = matrix;
  }

  void _resetZoom() {
    _transController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Toolbar (Layer Controls)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 2D Blueprint Badge & Layer Toggles
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF38BDF8)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.architecture_outlined, size: 16, color: Color(0xFF38BDF8)),
                        SizedBox(width: 6),
                        Text(
                          '2D CAD Blueprint',
                          style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilterChip(
                    label: const Text('Rulers & Dims'),
                    selected: _showDimensions,
                    avatar: const Icon(Icons.straighten, size: 15),
                    onSelected: (val) => setState(() => _showDimensions = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('Clearance Zones'),
                    selected: _showClearances,
                    avatar: const Icon(Icons.verified_user_outlined, size: 15),
                    onSelected: (val) => setState(() => _showClearances = val),
                  ),
                  const SizedBox(width: 6),
                  FilterChip(
                    label: const Text('CAD Grid'),
                    selected: _showGrid,
                    avatar: const Icon(Icons.grid_on, size: 15),
                    onSelected: (val) => setState(() => _showGrid = val),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // The Interactive Blueprint Canvas with RepaintBoundary for Export
        Expanded(
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: const Color(0xFF0B1120),
                  child: InteractiveViewer(
                    transformationController: _transController,
                    minScale: 0.3,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: RepaintBoundary(
                      key: widget.repaintBoundaryKey,
                      child: Container(
                        width: 900,
                        height: 700,
                        color: const Color(0xFF0B1120),
                        child: CustomPaint(
                          painter: Blueprint2DPainter(
                            room: widget.room,
                            showDimensions: _showDimensions,
                            showClearances: _showClearances,
                            showGrid: _showGrid,
                            isDarkMode: true,
                          ),
                          size: const Size(900, 700),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Canvas Controls (Zoom In, Zoom Out, Reset Center)
              Positioned(
                right: 16,
                bottom: 16,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoom_in',
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      onPressed: _zoomIn,
                      tooltip: 'Zoom In',
                      child: const Icon(Icons.zoom_in),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoom_out',
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: const Color(0xFF38BDF8),
                      onPressed: _zoomOut,
                      tooltip: 'Zoom Out',
                      child: const Icon(Icons.zoom_out),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton.small(
                      heroTag: 'zoom_reset',
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      onPressed: _resetZoom,
                      tooltip: 'Reset Zoom & Center',
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
              ),

              // Scale & Dimension Legend pill (Bottom Left)
              Positioned(
                left: 16,
                bottom: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.aspect_ratio, size: 14, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Text(
                        'Floor Area: ${widget.room.floorAreaSqFt.toStringAsFixed(1)} sq.ft (${widget.room.floorAreaSqM.toStringAsFixed(2)} m²) | Ceiling: ${widget.room.ceilingHeight.toStringAsFixed(1)}m',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
