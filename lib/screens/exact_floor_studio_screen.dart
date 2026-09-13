import 'package:flutter/material.dart';
import '../models/dynamic_floor_model.dart';
import '../models/dynamic_floor_layout_engine.dart';
import '../widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';
import '../widgets/dialogs/floor_dimension_form.dart';
import '../services/blueprint_export_service.dart';

class ExactFloorStudioScreen extends StatefulWidget {
  const ExactFloorStudioScreen({super.key});

  @override
  State<ExactFloorStudioScreen> createState() => _ExactFloorStudioScreenState();
}

class _ExactFloorStudioScreenState extends State<ExactFloorStudioScreen> {
  late DynamicFloorDimensions _dims;
  late List<DynamicFloorStyle> _styles;
  int _selectedStyleIndex = 0;

  bool _showDimensions = true;
  bool _showGrid = true;
  bool _showRoomLabels = true;
  bool _isExporting = false;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final TransformationController _transController = TransformationController();

  @override
  void initState() {
    super.initState();
    _dims = DynamicFloorDimensions();
    _recalculateStyles();
  }

  void _recalculateStyles() {
    _styles = DynamicFloorLayoutEngine.generateStyles(_dims);
  }

  void _openDimensionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FloorDimensionFormDialog(
        initialDimensions: _dims.clone(),
        onSave: (updated) {
          setState(() {
            _dims = updated;
            _recalculateStyles();
          });
        },
      ),
    );
  }

  Future<void> _exportBlueprint() async {
    setState(() => _isExporting = true);
    final pngBytes = await BlueprintExportService.generateUltraHighResBlueprintSheet(
      dims: _dims,
      items: const [],
      roomName: 'Master Floor Architectural Studio',
      showDimensions: _showDimensions,
      showGrid: _showGrid,
      showRoomLabels: _showRoomLabels,
    );

    String? savedPath;
    if (pngBytes != null) {
      final filename = 'CAD_Blueprint_Exact_Studio_${DateTime.now().millisecondsSinceEpoch}.png';
      savedPath = await BlueprintExportService.saveFileToDisk(pngBytes, filename);
    }

    setState(() => _isExporting = false);

    if (pngBytes != null && mounted) {
      BlueprintExportService.showExportSuccessDialog(
        context,
        pngBytes,
        'Master Floor Architectural Studio',
        savedFilePath: savedPath,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final curStyle = _styles[_selectedStyleIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Row(
          children: [
            const Icon(Icons.architecture, color: Color(0xFF38BDF8), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Master Floor Studio • 2D Architectural CAD Engine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
            ),
            onPressed: _openDimensionDialog,
            icon: const Icon(Icons.edit_note, size: 18),
            label: Text('Edit Dimensions (${_dims.unit.shortName.toUpperCase()})'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            onPressed: _isExporting ? null : _exportBlueprint,
            icon: _isExporting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export CAD Blueprint', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Row(
        children: [
          // Main Interactive Viewport (2D CAD)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Top Toolbar: Layer Controls
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
                        Row(
                          children: [
                            FilterChip(
                              label: const Text('Rulers & Dims'),
                              selected: _showDimensions,
                              avatar: const Icon(Icons.straighten, size: 15),
                              onSelected: (v) => setState(() => _showDimensions = v),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('CAD Grid'),
                              selected: _showGrid,
                              avatar: const Icon(Icons.grid_on, size: 15),
                              onSelected: (v) => setState(() => _showGrid = v),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Room Stamps & Areas'),
                              selected: _showRoomLabels,
                              avatar: const Icon(Icons.tag, size: 15),
                              onSelected: (v) => setState(() => _showRoomLabels = v),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Scale 1:50 Precision',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // The Interactive Canvas
                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            color: const Color(0xFF0B1120),
                            child: InteractiveViewer(
                              transformationController: _transController,
                              minScale: 0.2,
                              maxScale: 5.0,
                              boundaryMargin: const EdgeInsets.all(400),
                              child: RepaintBoundary(
                                key: _repaintBoundaryKey,
                                child: Container(
                                  width: 950,
                                  height: 750,
                                  color: const Color(0xFF0B1120),
                                  child: CustomPaint(
                                    painter: DynamicFloor2DPainter(
                                      dims: _dims,
                                      showDimensions: _showDimensions,
                                      showGrid: _showGrid,
                                      showRoomLabels: _showRoomLabels,
                                      isDarkMode: true,
                                    ),
                                    size: const Size(950, 750),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Quick Zoom Buttons
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Column(
                            children: [
                              FloatingActionButton.small(
                                heroTag: 'dyn_zoom_in',
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: const Color(0xFF38BDF8),
                                onPressed: () {
                                  final m = _transController.value.clone();
                                  m.scale(1.25);
                                  _transController.value = m;
                                },
                                tooltip: 'Zoom In',
                                child: const Icon(Icons.zoom_in),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'dyn_zoom_out',
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: const Color(0xFF38BDF8),
                                onPressed: () {
                                  final m = _transController.value.clone();
                                  m.scale(0.8);
                                  _transController.value = m;
                                },
                                tooltip: 'Zoom Out',
                                child: const Icon(Icons.zoom_out),
                              ),
                              const SizedBox(height: 8),
                              FloatingActionButton.small(
                                heroTag: 'dyn_zoom_reset',
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                onPressed: () {
                                  _transController.value = Matrix4.identity();
                                },
                                tooltip: 'Reset View',
                                child: const Icon(Icons.center_focus_strong),
                              ),
                            ],
                          ),
                        ),

                        // Dimension Pill (Bottom Left)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.straighten, size: 14, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Text(
                                  'Master Room: ${_dims.format(_dims.roomWidth)} × ${_dims.format(_dims.roomLength)} | Bath: ${_dims.format(_dims.bathWidth)} × ${_dims.format(_dims.bathLength)} | Kitchen: ${_dims.format(_dims.kitchenWidth)} × ${_dims.format(_dims.kitchenLength)}',
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
              ),
            ),
          ),

          // Right Sidebar: Layout Styles & Architectural Room Schedule
          Container(
            width: 380,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(left: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Layout Style Selector Cards
                Row(
                  children: [
                    const Icon(Icons.layers_outlined, color: Color(0xFF38BDF8), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'CAD Layout Variations (${_styles.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._styles.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final style = entry.value;
                  final isSelected = _selectedStyleIndex == idx;

                  return InkWell(
                    onTap: () => setState(() => _selectedStyleIndex = idx),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF131C2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                          width: isSelected ? 1.8 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  style.title,
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${style.score}% Efficiency', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(style.description, style: const TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: style.highlights.map((h) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('✓ $h', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10)),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 14),

                // Architectural Specifications Schedule
                _buildArchitecturalScheduleCard(curStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitecturalScheduleCard(DynamicFloorStyle style) {
    final roomArea = _dims.roomWidth * _dims.roomLength;
    final bathArea = _dims.bathWidth * _dims.bathLength;
    final kitchArea = _dims.kitchenWidth * _dims.kitchenLength;
    final totalBuiltArea = _dims.totalWidth * _dims.totalLength;
    final unitSq = _dims.unit.areaUnit;

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
              Expanded(
                child: Text(
                  'Architectural Room & Wall Schedule',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _scheduleRow('Master Bedroom', '${_dims.format(_dims.roomWidth)} × ${_dims.format(_dims.roomLength)}', '${roomArea.toStringAsFixed(1)} $unitSq', const Color(0xFF818CF8)),
          _scheduleRow('Ensuite Bathroom', '${_dims.format(_dims.bathWidth)} × ${_dims.format(_dims.bathLength)}', '${bathArea.toStringAsFixed(1)} $unitSq', const Color(0xFF22D3EE)),
          _scheduleRow('Modular Kitchen', '${_dims.format(_dims.kitchenWidth)} × ${_dims.format(_dims.kitchenLength)}', '${kitchArea.toStringAsFixed(1)} $unitSq', const Color(0xFFF87171)),
          _scheduleRow('Staircase Core', 'Width ${_dims.format(_dims.staircaseWidth)}', 'Circulation', const Color(0xFFFBBF24)),
          _scheduleRow('Gallery Corridor', 'Width ${_dims.format(_dims.galleryWidth)}', 'Circulation', const Color(0xFF94A3B8)),
          const Divider(color: Color(0xFF334155), height: 18),
          _metricRow('Total Gross Built-up', '${totalBuiltArea.toStringAsFixed(1)} $unitSq'),
          _metricRow('Ceiling Clear Height', _dims.format(_dims.ceilingHeight)),
          _metricRow('Master Entry Door', '3.0 ft (Radial Swing)'),
          _metricRow('Bathroom Gate', '2.5 ft'),
          _metricRow('Kitchen Entry Opening', '3.0 ft'),
          _metricRow('Shower Wet Zone', '${_dims.format(_dims.showerDepth)} depth'),
        ],
      ),
    );
  }

  Widget _scheduleRow(String name, String dims, String area, Color dotColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 4),
          Text(dims, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(width: 8),
          Text(area, style: TextStyle(color: dotColor, fontSize: 11, fontWeight: FontWeight.bold)),
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
          Text(value, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w600, fontSize: 11.5)),
        ],
      ),
    );
  }
}
