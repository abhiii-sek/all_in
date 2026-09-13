import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';
import '../services/amazon_dimension_parser_service.dart';

class PromptGeneratorScreen extends StatefulWidget {
  final DynamicFloorDimensions? initialDims;
  final List<RoomItemPlacement>? initialPlacements;

  const PromptGeneratorScreen({
    super.key,
    this.initialDims,
    this.initialPlacements,
  });

  @override
  State<PromptGeneratorScreen> createState() => _PromptGeneratorScreenState();
}

class _PromptGeneratorScreenState extends State<PromptGeneratorScreen>
    with SingleTickerProviderStateMixin {
  late DynamicFloorDimensions _dims;
  late TextEditingController _roomWCtrl;
  late TextEditingController _roomLCtrl;
  late TextEditingController _ceilingHCtrl;
  late TextEditingController _customItemCtrl;

  // Custom dimension overrides for new item
  final TextEditingController _customWidthCtrl = TextEditingController();
  final TextEditingController _customLengthCtrl = TextEditingController();
  final TextEditingController _customHeightCtrl = TextEditingController();
  final TextEditingController _amazonDescCtrl = TextEditingController();
  String? _amazonParsedSummary;
  bool _showCustomDimensionInputs = false;

  String _selectedWallForNewItem = 'West Wall (W)';
  String _selectedFacingForNewItem = 'Facing East (→)';

  // Placements list
  final List<RoomItemPlacement> _placements = [];

  // Recalibration State
  SpatialRecalibrationResult? _recalibrationResult;
  bool _isRecalibrating = false;
  late TabController _tabController;

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

  final List<Map<String, String>> _quickFurniturePresets = [
    {'name': '3-Seater Sofa', 'wall': 'South Wall (S)', 'facing': 'Facing North (↑)'},
    {'name': 'Sectional L-Sofa', 'wall': 'South-West Corner (S-W)', 'facing': 'Facing North (↑)'},
    {'name': 'King Platform Bed', 'wall': 'West Wall (W)', 'facing': 'Facing East (→)'},
    {'name': 'Sliding Wardrobe', 'wall': 'East Wall (E)', 'facing': 'Facing West (←)'},
    {'name': 'Wall-Mounted TV Unit', 'wall': 'North Wall (N)', 'facing': 'Facing South (↓)'},
    {'name': 'Study Desk & Chair', 'wall': 'North Wall (N)', 'facing': 'Facing South (↓)'},
    {'name': 'Vanity Dressing Table', 'wall': 'East Wall (E)', 'facing': 'Facing West (←)'},
    {'name': 'Center Coffee Table', 'wall': 'Center Floor', 'facing': 'Auto (Inward)'},
  ];

  @override
  void initState() {
    super.initState();
    _dims = widget.initialDims?.clone() ?? DynamicFloorDimensions();
    _roomWCtrl = TextEditingController(text: _dims.roomWidth.toStringAsFixed(2));
    _roomLCtrl = TextEditingController(text: _dims.roomLength.toStringAsFixed(2));
    _ceilingHCtrl = TextEditingController(text: _dims.ceilingHeight.toStringAsFixed(2));
    _customItemCtrl = TextEditingController();

    _tabController = TabController(length: 4, vsync: this);

    if (widget.initialPlacements != null && widget.initialPlacements!.isNotEmpty) {
      _placements.addAll(widget.initialPlacements!.map((p) => p.copyWith()));
      // Perform initial recalibration if placements were provided
      _performRecalibration();
    }
  }

  @override
  void dispose() {
    _roomWCtrl.dispose();
    _roomLCtrl.dispose();
    _ceilingHCtrl.dispose();
    _customItemCtrl.dispose();
    _customWidthCtrl.dispose();
    _customLengthCtrl.dispose();
    _customHeightCtrl.dispose();
    _amazonDescCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _applyDimensions() {
    setState(() {
      _dims.roomWidth = double.tryParse(_roomWCtrl.text) ?? _dims.roomWidth;
      _dims.roomLength = double.tryParse(_roomLCtrl.text) ?? _dims.roomLength;
      _dims.ceilingHeight = double.tryParse(_ceilingHCtrl.text) ?? _dims.ceilingHeight;
      // Mark as needing recalibration
      _recalibrationResult = null;
    });
  }

  void _parseAndApplyAmazonDescription() {
    final text = _amazonDescCtrl.text.trim();
    if (text.isEmpty) return;
    final parsed = AmazonDimensionParserService.parse(text, targetUnit: _dims.unit);
    setState(() {
      if (parsed.isValid) {
        if (parsed.width != null) _customWidthCtrl.text = parsed.width!.toStringAsFixed(2);
        if (parsed.length != null) _customLengthCtrl.text = parsed.length!.toStringAsFixed(2);
        if (parsed.height != null) _customHeightCtrl.text = parsed.height!.toStringAsFixed(2);
        _amazonParsedSummary = parsed.formattedSummary;
        _showCustomDimensionInputs = true;
      } else {
        _amazonParsedSummary = 'Could not parse dimensions from description.';
      }
    });
  }

  void _addQuickPreset(String name, String wall, String facing) {
    setState(() {
      _placements.add(RoomItemPlacement(
        id: 'item_${DateTime.now().millisecondsSinceEpoch}_${_placements.length}',
        itemName: name,
        targetWall: wall,
        facingDirection: facing,
      ));
      _recalibrationResult = null;
    });
  }

  void _addItem() {
    final raw = _customItemCtrl.text.trim();
    if (raw.isNotEmpty) {
      final double? cW = double.tryParse(_customWidthCtrl.text.trim());
      final double? cL = double.tryParse(_customLengthCtrl.text.trim());
      final double? cH = double.tryParse(_customHeightCtrl.text.trim());

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
            customWidth: cW,
            customLength: cL,
            customHeight: cH,
          ));
        }
        _customItemCtrl.clear();
        _customWidthCtrl.clear();
        _customLengthCtrl.clear();
        _customHeightCtrl.clear();
        _amazonDescCtrl.clear();
        _amazonParsedSummary = null;
        _showCustomDimensionInputs = false;
        _recalibrationResult = null;
      });
    }
  }

  void _showEditPlacementDialog(int index) {
    if (index >= _placements.length) return;
    final p = _placements[index];
    final wCtrl = TextEditingController(text: p.customWidth?.toStringAsFixed(2) ?? '');
    final lCtrl = TextEditingController(text: p.customLength?.toStringAsFixed(2) ?? '');
    final hCtrl = TextEditingController(text: p.customHeight?.toStringAsFixed(2) ?? '');
    final amazonCtrl = TextEditingController();
    String? localSummary;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Modify Dimensions: ${p.itemName}',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paste Amazon product dimension or enter custom values in ${_dims.unit.symbol}:',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF9900), size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Amazon Dimension String (e.g. 198.1L x 152.4W x 10.2Th Centimeter)',
                                  style: TextStyle(color: Color(0xFFFF9900), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amazonCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'Paste: 47.6D x 120W x 182.4H Centimeters...',
                                hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                                isDense: true,
                                border: InputBorder.none,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF9900),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () {
                                  final text = amazonCtrl.text.trim();
                                  if (text.isNotEmpty) {
                                    final res = AmazonDimensionParserService.parse(text, targetUnit: _dims.unit);
                                    setDialogState(() {
                                      if (res.isValid) {
                                        if (res.width != null) wCtrl.text = res.width!.toStringAsFixed(2);
                                        if (res.length != null) lCtrl.text = res.length!.toStringAsFixed(2);
                                        if (res.height != null) hCtrl.text = res.height!.toStringAsFixed(2);
                                        localSummary = res.formattedSummary;
                                      } else {
                                        localSummary = 'Could not parse dimensions.';
                                      }
                                    });
                                  }
                                },
                                icon: const Icon(Icons.auto_awesome, size: 13),
                                label: const Text('Parse & Apply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            if (localSummary != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                localSummary!,
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: wCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Width (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Length (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: hCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Height (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final double? newW = double.tryParse(wCtrl.text.trim());
                    final double? newL = double.tryParse(lCtrl.text.trim());
                    final double? newH = double.tryParse(hCtrl.text.trim());
                    setState(() {
                      p.customWidth = newW;
                      p.customLength = newL;
                      p.customHeight = newH;
                      _recalibrationResult = null;
                    });
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Save Dimensions', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _removeItem(int index) {
    setState(() {
      _placements.removeAt(index);
      _recalibrationResult = null;
    });
  }

  void _performRecalibration() {
    _applyDimensions();
    setState(() {
      _isRecalibrating = true;
    });

    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final result = ArchitecturalPromptService.recalibrateSpatialLayout(
        dims: _dims,
        placements: _placements,
      );

      setState(() {
        _recalibrationResult = result;
        _isRecalibrating = false;
      });
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Spatial Recalibration & Prompt Studio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (_recalibrationResult != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _copyToClipboard(_recalibrationResult!.masterPrompt, 'Master AI Prompt'),
                icon: const Icon(Icons.copy, size: 15),
                label: const Text('Copy Master Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CARD 1: Room Dimensions & Global Unit Setup
            _buildRoomDimensionsCard(),
            const SizedBox(height: 16),

            // CARD 2: Cardinal Walls & Openings Reference
            _buildCardinalWallsCard(),
            const SizedBox(height: 16),

            // CARD 3: Add & Manage Furniture / Fixtures
            _buildFurnitureManagementCard(),
            const SizedBox(height: 20),

            // ACTION BAR: Recalibrate & Generate Master AI Prompt Button
            _buildGenerateActionBar(),
            const SizedBox(height: 24),

            // CARD 4: Recalibration Results & AI Prompt Suite
            if (_recalibrationResult != null) _buildRecalibrationResultsView(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomDimensionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  Icon(Icons.straighten, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Step 1: Room Dimensions & Measurement Unit',
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
                      _recalibrationResult = null;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _numField('Room Width (East ↔ West)', _roomWCtrl),
              _numField('Room Length (North ↔ South)', _roomLCtrl),
              _numField('Ceiling Height (AFF)', _ceilingHCtrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardinalWallsCard() {
    return Container(
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
              Icon(Icons.explore, color: Color(0xFF10B981), size: 18),
              SizedBox(width: 8),
              Text(
                'Step 2: Room Cardinal Boundaries & Anchors',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _cardinalInfoPill('North Wall (N)', 'Exterior Glazed Window (W1)', const Color(0xFFEF4444)),
                _cardinalInfoPill('South Wall (S)', 'Living Zone / Enclosed Wall', const Color(0xFF38BDF8)),
                _cardinalInfoPill('East Wall (E)', 'Main Suite Door (SW Corridor)', const Color(0xFF10B981)),
                _cardinalInfoPill('West Wall (W)', 'Continuous Solid Feature Wall', const Color(0xFF818CF8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFurnitureManagementCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
                  Icon(Icons.chair, color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Step 3: Add & Configure Furniture Items',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Text(
                '${_placements.length} Items Configured',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Add all furniture pieces (e.g. Sofa, King Bed, Wardrobe, Desk, TV Console). Set target walls and orientations. When you finish adding everything, click the Generate button below.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Quick Preset Addition Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickFurniturePresets.map((preset) {
              return ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Color(0xFF334155)),
                avatar: const Icon(Icons.add, size: 14, color: Color(0xFF38BDF8)),
                label: Text(
                  preset['name']!,
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _addQuickPreset(preset['name']!, preset['wall']!, preset['facing']!),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Add Custom Item Row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _customItemCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter item name (e.g., 3-Seater Sofa, Sectional, Dining Table)...',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedWallForNewItem,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                      items: _cardinalWalls.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
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
                      items: ArchitecturalPromptService.facingDirectionOptions
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFacingForNewItem = val);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setState(() => _showCustomDimensionInputs = !_showCustomDimensionInputs),
                  child: Row(
                    children: [
                      Icon(
                        _showCustomDimensionInputs ? Icons.keyboard_arrow_up : Icons.tune,
                        size: 14,
                        color: const Color(0xFF38BDF8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showCustomDimensionInputs
                            ? 'Hide Custom & Amazon Dimension Overrides'
                            : 'Set Custom Dimensions / Paste Amazon Description (Optional)',
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (_showCustomDimensionInputs) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF9900), size: 15),
                            const SizedBox(width: 6),
                            const Text(
                              'Auto-Parse Amazon Description (Any Variation)',
                              style: TextStyle(color: Color(0xFFFF9900), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (_amazonParsedSummary != null)
                              Text(
                                _amazonParsedSummary!,
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amazonDescCtrl,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: const InputDecoration(
                                  hintText: 'e.g. 198.1L x 152.4W x 10.2Th Centimeter or 47.6D x 120W x 182.4H Centimeters...',
                                  hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Color(0xFF1E293B),
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide.none),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9900),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              onPressed: _parseAndApplyAmazonDescription,
                              icon: const Icon(Icons.auto_awesome, size: 14),
                              label: const Text('Parse & Fill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _miniNumField('Width (X-Span) (${_dims.unit.symbol})', _customWidthCtrl),
                      _miniNumField('Depth / Length (Y-Span) (${_dims.unit.symbol})', _customLengthCtrl),
                      _miniNumField('Height (Z-Span) (${_dims.unit.symbol})', _customHeightCtrl),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Configured Placements List
          if (_placements.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Center(
                child: Text(
                  'No items added yet. Click preset chips above or type custom furniture to add.',
                  style: TextStyle(color: Colors.white54, fontSize: 12.5),
                ),
              ),
            )
          else
            ..._placements.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131C2E),
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
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        p.facingDirection,
                        style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.itemName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          if (p.customWidth != null || p.customLength != null || p.customHeight != null)
                            Text(
                              'Custom: ${p.customWidth ?? "-"}W × ${p.customLength ?? "-"}D × ${p.customHeight ?? "-"}H ${_dims.unit.symbol}',
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF38BDF8), size: 18),
                      onPressed: () => _showEditPlacementDialog(i),
                      tooltip: 'Edit dimensions / Amazon input',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                      onPressed: () => _removeItem(i),
                      tooltip: 'Remove item',
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildGenerateActionBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF2563EB), Color(0xFF7C3AED)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isRecalibrating ? null : _performRecalibration,
        icon: _isRecalibrating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome, size: 22),
        label: Text(
          _isRecalibrating
              ? 'Recalibrating Geometry & Gaps...'
              : '⚡ Recalibrate Layout & Generate Master AI Prompt',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildRecalibrationResultsView() {
    final res = _recalibrationResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Analytics Summary Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'AI Recalibration Complete & Mathematically Validated',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: res.collisionCount == 0
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFEF4444).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      res.collisionCount == 0 ? '✓ Zero Collisions' : '⚠ ${res.collisionCount} Overlaps Resolved',
                      style: TextStyle(
                        color: res.collisionCount == 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  _metricPill('Room Footprint', res.dims.formatArea(res.totalRoomArea), const Color(0xFF38BDF8)),
                  _metricPill('Occupied Area', '${res.dims.formatArea(res.occupiedArea)} (${res.occupiedPercentage.toStringAsFixed(1)}%)', const Color(0xFFF59E0B)),
                  _metricPill('Free Carpet Area', res.dims.formatArea(res.freeCarpetArea), const Color(0xFF10B981)),
                  _metricPill('Min Walkway', res.dims.format(res.minCirculationCorridor), const Color(0xFF818CF8)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tabs & Content Card
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF38BDF8),
                labelColor: const Color(0xFF38BDF8),
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                tabs: const [
                  Tab(icon: Icon(Icons.description, size: 16), text: '🏛️ Master AI Prompt'),
                  Tab(icon: Icon(Icons.table_chart, size: 16), text: '📐 Spatial Matrix & Gaps'),
                  Tab(icon: Icon(Icons.image, size: 16), text: '🎨 3D Photorealistic Prompts'),
                  Tab(icon: Icon(Icons.architecture, size: 16), text: '📋 2D CAD Spec'),
                ],
              ),
              const Divider(color: Color(0xFF1E293B), height: 1),
              SizedBox(
                height: 520,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Full Master Prompt
                    _buildMasterPromptTab(res),
                    // Tab 2: Spatial Matrix & Gaps Breakdown
                    _buildSpatialMatrixTab(res),
                    // Tab 3: Individual 3D Renders Prompts
                    _build3DPromptsTab(res),
                    // Tab 4: 2D CAD Technical Spec
                    _buildCadSpecTab(res),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMasterPromptTab(SpatialRecalibrationResult res) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF131C2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Complete recalibrated architectural specification for 3D & 2D rendering',
                style: TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _copyToClipboard(res.masterPrompt, 'Master AI Prompt'),
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              res.masterPrompt,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12.5,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpatialMatrixTab(SpatialRecalibrationResult res) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Recalibrated Coordinates, Dimensions & Inter-Item Gaps',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),
        ...res.items.map((it) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      it.itemName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                    Text(
                      '${res.dims.format(it.width)} × ${res.dims.format(it.length)} × ${res.dims.format(it.height)}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '📍 Target: ${it.targetWall}  •  Compass: ${it.facingDirection}',
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _coordLabel('X (from West)', res.dims.format(it.x)),
                      _coordLabel('Y (from North)', res.dims.format(it.y)),
                      _coordLabel('Z (Elevation)', res.dims.format(it.z)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '🧱 Wall Gaps: North: ${it.gapToNorthWall < 0.05 ? "Flush" : res.dims.format(it.gapToNorthWall)} | South: ${it.gapToSouthWall < 0.05 ? "Flush" : res.dims.format(it.gapToSouthWall)} | West: ${it.gapToWestWall < 0.05 ? "Flush" : res.dims.format(it.gapToWestWall)} | East: ${it.gapToEastWall < 0.05 ? "Flush" : res.dims.format(it.gapToEastWall)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
                if (it.pairwiseGaps.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  const Text('🔗 Pairwise Distances to Other Placed Items:', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...it.pairwiseGaps.entries.map((entry) {
                    final other = res.items.firstWhere((o) => o.id == entry.key, orElse: () => it);
                    if (other.id == it.id) return const SizedBox.shrink();
                    return Text(
                      '  • Distance to ${other.itemName}: ${res.dims.format(entry.value)}',
                      style: const TextStyle(color: Colors.white60, fontSize: 10.5),
                    );
                  }),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _build3DPromptsTab(SpatialRecalibrationResult res) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPromptBlock(
          title: '🌟 3D Isometric Cutaway Master Plan (Midjourney v6 / Unreal 5)',
          prompt: res.midjourneyIsometricPrompt,
        ),
        const SizedBox(height: 16),
        _buildPromptBlock(
          title: '🌟 Eye-Level Cinematic Interior Perspective',
          prompt: res.midjourneyEyeLevelPrompt,
        ),
        const SizedBox(height: 16),
        _buildPromptBlock(
          title: '🌟 3D Axonometric Top-Down Spatial Layout',
          prompt: res.midjourneyTopDownPrompt,
        ),
      ],
    );
  }

  Widget _buildCadSpecTab(SpatialRecalibrationResult res) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF131C2E),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AutoCAD 2D Blueprint Coordinates & Geometry Spec', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () => _copyToClipboard(res.cadTechnicalPrompt, '2D CAD Specification'),
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copy CAD Spec', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              res.cadTechnicalPrompt,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptBlock({required String title, required String prompt}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => _copyToClipboard(prompt, title),
                icon: const Icon(Icons.copy, size: 13),
                label: const Text('Copy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            prompt,
            style: const TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordLabel(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _metricPill(String label, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _cardinalInfoPill(String wall, String desc, Color color) {
    return Column(
      children: [
        Text(wall, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11.5)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _numField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        onChanged: (_) => _applyDimensions(),
      ),
    );
  }

  Widget _miniNumField(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 10),
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
