import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';

class PromptGeneratorScreen extends StatefulWidget {
  final DynamicFloorDimensions? initialDims;

  const PromptGeneratorScreen({super.key, this.initialDims});

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen> {
  late DynamicFloorDimensions _dims;
  late TextEditingController _roomWCtrl;
  late TextEditingController _roomLCtrl;
  late TextEditingController _ceilingHCtrl;
  late TextEditingController _customItemCtrl;

  String _selectedWallForNewItem = 'West Wall (W)';
  String _selectedFacingForNewItem = 'Auto (Inward)';

  // Starts completely empty - only user-added items appear!
  final List<RoomItemPlacement> _placements = [];

  final List<String> _cardinalWalls = [
    'North Wall (N)',
    'South Wall (S)',
    'East Wall (E)',
    'West Wall (W)',
    'North-West Corner (N-W)',
    'North-East Corner (N-E)',
    'South-West Corner (S-W)',
    'South-East Corner (S-E)',
    'Center Floor',
  ];

  @override
  void initState() {
    super.initState();
    _dims = widget.initialDims?.clone() ?? DynamicFloorDimensions();
    _roomWCtrl = TextEditingController(text: _dims.roomWidth.toStringAsFixed(2));
    _roomLCtrl = TextEditingController(text: _dims.roomLength.toStringAsFixed(2));
    _ceilingHCtrl = TextEditingController(text: _dims.ceilingHeight.toStringAsFixed(2));
    _customItemCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _roomWCtrl.dispose();
    _roomLCtrl.dispose();
    _ceilingHCtrl.dispose();
    _customItemCtrl.dispose();
    super.dispose();
  }

  void _applyInputs() {
    setState(() {
      _dims.roomWidth = double.tryParse(_roomWCtrl.text) ?? _dims.roomWidth;
      _dims.roomLength = double.tryParse(_roomLCtrl.text) ?? _dims.roomLength;
      _dims.ceilingHeight = double.tryParse(_ceilingHCtrl.text) ?? _dims.ceilingHeight;
    });
  }

  void _addItem() {
    final raw = _customItemCtrl.text.trim();
    if (raw.isNotEmpty) {
      final parts = raw
          .split(RegExp(r'[,;]|\band\b|\b\+\b'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      setState(() {
        for (int i = 0; i < parts.length; i++) {
          _placements.add(RoomItemPlacement(
            id: 'item_${DateTime.now().millisecondsSinceEpoch}_$i',
            itemName: parts[i],
            targetWall: _selectedWallForNewItem,
            facingDirection: _selectedFacingForNewItem,
          ));
        }
        _customItemCtrl.clear();
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _placements.removeAt(index);
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label copied to clipboard successfully!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullPrompt = ArchitecturalPromptService.generateMasterPrompt(
      dims: _dims,
      placements: _placements,
    );

    final calculatedItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Architectural Prompt & Math Sizing Engine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _copyToClipboard(fullPrompt, 'Master AI Prompt'),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Master Prompt', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Column: Inputs & Math Calculations
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. Cardinal Wall & Dimensions Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
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
                              Icon(Icons.explore, color: Color(0xFF38BDF8), size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Room Dimensions & Cardinal Walls (N, S, E, W)',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          SegmentedButton<DimensionUnit>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(value: DimensionUnit.feet, label: Text('ft')),
                              ButtonSegment(value: DimensionUnit.inches, label: Text('in')),
                              ButtonSegment(value: DimensionUnit.meters, label: Text('m')),
                              ButtonSegment(value: DimensionUnit.centimeters, label: Text('cm')),
                            ],
                            selected: {_dims.unit},
                            onSelectionChanged: (val) {
                              if (val.isNotEmpty) {
                                setState(() {
                                  _dims.switchUnit(val.first);
                                  _roomWCtrl.text = _dims.roomWidth.toStringAsFixed(2);
                                  _roomLCtrl.text = _dims.roomLength.toStringAsFixed(2);
                                  _ceilingHCtrl.text = _dims.ceilingHeight.toStringAsFixed(2);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _numField('Room Width (E ↔ W)', _roomWCtrl),
                          _numField('Room Length (N ↔ S)', _roomLCtrl),
                          _numField('Ceiling Height (H)', _ceilingHCtrl),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Cardinal Directions Pill Grid
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131C2E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _CardinalBadge('North Wall (N)', 'Main Entry Door', Color(0xFFEF4444)),
                            _CardinalBadge('South Wall (S)', 'Glazed Windows', Color(0xFF38BDF8)),
                            _CardinalBadge('East Wall (E)', 'Gallery & Storage', Color(0xFF10B981)),
                            _CardinalBadge('West Wall (W)', 'Solid Feature Wall', Color(0xFF818CF8)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Describe Items & Wall Placement Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.format_list_bulleted_add, color: Color(0xFF10B981), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Describe Items & Attached Wall Placements',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select which wall (N, S, E, W) each furniture/fixture is attached to. The engine uses mathematical geometry to calculate the best possible non-colliding dimensions.',
                        style: TextStyle(color: Colors.white60, fontSize: 11.5),
                      ),
                      const SizedBox(height: 14),

                      // Add Item Input Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _customItemCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Item name (e.g. King Bed, Study Table, Wardrobe, Recliner)...',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedWallForNewItem,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                            items: _cardinalWalls.map((w) {
                              return DropdownMenuItem(value: w, child: Text(w));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedWallForNewItem = val;
                                  _selectedFacingForNewItem = ArchitecturalPromptService.defaultFacingForWall(val);
                                });
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: ArchitecturalPromptService.facingDirectionOptions.contains(_selectedFacingForNewItem)
                                ? _selectedFacingForNewItem
                                : ArchitecturalPromptService.facingDirectionOptions.first,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                            items: ArchitecturalPromptService.facingDirectionOptions.map((f) {
                              return DropdownMenuItem(value: f, child: Text(f));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedFacingForNewItem = val);
                            },
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: Colors.black,
                            ),
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Item'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Placements List
                      if (_placements.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: const Center(
                            child: Text(
                              'No furniture items added yet. Type an item name and click "Add Item".',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ),
                      ..._placements.asMap().entries.map((entry) {
                        final i = entry.key;
                        final p = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.targetWall,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.facingDirection,
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 10.5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  p.itemName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                                onPressed: () => _removeItem(i),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Calculated Math Dimensions Breakdown
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.calculate_outlined, color: Color(0xFFF59E0B), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Mathematical Sizing & Clearance Calculations',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (calculatedItems.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              'Mathematical dimensions will calculate automatically when items are added.',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ),
                        ),
                      ...calculatedItems.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131C2E),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF334155)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.itemName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    '${_dims.format(item.width)} × ${_dims.format(item.length)} × ${_dims.format(item.height)}',
                                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '📍 ${item.targetWall} • Buffer: ${_dims.format(item.clearance)} walkway',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '📐 ${item.formula}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10.5, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right Column: Master Copyable Prompt Box
          Expanded(
            flex: 6,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with Copy Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: const BoxDecoration(
                      color: Color(0xFF131C2E),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Generated Master AI Prompt (2-3 2D CAD & 2-3 3D Renders)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF38BDF8),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => _copyToClipboard(fullPrompt, 'Master AI Prompt'),
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text('Copy to Clipboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),

                  // Selectable Scrollable Prompt Text View
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          fullPrompt,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12.5,
                            fontFamily: 'monospace',
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: (_) => _applyInputs(),
      ),
    );
  }
}

class _CardinalBadge extends StatelessWidget {
  final String wall;
  final String feature;
  final Color color;

  const _CardinalBadge(this.wall, this.feature, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          wall,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5),
        ),
        const SizedBox(height: 2),
        Text(
          feature,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}
