import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../models/dynamic_floor_model.dart';
import '../models/cad_hover_detail.dart';
import '../models/architectural_design_option.dart';
import '../widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';
import '../widgets/blueprint_canvas/wall_elevation_interactive_view.dart';
import '../widgets/blueprint_canvas/cad_hover_inspector_card.dart';
import '../widgets/dialogs/design_options_modal_sheet.dart';
import '../services/blueprint_export_service.dart';
import '../services/architectural_prompt_service.dart';
import '../services/cad_hover_hit_test_service.dart';
import '../services/design_option_manager_service.dart';
import '../services/url_launcher_helper.dart';
import 'prompt_generator_screen.dart';
import 'bedroom_simulation_screen.dart';

enum BlueprintCanvasMode {
  plan2D,
  wallElevation,
}

class MainFloorExperienceScreen extends StatefulWidget {
  const MainFloorExperienceScreen({super.key});

  @override
  State<MainFloorExperienceScreen> createState() =>
      _MainFloorExperienceScreenState();
}

class _MainFloorExperienceScreenState extends State<MainFloorExperienceScreen> {
  int _currentStep = 0; // 0: Dimensions & Openings, 1: 2D CAD Blueprint Studio

  // Dimension Model
  late DynamicFloorDimensions _dims;

  // Openings state (Doors & Windows)
  final double _roomDoorWidth = 3.0; // ft
  final double _roomWindowWidth = 5.0; // ft
  final double _bathGateWidth = 2.5; // ft
  final double _bathWindowWidth = 2.0; // ft
  final double _kitchenDoorWidth = 3.0; // ft
  final double _kitchenWindowWidth = 4.0; // ft

  // 2D Studio & Wall Elevation Controls
  BlueprintCanvasMode _canvasMode = BlueprintCanvasMode.plan2D;
  String _activeWallElevationKey = 'All Walls (4-Wall Panoramic)';
  bool _showDimensions = true;
  bool _showGrid = true;
  bool _showRoomLabels = true;
  bool _isExporting = false;

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final TransformationController _transController = TransformationController();

  // Controllers for Step 1
  late TextEditingController _roomWCtrl;
  late TextEditingController _roomLCtrl;
  late TextEditingController _ceilingHCtrl;
  late TextEditingController _bathWCtrl;
  late TextEditingController _bathLCtrl;
  late TextEditingController _showerDCtrl;
  late TextEditingController _kitchWCtrl;
  late TextEditingController _kitchLCtrl;
  late TextEditingController _stairWCtrl;
  late TextEditingController _galleryWCtrl;

  // AI Master Prompt Sidebar State
  final TextEditingController _promptItemInputCtrl = TextEditingController();
  String _selectedPromptWall = 'West Wall (W)';
  String _selectedPromptFacing = 'Auto (Inward)';
  String? _selectedItemId;

  // Mouse & CAD Canvas Interaction State
  final Map<int, Offset> _activePointers = <int, Offset>{};
  Offset? _lastCentroid;
  double? _lastSpan;
  double _lastTrackpadScale = 1.0;
  String? _draggingItemId;
  String? _resizingCorner; // 'tl', 'tr', 'bl', 'br'
  Offset? _dragStartPointerPos;
  Offset? _dragStartItemPos;
  double? _dragStartWidth;
  double? _dragStartLength;
  Offset? _canvasPanStartPos;
  Matrix4? _canvasPanStartMatrix;
  CadHoverDetail? _hoverDetail;
  static const Size _canvasBaseSize = Size(1800, 1500);
  double get _canvasBaseScale => DynamicFloorDimensions.getBaseScale(_dims.unit);
  bool _isSidebarOpen = true;

  final List<String> _cardinalWallOptions = [
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

  // Placed Furniture list for current active layout
  List<RoomItemPlacement> _placements = [];

  @override
  void initState() {
    super.initState();
    final active = DesignOptionManagerService.activeDesign;
    _dims = active.dims.clone();
    _placements.clear();
    _placements.addAll(active.placements.map((p) => p.copyWith()));
    _initControllers();
  }

  void _loadDesignOption(ArchitecturalDesignOption design) {
    setState(() {
      _applyInputs();
      _dims = design.dims.clone();
      _placements.clear();
      _placements.addAll(design.placements.map((p) => p.copyWith()));
      _selectedItemId = null;
      _syncControllersWithDims();
    });
  }

  void _saveActiveDesign() {
    _applyInputs();
    final updated = DesignOptionManagerService.saveCurrentDesign(
      dims: _dims,
      placements: _placements,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Design "${updated.name}" saved successfully with all alterations!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyCurrentDesignAsNew() {
    _applyInputs();
    final active = DesignOptionManagerService.activeDesign;
    final nameCtrl = TextEditingController(text: '${active.name} (Copy)');
    final descCtrl = TextEditingController(text: 'Duplicated from "${active.name}" for custom alterations.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.copy_all, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copy to New Design Option',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Save current modified dimensions and furniture placements as a brand new design option. Your original design remains unchanged.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Design Option Name',
                  labelStyle: const TextStyle(color: Color(0xFF38BDF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes / Alterations',
                  labelStyle: const TextStyle(color: Colors.white70),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Save as New Design', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final newOpt = DesignOptionManagerService.createNewDesignOption(
                name: nameCtrl.text,
                description: descCtrl.text,
                dims: _dims,
                initialPlacements: _placements,
              );
              _loadDesignOption(newOpt);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  content: Text('Created and activated new design "${newOpt.name}"!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showCreateNewDesignDialog() {
    _applyInputs();
    final nameCtrl = TextEditingController(text: 'Design Option ${DesignOptionManagerService.designs.length + 1}');
    final descCtrl = TextEditingController();
    bool startBlank = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.add_circle, color: Color(0xFF38BDF8), size: 22),
              SizedBox(width: 10),
              Text(
                'Add New Design Option',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create an alternative design option to test and compare layout concepts.',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Design Option Name',
                    labelStyle: const TextStyle(color: Color(0xFF38BDF8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Description / Purpose',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start with empty room floor', style: TextStyle(color: Colors.white, fontSize: 13.5)),
                  subtitle: const Text('Start fresh without any furniture items', style: TextStyle(color: Colors.white54, fontSize: 11.5)),
                  value: startBlank,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (v) => setDlgState(() => startBlank = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Create & Open', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                final newOpt = DesignOptionManagerService.createNewDesignOption(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  dims: _dims,
                  initialPlacements: startBlank ? [] : _placements,
                );
                _loadDesignOption(newOpt);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFinalizeActiveDesign() {
    _applyInputs();
    final active = DesignOptionManagerService.activeDesign;
    if (active.isFinalized) {
      final unlocked = DesignOptionManagerService.unlockFinalizedDesign(active.id);
      _loadDesignOption(unlocked);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          content: Text('Plan unlocked and returned to working draft status.'),
        ),
      );
    } else {
      final notesCtrl = TextEditingController(text: 'All dimensions and 4-wall clearances verified for execution.');
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 10),
              Text(
                'Finalize & Approve Design Plan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Finalize "${active.name}". This stamps the design as verified and approved with an official seal on the high-res blueprint.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Approval & Fabrication Notes',
                    labelStyle: const TextStyle(color: Color(0xFFF59E0B)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: const Color(0xFF0F172A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.check_circle, size: 16),
              label: const Text('Finalize Plan', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                DesignOptionManagerService.saveCurrentDesign(dims: _dims, placements: _placements);
                final finOpt = DesignOptionManagerService.finalizeDesign(active.id, approvalNotes: notesCtrl.text);
                _loadDesignOption(finOpt);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                    content: Text('Plan "${finOpt.name}" is now FINALIZED & APPROVED! ✅'),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  void _showAllDesignsModal() {
    _applyInputs();
    DesignOptionsModalSheet.show(
      context,
      currentDims: _dims,
      currentPlacements: _placements,
      onDesignSelected: (selected) {
        _loadDesignOption(selected);
      },
      onStateUpdated: () {
        setState(() {});
      },
    );
  }

  void _initControllers() {
    _roomWCtrl = TextEditingController(text: _dims.roomWidth.toStringAsFixed(2));
    _roomLCtrl = TextEditingController(text: _dims.roomLength.toStringAsFixed(2));
    _ceilingHCtrl = TextEditingController(text: _dims.ceilingHeight.toStringAsFixed(2));
    _bathWCtrl = TextEditingController(text: _dims.bathWidth.toStringAsFixed(2));
    _bathLCtrl = TextEditingController(text: _dims.bathLength.toStringAsFixed(2));
    _showerDCtrl = TextEditingController(text: _dims.showerDepth.toStringAsFixed(2));
    _kitchWCtrl = TextEditingController(text: _dims.kitchenWidth.toStringAsFixed(2));
    _kitchLCtrl = TextEditingController(text: _dims.kitchenLength.toStringAsFixed(2));
    _stairWCtrl = TextEditingController(text: _dims.staircaseWidth.toStringAsFixed(2));
    _galleryWCtrl = TextEditingController(text: _dims.galleryWidth.toStringAsFixed(2));
  }

  void _syncControllersWithDims() {
    _roomWCtrl.text = _dims.roomWidth.toStringAsFixed(2);
    _roomLCtrl.text = _dims.roomLength.toStringAsFixed(2);
    _ceilingHCtrl.text = _dims.ceilingHeight.toStringAsFixed(2);
    _bathWCtrl.text = _dims.bathWidth.toStringAsFixed(2);
    _bathLCtrl.text = _dims.bathLength.toStringAsFixed(2);
    _showerDCtrl.text = _dims.showerDepth.toStringAsFixed(2);
    _kitchWCtrl.text = _dims.kitchenWidth.toStringAsFixed(2);
    _kitchLCtrl.text = _dims.kitchenLength.toStringAsFixed(2);
    _stairWCtrl.text = _dims.staircaseWidth.toStringAsFixed(2);
    _galleryWCtrl.text = _dims.galleryWidth.toStringAsFixed(2);
  }

  void _applyInputs() {
    _dims.roomWidth = double.tryParse(_roomWCtrl.text) ?? _dims.roomWidth;
    _dims.roomLength = double.tryParse(_roomLCtrl.text) ?? _dims.roomLength;
    _dims.ceilingHeight = double.tryParse(_ceilingHCtrl.text) ?? _dims.ceilingHeight;
    _dims.bathWidth = double.tryParse(_bathWCtrl.text) ?? _dims.bathWidth;
    _dims.bathLength = double.tryParse(_bathLCtrl.text) ?? _dims.bathLength;
    _dims.showerDepth = double.tryParse(_showerDCtrl.text) ?? _dims.showerDepth;
    _dims.kitchenWidth = double.tryParse(_kitchWCtrl.text) ?? _dims.kitchenWidth;
    _dims.kitchenLength = double.tryParse(_kitchLCtrl.text) ?? _dims.kitchenLength;
    _dims.staircaseWidth = double.tryParse(_stairWCtrl.text) ?? _dims.staircaseWidth;
    _dims.galleryWidth = double.tryParse(_galleryWCtrl.text) ?? _dims.galleryWidth;
  }

  void _switchDimensionUnit(DimensionUnit newUnit) {
    if (_dims.unit == newUnit) return;
    setState(() {
      _applyInputs();
      final oldUnit = _dims.unit;
      for (final p in _placements) {
        if (p.customPosX != null) {
          p.customPosX = DynamicFloorDimensions.convertValue(p.customPosX!, oldUnit, newUnit);
        }
        if (p.customPosY != null) {
          p.customPosY = DynamicFloorDimensions.convertValue(p.customPosY!, oldUnit, newUnit);
        }
        if (p.customWidth != null) {
          p.customWidth = DynamicFloorDimensions.convertValue(p.customWidth!, oldUnit, newUnit);
        }
        if (p.customLength != null) {
          p.customLength = DynamicFloorDimensions.convertValue(p.customLength!, oldUnit, newUnit);
        }
        if (p.customHeight != null) {
          p.customHeight = DynamicFloorDimensions.convertValue(p.customHeight!, oldUnit, newUnit);
        }
      }
      _dims.switchUnit(newUnit);
      _syncControllersWithDims();
    });
  }

  @override
  void dispose() {
    _roomWCtrl.dispose();
    _roomLCtrl.dispose();
    _ceilingHCtrl.dispose();
    _bathWCtrl.dispose();
    _bathLCtrl.dispose();
    _showerDCtrl.dispose();
    _kitchWCtrl.dispose();
    _kitchLCtrl.dispose();
    _stairWCtrl.dispose();
    _galleryWCtrl.dispose();
    _promptItemInputCtrl.dispose();
    super.dispose();
  }

  void _copyPromptToClipboard(String prompt) {
    Clipboard.setData(ClipboardData(text: prompt));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Master Architectural AI Prompt (2-3 2D & 3D) copied to clipboard!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBlueprint() async {
    setState(() => _isExporting = true);
    _applyInputs();
    final calculatedItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );
    final active = DesignOptionManagerService.activeDesign;

    final pngBytes = await BlueprintExportService.generateUltraHighResBlueprintSheet(
      dims: _dims,
      items: calculatedItems,
      roomName: active.name,
      isFinalized: active.isFinalized,
      finalizedAt: active.finalizedAt,
      finalizedNotes: active.finalizedNotes,
      showDimensions: _showDimensions,
      showGrid: _showGrid,
      showRoomLabels: _showRoomLabels,
    );

    String? savedPath;
    if (pngBytes != null) {
      final sanitized = active.name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final filename = 'CAD_${sanitized}_${DateTime.now().millisecondsSinceEpoch}.png';
      savedPath = await BlueprintExportService.saveFileToDisk(pngBytes, filename);
    }

    setState(() => _isExporting = false);

    if (pngBytes != null && mounted) {
      BlueprintExportService.showExportSuccessDialog(
        context,
        pngBytes,
        active.name,
        savedFilePath: savedPath,
      );
    }
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
            Icon(Icons.architecture, color: Color(0xFF38BDF8), size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'HomeCraft OS • 2D Architectural Floor CAD Planner',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9900),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _applyInputs();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => BedroomSimulationScreen(
                    dims: _dims,
                    placements: _placements,
                    initialFocusItemId: _selectedItemId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.view_in_ar, size: 16),
            label: const Text('🌟 3D Simulation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              _applyInputs();
              DesignOptionManagerService.saveCurrentDesign(dims: _dims, placements: _placements);
              _showAllDesignsModal();
            },
            icon: const Icon(Icons.folder_open, size: 16),
            label: Text(
              'Designs (${DesignOptionManagerService.designs.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => PromptGeneratorScreen(initialDims: _dims),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('AI Master Prompt (Copy)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0B1120),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _stepTab(0, '1. Dimensions & Openings', Icons.straighten),
                  _stepDivider(),
                  _stepTab(1, '2. 2D CAD Blueprint Studio', Icons.architecture),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _buildCurrentStepView(),
    );
  }

  Widget _stepTab(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return InkWell(
      onTap: () {
        _applyInputs();
        setState(() => _currentStep = stepIndex);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive
                ? const Color(0xFF38BDF8)
                : (isDone ? const Color(0xFF10B981) : Colors.transparent),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isDone ? Icons.check_circle : icon,
              color: isActive
                  ? const Color(0xFF38BDF8)
                  : (isDone ? const Color(0xFF10B981) : Colors.white38),
              size: 17,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isActive ? const Color(0xFF38BDF8) : (isDone ? Colors.white : Colors.white54),
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepDivider() {
    return Container(
      width: 40,
      height: 1.5,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: const Color(0xFF334155),
    );
  }

  Widget _buildCurrentStepView() {
    if (_currentStep == 0) {
      return _buildStep1Dimensions();
    }
    return _buildStep2Studio();
  }

  // =========================================================================
  // STEP 1: ACCURATE DIMENSIONS & OPENINGS
  // =========================================================================
  Widget _buildStep1Dimensions() {
    final unitLabel = _dims.unit.label;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card with Unit Selector
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Step 1: Enter Exact Room Dimensions & Openings',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter actual lengths of your walls, doors, windows, and circulation core in $unitLabel.',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<DimensionUnit>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: DimensionUnit.feet, label: Text('ft', style: TextStyle(fontWeight: FontWeight.bold))),
                        ButtonSegment(value: DimensionUnit.inches, label: Text('in', style: TextStyle(fontWeight: FontWeight.bold))),
                        ButtonSegment(value: DimensionUnit.meters, label: Text('m', style: TextStyle(fontWeight: FontWeight.bold))),
                        ButtonSegment(value: DimensionUnit.centimeters, label: Text('cm', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      selected: {_dims.unit},
                      onSelectionChanged: (val) {
                        if (val.isNotEmpty) {
                          _switchDimensionUnit(val.first);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Master Bedroom Dimensions & Openings
              _sectionBox(
                '🛏️ 1. Master Bedroom Suite & Openings',
                const Color(0xFF6366F1),
                [
                  _field('Total Room Width', _roomWCtrl, 'e.g. 10.5 ft'),
                  _field('Total Room Length', _roomLCtrl, 'e.g. 18.5 ft'),
                  _field('Ceiling Height', _ceilingHCtrl, 'e.g. 9.5 ft'),
                  _field('Room Door Width', TextEditingController(text: _dims.format(_roomDoorWidth)), '3.0 ft (Bottom Entry)'),
                  _field('Room Window Width', TextEditingController(text: _dims.format(_roomWindowWidth)), '5.0 ft (Top Wall)'),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Ensuite Bathroom Dimensions & Openings
              _sectionBox(
                '🚿 2. Ensuite Bathroom & Openings',
                const Color(0xFF06B6D4),
                [
                  _field('Bathroom Width', _bathWCtrl, 'e.g. 5.91 ft'),
                  _field('Bathroom Length', _bathLCtrl, 'e.g. 7.50 ft'),
                  _field('Shower Area Depth', _showerDCtrl, 'e.g. 3.01 ft (Wet Zone)'),
                  _field('Bathroom Gate Width', TextEditingController(text: _dims.format(_bathGateWidth)), '2.5 ft (Right Entry)'),
                  _field('Bathroom Window / Vent', TextEditingController(text: _dims.format(_bathWindowWidth)), '2.0 ft (Bottom Wall)'),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Modular Kitchen Dimensions & Openings
              _sectionBox(
                '🍳 3. Modular Kitchen & Openings',
                const Color(0xFFEF4444),
                [
                  _field('Kitchen Width', _kitchWCtrl, 'e.g. 7.60 ft'),
                  _field('Kitchen Length', _kitchLCtrl, 'e.g. 9.80 ft'),
                  _field('Kitchen Door Width', TextEditingController(text: _dims.format(_kitchenDoorWidth)), '3.0 ft (Staircase Hall)'),
                  _field('Kitchen Window / Vent', TextEditingController(text: _dims.format(_kitchenWindowWidth)), '4.0 ft (Top Wall)'),
                ],
              ),
              const SizedBox(height: 16),

              // 4. Staircase & Gallery Corridor
              _sectionBox(
                '🏛️ 4. Staircase Core & Long Gallery Corridor',
                const Color(0xFFF59E0B),
                [
                  _field('Staircase Core Width', _stairWCtrl, 'e.g. 4.50 ft'),
                  _field('Gallery Corridor Width', _galleryWCtrl, 'e.g. 2.80 ft (Far Right Corridor)'),
                ],
              ),
              const SizedBox(height: 24),

              // Generate Blueprint Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _applyInputs();
                    setState(() => _currentStep = 1);
                  },
                  icon: const Icon(Icons.architecture),
                  label: const Text(
                    'Generate 2D Architectural CAD Blueprint',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 2: 2D CAD BLUEPRINT STUDIO
  // =========================================================================
  // STEP 2: 2D CAD BLUEPRINT STUDIO (DEDICATED FULL SCREEN DESIGN VIEW)
  // =========================================================================
  Widget _buildStep2Studio() {
    final calculatedItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );
    final fullPrompt = ArchitecturalPromptService.generateMasterPrompt(
      dims: _dims,
      placements: _placements,
    );

    RoomItemPlacement? selectedPlacement;
    MathematicalItemDimension? selectedItemCalc;
    if (_selectedItemId != null) {
      final pIdx = _placements.indexWhere((p) => p.id == _selectedItemId);
      if (pIdx != -1) selectedPlacement = _placements[pIdx];
      final cIdx = calculatedItems.indexWhere((c) => c.id == _selectedItemId);
      if (cIdx != -1) selectedItemCalc = calculatedItems[cIdx];
    }

    return Row(
      children: [
        // Dedicated Full-Screen CAD Design View
        Expanded(
          child: _buildDesignCanvasWorkspace(calculatedItems, selectedPlacement, selectedItemCalc),
        ),

        // Dedicated Tools & Controls Side Panel
        if (_isSidebarOpen)
          _buildDedicatedStudioSidebar(calculatedItems, fullPrompt, selectedPlacement, selectedItemCalc),
      ],
    );
  }

  Widget _buildDesignCanvasWorkspace(
    List<MathematicalItemDimension> calculatedItems,
    RoomItemPlacement? selectedPlacement,
    MathematicalItemDimension? selectedItemCalc,
  ) {
    return Stack(
      children: [
        // 1. Full-Viewport Interactive Design Canvas
        Positioned.fill(
          child: _canvasMode == BlueprintCanvasMode.wallElevation
              ? WallElevationInteractiveView(
                  dims: _dims,
                  calculatedItems: calculatedItems,
                  placements: _placements,
                  activeWallKey: _activeWallElevationKey,
                  onWallSelected: (newWall) => setState(() => _activeWallElevationKey = newWall),
                  onPlacementsChanged: (updated) => setState(() => _placements = updated),
                  onExport: _exportBlueprint,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      color: Colors.white,
                      child: ClipRect(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerSignal: (signal) {
                            if (signal is PointerScrollEvent) {
                              final zoomFactor = signal.scrollDelta.dy < 0 ? 1.10 : 0.90;
                              _applyZoomAndPan(
                                scaleFactor: zoomFactor,
                                panDelta: Offset.zero,
                                focalPoint: signal.localPosition,
                              );
                            }
                          },
                          onPointerPanZoomStart: (event) {
                            _lastTrackpadScale = 1.0;
                          },
                          onPointerPanZoomUpdate: (event) {
                            final scaleDelta = _lastTrackpadScale > 0 ? (event.scale / _lastTrackpadScale) : 1.0;
                            _lastTrackpadScale = event.scale;
                            _applyZoomAndPan(
                              scaleFactor: scaleDelta,
                              panDelta: event.panDelta,
                              focalPoint: event.localPosition,
                            );
                          },
                          onPointerPanZoomEnd: (event) {
                            _lastTrackpadScale = 1.0;
                          },
                          onPointerDown: (event) {
                            _activePointers[event.pointer] = event.localPosition;
                            if (_activePointers.length >= 2) {
                              // 2-finger multi-touch active: abort any furniture dragging/resizing
                              _draggingItemId = null;
                              _resizingCorner = null;
                              _canvasPanStartPos = null;
                              _canvasPanStartMatrix = null;
                              final pointerList = _activePointers.values.toList();
                              _lastCentroid = (pointerList[0] + pointerList[1]) / 2.0;
                              _lastSpan = (pointerList[0] - pointerList[1]).distance;
                              setState(() {});
                              return;
                            }
                            final canvasPos = _screenToCanvas(event.localPosition);
                            _handleCanvasPointerDown(canvasPos, event.localPosition, calculatedItems, event.kind);
                          },
                          onPointerMove: (event) {
                            _activePointers[event.pointer] = event.localPosition;
                            if (_activePointers.length >= 2) {
                              final pointerList = _activePointers.values.toList();
                              final currentCentroid = (pointerList[0] + pointerList[1]) / 2.0;
                              final currentSpan = (pointerList[0] - pointerList[1]).distance;

                              if (_lastCentroid != null && _lastSpan != null && _lastSpan! > 5.0 && currentSpan > 5.0) {
                                final panDelta = currentCentroid - _lastCentroid!;
                                final scaleFactor = currentSpan / _lastSpan!;
                                _applyZoomAndPan(
                                  scaleFactor: scaleFactor,
                                  panDelta: panDelta,
                                  focalPoint: currentCentroid,
                                );
                              }
                              _lastCentroid = currentCentroid;
                              _lastSpan = currentSpan;
                              return;
                            }
                            final canvasPos = _screenToCanvas(event.localPosition);
                            _handleCanvasPointerMove(canvasPos, event.localPosition, calculatedItems);
                          },
                          onPointerUp: (event) {
                            _activePointers.remove(event.pointer);
                            if (_activePointers.length < 2) {
                              _lastCentroid = null;
                              _lastSpan = null;
                            }
                            if (_activePointers.isEmpty) {
                              _handleCanvasPanEnd();
                            }
                          },
                          onPointerCancel: (event) {
                            _activePointers.remove(event.pointer);
                            if (_activePointers.length < 2) {
                              _lastCentroid = null;
                              _lastSpan = null;
                            }
                            if (_activePointers.isEmpty) {
                              _handleCanvasPanEnd();
                            }
                          },
                          child: MouseRegion(
                            cursor: _getHoverCursor(),
                            onHover: (event) {
                              final canvasPos = _screenToCanvas(event.localPosition);
                              _handleCanvasHover(canvasPos, calculatedItems);
                            },
                            onExit: (_) => _handleCanvasExit(),
                            child: AnimatedBuilder(
                              animation: _transController,
                              builder: (context, child) {
                                return Transform(
                                  transform: _transController.value,
                                  child: child,
                                );
                              },
                              child: OverflowBox(
                                alignment: Alignment.topLeft,
                                minWidth: _canvasBaseSize.width,
                                maxWidth: _canvasBaseSize.width,
                                minHeight: _canvasBaseSize.height,
                                maxHeight: _canvasBaseSize.height,
                                child: RepaintBoundary(
                                  key: _repaintBoundaryKey,
                                  child: Container(
                                    width: _canvasBaseSize.width,
                                    height: _canvasBaseSize.height,
                                    color: Colors.white,
                                    child: Stack(
                                      children: [
                                        CustomPaint(
                                          painter: DynamicFloor2DPainter(
                                            dims: _dims,
                                            items: calculatedItems,
                                            selectedItemId: _selectedItemId,
                                            showDimensions: _showDimensions,
                                            showGrid: _showGrid,
                                            showRoomLabels: _showRoomLabels,
                                            isDarkMode: false,
                                            scale: _canvasBaseScale,
                                            hoveredTargetRect: _hoverDetail?.targetRect,
                                            hoveredAccentColor: _hoverDetail?.accentColor,
                                          ),
                                          size: _canvasBaseSize,
                                        ),
                                        if (_hoverDetail != null && _draggingItemId == null)
                                          CadHoverInspectorCard(
                                            detail: _hoverDetail!,
                                            canvasSize: _canvasBaseSize,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // 2. Sleek Floating Top Control Bar on Canvas
        Positioned(
          top: 14,
          left: 14,
          right: 14,
          child: _buildCanvasFloatingTopBar(),
        ),

        // 3. Selected Item Floating Quick Action HUD Toolbar
        if (selectedPlacement != null && selectedItemCalc != null)
          _buildSelectedFloatingToolbar(selectedItemCalc, selectedPlacement),

        // 4. Floating Zoom Controls
        Positioned(
          right: 16,
          bottom: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'zoom_in_btn',
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
                heroTag: 'zoom_out_btn',
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
                heroTag: 'zoom_reset_btn',
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                onPressed: () {
                  _transController.value = Matrix4.identity();
                },
                tooltip: 'Reset Center',
                child: const Icon(Icons.center_focus_strong),
              ),
            ],
          ),
        ),

        // 5. Dynamic Live Telemetry & Inspection Legend Pill
        Positioned(
          left: 16,
          bottom: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hoverDetail != null
                    ? _hoverDetail!.accentColor.withValues(alpha: 0.6)
                    : const Color(0xFF334155),
              ),
              boxShadow: _hoverDetail != null
                  ? [
                      BoxShadow(
                        color: _hoverDetail!.accentColor.withValues(alpha: 0.15),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hoverDetail?.icon ?? Icons.touch_app,
                  size: 15,
                  color: _hoverDetail?.accentColor ?? const Color(0xFF38BDF8),
                ),
                const SizedBox(width: 8),
                Text(
                  _hoverDetail != null
                      ? '[${_hoverDetail!.category}] ${_hoverDetail!.title}  •  ${_hoverDetail!.keyMetrics.entries.map((e) => "${e.key}: ${e.value}").take(2).join(" • ")}'
                      : 'Interactive 2D CAD: Hover anywhere for full details • Drag items to reposition • Drag handles to stretch',
                  style: TextStyle(
                    color: _hoverDetail != null ? Colors.white : Colors.white70,
                    fontSize: 11.0,
                    fontWeight: _hoverDetail != null ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCanvasFloatingTopBar() {
    final active = DesignOptionManagerService.activeDesign;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Active Design Option Badge & Quick Selector
            InkWell(
              onTap: _showAllDesignsModal,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.dashboard_customize, size: 15, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 8),
                    Text(
                      active.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: active.isFinalized
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        active.isFinalized ? 'Finalized' : 'Draft',
                        style: TextStyle(
                          color: active.isFinalized ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF38BDF8), size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Segmented CAD View Switcher (2D Plan vs Wall Front View)
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _topBarModeButton(
                    title: '2D Floor Plan',
                    icon: Icons.architecture,
                    isSelected: _canvasMode == BlueprintCanvasMode.plan2D,
                    onTap: () => setState(() => _canvasMode = BlueprintCanvasMode.plan2D),
                  ),
                  const SizedBox(width: 4),
                  _topBarModeButton(
                    title: 'Wall Front View',
                    icon: Icons.view_sidebar,
                    isSelected: _canvasMode == BlueprintCanvasMode.wallElevation,
                    onTap: () => setState(() => _canvasMode = BlueprintCanvasMode.wallElevation),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Right Action Buttons: Export & Full Screen Toggle
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isExporting ? null : _exportBlueprint,
                  icon: _isExporting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)))
                      : const Icon(Icons.download, size: 15),
                  label: Text(_isExporting ? 'Exporting...' : 'Export CAD Blueprint PNG', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSidebarOpen ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => setState(() => _isSidebarOpen = !_isSidebarOpen),
                  icon: Icon(_isSidebarOpen ? Icons.fullscreen : Icons.view_sidebar, size: 16),
                  label: Text(
                    _isSidebarOpen ? 'Full Screen' : 'Show Tools',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBarModeButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _screenToCanvas(Offset screenPos) {
    final Matrix4? inverse = Matrix4.tryInvert(_transController.value);
    if (inverse == null) return screenPos;
    return MatrixUtils.transformPoint(inverse, screenPos);
  }

  void _applyZoomAndPan({
    required double scaleFactor,
    required Offset panDelta,
    required Offset focalPoint,
    double minScale = 0.2,
    double maxScale = 6.0,
  }) {
    final Matrix4 matrix = _transController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    final double clampedScale = (currentScale * scaleFactor).clamp(minScale, maxScale);
    final double effectiveScale = clampedScale / currentScale;

    // 1. Pan Delta
    matrix.setEntry(0, 3, matrix.entry(0, 3) + panDelta.dx);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + panDelta.dy);

    // 2. Zoom around focalPoint
    if ((effectiveScale - 1.0).abs() > 0.0001) {
      final double tx = matrix.entry(0, 3);
      final double ty = matrix.entry(1, 3);
      final double newTx = focalPoint.dx - (focalPoint.dx - tx) * effectiveScale;
      final double newTy = focalPoint.dy - (focalPoint.dy - ty) * effectiveScale;

      matrix.scale(effectiveScale, effectiveScale, 1.0);
      matrix.setEntry(0, 3, newTx);
      matrix.setEntry(1, 3, newTy);
    }

    setState(() {
      _transController.value = matrix;
    });
  }

  void _handleCanvasPointerDown(Offset localPos, Offset globalPos, List<MathematicalItemDimension> calculatedItems, [PointerDeviceKind? kind]) {
    final rectMap = DynamicFloor2DPainter.calculateItemRects(
      dims: _dims,
      items: calculatedItems,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );
    final origin = DynamicFloor2DPainter.getOrigin(
      dims: _dims,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );

    // 1. If an item is already selected, check if touching its rotation handle, corner handles, or edge stretch handles
    if (_selectedItemId != null && rectMap.containsKey(_selectedItemId)) {
      final selectedRect = rectMap[_selectedItemId]!;
      final pIndex = _placements.indexWhere((p) => p.id == _selectedItemId);
      final p = pIndex != -1 ? _placements[pIndex] : null;

      final visualW = selectedRect.width / _canvasBaseScale;
      final visualH = selectedRect.height / _canvasBaseScale;
      final itemPosX = (selectedRect.left - origin.dx) / _canvasBaseScale;
      final itemPosY = (selectedRect.top - origin.dy) / _canvasBaseScale;

      if (p != null) {
        p.customWidth ??= double.parse(visualW.toStringAsFixed(2));
        p.customLength ??= double.parse(visualH.toStringAsFixed(2));
        p.customPosX ??= double.parse(itemPosX.toStringAsFixed(2));
        p.customPosY ??= double.parse(itemPosY.toStringAsFixed(2));
      }

      // Check Rotation Handle (Always available above or below item)
      final bool hasTopClearance = selectedRect.top - origin.dy >= 22.0;
      final rotateHandlePos = hasTopClearance
          ? Offset(selectedRect.center.dx, selectedRect.top - 18.0)
          : Offset(selectedRect.center.dx, selectedRect.bottom + 18.0);

      const handleHitRadius = 22.0;
      if ((localPos - rotateHandlePos).distance <= handleHitRadius) {
        _rotateSelectedItem();
        return;
      }

      // Check 4 Corner Resize Handles (Generous 20px hit radius for easy finger tap/drag)
      if ((localPos - selectedRect.topLeft).distance <= handleHitRadius) {
        _resizingCorner = 'tl';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.topRight).distance <= handleHitRadius) {
        _resizingCorner = 'tr';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.bottomLeft).distance <= handleHitRadius) {
        _resizingCorner = 'bl';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.bottomRight).distance <= handleHitRadius) {
        _resizingCorner = 'br';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      }

      // Check 4 Side/Edge Stretch Handles (Generous 20px hit radius)
      if ((localPos - selectedRect.topCenter).distance <= handleHitRadius) {
        _resizingCorner = 'top';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.bottomCenter).distance <= handleHitRadius) {
        _resizingCorner = 'bottom';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.centerLeft).distance <= handleHitRadius) {
        _resizingCorner = 'left';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      } else if ((localPos - selectedRect.centerRight).distance <= handleHitRadius) {
        _resizingCorner = 'right';
        _draggingItemId = _selectedItemId;
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
        _dragStartPointerPos = localPos;
        _dragStartWidth = visualW;
        _dragStartLength = visualH;
        _dragStartItemPos = Offset(itemPosX, itemPosY);
        setState(() {});
        return;
      }
    }

    // 2. Check if touching any furniture item body to start move drag
    for (int i = calculatedItems.length - 1; i >= 0; i--) {
      final item = calculatedItems[i];
      final rect = rectMap[item.id];
      if (rect != null && rect.contains(localPos)) {
        final pIndex = _placements.indexWhere((p) => p.id == item.id);
        final p = pIndex != -1 ? _placements[pIndex] : null;

        final visualW = rect.width / _canvasBaseScale;
        final visualH = rect.height / _canvasBaseScale;
        final itemPosX = (rect.left - origin.dx) / _canvasBaseScale;
        final itemPosY = (rect.top - origin.dy) / _canvasBaseScale;

        if (p != null) {
          p.customWidth ??= double.parse(visualW.toStringAsFixed(2));
          p.customLength ??= double.parse(visualH.toStringAsFixed(2));
          p.customPosX = double.parse(itemPosX.toStringAsFixed(2));
          p.customPosY = double.parse(itemPosY.toStringAsFixed(2));
        }

        setState(() {
          _selectedItemId = item.id;
          _draggingItemId = item.id;
          _resizingCorner = null;
          _canvasPanStartPos = null;
          _canvasPanStartMatrix = null;
          _dragStartPointerPos = localPos;
          _dragStartWidth = visualW;
          _dragStartLength = visualH;
          _dragStartItemPos = Offset(itemPosX, itemPosY);
        });
        return;
      }
    }

    // 2.5 Check if clicking the Room Door at the end of the room East wall (y = origin.dy + rlPx)
    final rwPx = _dims.roomWidth * _canvasBaseScale;
    final rlPx = _dims.roomLength * _canvasBaseScale;
    final bwPx = _dims.bathWidth * _canvasBaseScale;
    final roomDoorW = math.min(3.0 * _canvasBaseScale, (rwPx - bwPx) * 0.85);
    final doorPivot = Offset(origin.dx + rwPx, origin.dy + rlPx);
    final doorCenter = Offset(origin.dx + rwPx - roomDoorW / 2, origin.dy + rlPx);

    if ((localPos - doorPivot).distance <= roomDoorW + 20.0 ||
        (localPos - doorCenter).distance <= roomDoorW + 15.0) {
      setState(() {
        _dims.roomDoorSwingQuadrant = (_dims.roomDoorSwingQuadrant + 1) % 4;
      });
      final quadDescriptions = [
        'Inward NW (Into Master Bedroom)',
        'Inward SW (Into Passage / Entry Vestibule)',
        'Outward SE (Into Staircase / Corridor)',
        'Outward NE (Into Kitchen & Right Wing)',
      ];
      final desc = quadDescriptions[_dims.roomDoorSwingQuadrant % 4];
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.meeting_room, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Room Door (End of East Wall): Swung to Quadrant ${_dims.roomDoorSwingQuadrant + 1}/4: $desc',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 3. Clicked empty space on canvas -> deselect & start smooth canvas pan if mouse
    setState(() {
      _selectedItemId = null;
      _draggingItemId = null;
      _resizingCorner = null;
      if (kind == PointerDeviceKind.mouse) {
        _canvasPanStartPos = globalPos;
        _canvasPanStartMatrix = _transController.value.clone();
      } else {
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
      }
    });
  }

  void _handleCanvasPointerMove(Offset canvasPos, Offset screenPos, List<MathematicalItemDimension> calculatedItems) {
    if (_draggingItemId != null) {
      _handleRawPointerMove(canvasPos, calculatedItems);
    } else if (_canvasPanStartPos != null && _canvasPanStartMatrix != null) {
      final delta = screenPos - _canvasPanStartPos!;
      final m = _canvasPanStartMatrix!.clone();
      m.setEntry(0, 3, m.entry(0, 3) + delta.dx);
      m.setEntry(1, 3, m.entry(1, 3) + delta.dy);
      setState(() {
        _transController.value = m;
      });
    }
  }

  void _handleCanvasPanEnd() {
    setState(() {
      _draggingItemId = null;
      _resizingCorner = null;
      _dragStartPointerPos = null;
      _dragStartItemPos = null;
      _canvasPanStartPos = null;
      _canvasPanStartMatrix = null;
    });
  }

  void _handleRawPointerMove(Offset localPos, List<MathematicalItemDimension> calculatedItems) {
    if (_draggingItemId == null || _dragStartPointerPos == null || _dragStartItemPos == null) return;
    final pIndex = _placements.indexWhere((p) => p.id == _draggingItemId);
    if (pIndex == -1) return;
    final p = _placements[pIndex];
    final calcItem = calculatedItems.firstWhere((c) => c.id == _draggingItemId, orElse: () => calculatedItems.first);

    final deltaX = (localPos.dx - _dragStartPointerPos!.dx) / _canvasBaseScale;
    final deltaY = (localPos.dy - _dragStartPointerPos!.dy) / _canvasBaseScale;

    final rectMap = DynamicFloor2DPainter.calculateItemRects(
      dims: _dims,
      items: calculatedItems,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );

    if (_resizingCorner != null) {
      final baseW = _dragStartWidth ?? p.customWidth ?? calcItem.width;
      final baseL = _dragStartLength ?? p.customLength ?? calcItem.length;
      final posX = _dragStartItemPos!.dx;
      final posY = _dragStartItemPos!.dy;

      double curW = baseW;
      double curL = baseL;
      double curX = posX;
      double curY = posY;

      switch (_resizingCorner) {
        // --- 4 SIDE / EDGE HANDLES: STRICT INDEPENDENCE ---
        case 'right': // East Edge: ONLY change Breadth (X-span). Length strictly unchanged!
          curW = (baseW + deltaX).clamp(0.5, _dims.roomWidth - posX);
          curL = baseL;
          break;

        case 'left': // West Edge: ONLY change Breadth (X-span) & X position. Length strictly unchanged!
          final maxLeft = posX;
          final clampX = deltaX.clamp(-maxLeft, baseW - 0.5);
          curW = (baseW - clampX).clamp(0.5, _dims.roomWidth);
          curX = posX + clampX;
          curL = baseL;
          break;

        case 'bottom': // North Edge (Bottom): ONLY change Length (Y-span). Breadth strictly unchanged!
          curL = (baseL + deltaY).clamp(0.5, _dims.roomLength - posY);
          curW = baseW;
          break;

        case 'top': // South Edge (Top): ONLY change Length (Y-span) & Y position. Breadth strictly unchanged!
          final maxTop = posY;
          final clampY = deltaY.clamp(-maxTop, baseL - 0.5);
          curL = (baseL - clampY).clamp(0.5, _dims.roomLength);
          curY = posY + clampY;
          curW = baseW;
          break;

        // --- 4 CORNER HANDLES ---
        case 'br': // Bottom-Right: expand East (Breadth) + North (Length)
          curW = (baseW + deltaX).clamp(0.5, _dims.roomWidth - posX);
          curL = (baseL + deltaY).clamp(0.5, _dims.roomLength - posY);
          break;

        case 'bl': // Bottom-Left: expand West (Breadth) + North (Length)
          final maxL = posX;
          final clX = deltaX.clamp(-maxL, baseW - 0.5);
          curW = (baseW - clX).clamp(0.5, _dims.roomWidth);
          curX = posX + clX;
          curL = (baseL + deltaY).clamp(0.5, _dims.roomLength - posY);
          break;

        case 'tr': // Top-Right: expand East (Breadth) + South (Length)
          curW = (baseW + deltaX).clamp(0.5, _dims.roomWidth - posX);
          final maxT = posY;
          final clY = deltaY.clamp(-maxT, baseL - 0.5);
          curL = (baseL - clY).clamp(0.5, _dims.roomLength);
          curY = posY + clY;
          break;

        case 'tl': // Top-Left: expand West (Breadth) + South (Length)
          final maxTlX = posX;
          final clTlX = deltaX.clamp(-maxTlX, baseW - 0.5);
          curW = (baseW - clTlX).clamp(0.5, _dims.roomWidth);
          curX = posX + clTlX;

          final maxTlY = posY;
          final clTlY = deltaY.clamp(-maxTlY, baseL - 0.5);
          curL = (baseL - clTlY).clamp(0.5, _dims.roomLength);
          curY = posY + clTlY;
          break;
      }

      setState(() {
        p.customWidth = double.parse(curW.toStringAsFixed(2));
        p.customLength = double.parse(curL.toStringAsFixed(2));
        p.customPosX = double.parse(curX.toStringAsFixed(2));
        p.customPosY = double.parse(curY.toStringAsFixed(2));
      });
    } else {
      // Live Drag Position across floor to any wall with 0.00 margin
      final rect = rectMap[p.id];
      final itemVisualW = _dragStartWidth ?? (rect != null ? (rect.width / _canvasBaseScale) : (p.customWidth ?? calcItem.width));
      final itemVisualH = _dragStartLength ?? (rect != null ? (rect.height / _canvasBaseScale) : (p.customLength ?? calcItem.length));

      final rawTargetX = _dragStartItemPos!.dx + deltaX;
      final rawTargetY = _dragStartItemPos!.dy + deltaY;

      double newX = rawTargetX.clamp(0.0, _dims.roomWidth - itemVisualW);
      double newY = rawTargetY.clamp(0.0, _dims.roomLength - itemVisualH);

      // Snap flush to South (Top) wall with 0.00 margin if close (< 0.7 ft) or dragged to/above wall
      if (rawTargetY <= 0.0 || newY < 0.7) {
        newY = 0.0;
      } else if (rawTargetY + itemVisualH >= _dims.roomLength || (_dims.roomLength - (newY + itemVisualH)).abs() < 0.7) {
        // Snap flush to North (Bottom) wall with 0.00 margin
        newY = _dims.roomLength - itemVisualH;
      }

      // Snap flush to West (Left) or East (Right) wall independently with 0.00 margin
      if (rawTargetX <= 0.0 || newX < 0.7) {
        newX = 0.0;
      } else if (rawTargetX + itemVisualW >= _dims.roomWidth || (_dims.roomWidth - (newX + itemVisualW)).abs() < 0.7) {
        newX = _dims.roomWidth - itemVisualW;
      }

      setState(() {
        p.customWidth = itemVisualW;
        p.customLength = itemVisualH;
        p.customPosX = double.parse(newX.toStringAsFixed(2));
        p.customPosY = double.parse(newY.toStringAsFixed(2));
      });
    }
  }

  void _handleCanvasHover(Offset localPos, List<MathematicalItemDimension> calculatedItems) {
    if (_draggingItemId != null) {
      if (_hoverDetail != null) setState(() => _hoverDetail = null);
      return;
    }
    final hit = CadHoverHitTestService.hitTest(
      localPos: localPos,
      dims: _dims,
      items: calculatedItems,
      selectedItemId: _selectedItemId,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );
    if (hit?.title != _hoverDetail?.title || hit?.pointerPosition != _hoverDetail?.pointerPosition) {
      setState(() {
        _hoverDetail = hit;
      });
    }
  }

  void _handleCanvasExit() {
    if (_hoverDetail != null) {
      setState(() {
        _hoverDetail = null;
      });
    }
  }

  MouseCursor _getHoverCursor() {
    if (_hoverDetail == null) return SystemMouseCursors.basic;
    final cat = _hoverDetail!.category;
    final title = _hoverDetail!.title.toLowerCase();
    if (cat == 'CONTROL HANDLE') {
      if (title.contains('east') || title.contains('west') || title.contains('↔')) {
        return SystemMouseCursors.resizeLeftRight;
      }
      if (title.contains('north') || title.contains('south') || title.contains('↕')) {
        return SystemMouseCursors.resizeUpDown;
      }
      if (title.contains('top-left') || title.contains('bottom-right') || title.contains('↖') || title.contains('↘')) {
        return SystemMouseCursors.resizeUpLeftDownRight;
      }
      if (title.contains('top-right') || title.contains('bottom-left') || title.contains('↗') || title.contains('↙')) {
        return SystemMouseCursors.resizeUpRightDownLeft;
      }
      if (title.contains('rotate')) {
        return SystemMouseCursors.click;
      }
    }
    if (cat == 'FURNITURE ITEM') {
      return SystemMouseCursors.grab;
    }
    return SystemMouseCursors.click;
  }

  void _rotateSelectedItem() {
    if (_selectedItemId == null) return;
    final idx = _placements.indexWhere((p) => p.id == _selectedItemId);
    if (idx == -1) return;
    final p = _placements[idx];

    final calculatedItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );
    final rectMap = DynamicFloor2DPainter.calculateItemRects(
      dims: _dims,
      items: calculatedItems,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );
    final origin = DynamicFloor2DPainter.getOrigin(
      dims: _dims,
      canvasSize: _canvasBaseSize,
      scale: _canvasBaseScale,
    );

    final rect = rectMap[p.id];
    final curVisualW = rect != null ? (rect.width / _canvasBaseScale) : (p.customWidth ?? 6.0);
    final curVisualH = rect != null ? (rect.height / _canvasBaseScale) : (p.customLength ?? 6.5);
    final curVisualX = rect != null ? ((rect.left - origin.dx) / _canvasBaseScale) : (p.customPosX ?? 0.0);
    final curVisualY = rect != null ? ((rect.top - origin.dy) / _canvasBaseScale) : (p.customPosY ?? 0.0);

    setState(() {
      p.rotationDegrees = (p.rotationDegrees + 90) % 360;

      // Swap width and length for visual 90-degree turn
      p.customWidth = double.parse(curVisualH.toStringAsFixed(2));
      p.customLength = double.parse(curVisualW.toStringAsFixed(2));

      // Rotate facing direction cyclically
      switch (p.rotationDegrees) {
        case 0:
          p.facingDirection = 'Facing South (↓)';
          break;
        case 90:
          p.facingDirection = 'Facing West (←)';
          break;
        case 180:
          p.facingDirection = 'Facing North (↑)';
          break;
        case 270:
          p.facingDirection = 'Facing East (→)';
          break;
      }

      // Clamp new position so item stays inside the room boundaries
      p.customPosX = double.parse(curVisualX.clamp(0.0, (_dims.roomWidth - p.customWidth!).clamp(0.0, _dims.roomWidth)).toStringAsFixed(2));
      p.customPosY = double.parse(curVisualY.clamp(0.0, (_dims.roomLength - p.customLength!).clamp(0.0, _dims.roomLength)).toStringAsFixed(2));
    });
  }

  Widget _buildSelectedFloatingToolbar(
    MathematicalItemDimension selectedItemCalc,
    RoomItemPlacement selectedPlacement,
  ) {
    final pIndex = _placements.indexWhere((p) => p.id == selectedPlacement.id);
    if (pIndex == -1) return const SizedBox.shrink();

    final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
    final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
    final curPosX = selectedPlacement.customPosX ?? 0.0;
    final curPosY = selectedPlacement.customPosY ?? 0.0;
    final curRotation = selectedPlacement.rotationDegrees;

    return Positioned(
      top: 68,
      left: 14,
      right: 14,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Item Name Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.touch_app, size: 15, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 6),
                      Text(
                        selectedPlacement.itemName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 1. Breadth / Width Stepper (↔)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('↔ Breadth: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                            final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                            selectedPlacement.customWidth = double.parse((curBreadth - step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                            selectedPlacement.customLength = curLength;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF38BDF8)),
                        ),
                      ),
                      Text(
                        _dims.format(curBreadth),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                            final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                            selectedPlacement.customWidth = double.parse((curBreadth + step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                            selectedPlacement.customLength = curLength;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF38BDF8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Length / Span Stepper (↕)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('↕ Length: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                            final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                            selectedPlacement.customLength = double.parse((curLength - step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                            selectedPlacement.customWidth = curBreadth;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF10B981)),
                        ),
                      ),
                      Text(
                        _dims.format(curLength),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                            final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                            selectedPlacement.customLength = double.parse((curLength + step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                            selectedPlacement.customWidth = curBreadth;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 3. Position X Stepper (📍 Pos X)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📍 Pos X: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                            final maxX = (_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth);
                            selectedPlacement.customPosX = double.parse((curPosX - step).clamp(0.0, maxX).toStringAsFixed(2));
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.arrow_left, size: 18, color: Color(0xFF818CF8)),
                        ),
                      ),
                      Text(
                        _dims.format(curPosX),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                            final maxX = (_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth);
                            selectedPlacement.customPosX = double.parse((curPosX + step).clamp(0.0, maxX).toStringAsFixed(2));
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.arrow_right, size: 18, color: Color(0xFF818CF8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 4. Position Y Stepper (📍 Pos Y)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('📍 Pos Y: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                            final maxY = (_dims.roomLength - curLength).clamp(0.0, _dims.roomLength);
                            selectedPlacement.customPosY = double.parse((curPosY - step).clamp(0.0, maxY).toStringAsFixed(2));
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.arrow_drop_up, size: 18, color: Color(0xFFF43F5E)),
                        ),
                      ),
                      Text(
                        _dims.format(curPosY),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                            final maxY = (_dims.roomLength - curLength).clamp(0.0, _dims.roomLength);
                            selectedPlacement.customPosY = double.parse((curPosY + step).clamp(0.0, maxY).toStringAsFixed(2));
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFFF43F5E)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 5. Rotation Controls (↺ Rotate 90°)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: InkWell(
                    onTap: _rotateSelectedItem,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.8)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.rotate_right, size: 15, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            '$curRotation° (↺ 90°)',
                            style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 6. Quick Flush Wall Snapping (0.00' Margin)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Snap: ', style: TextStyle(color: Colors.white60, fontSize: 10.5, fontWeight: FontWeight.bold)),
                      _flushSnapButton(
                        label: '⬆ South (0\')',
                        tooltip: 'Snap Flush to South Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosY = 0.0;
                            selectedPlacement.targetWall = 'South Wall (S)';
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: '⬇ North (0\')',
                        tooltip: 'Snap Flush to North Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosY = double.parse((_dims.roomLength - curLength).clamp(0.0, _dims.roomLength).toStringAsFixed(2));
                            selectedPlacement.targetWall = 'North Wall (N)';
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: '⬅ West (0\')',
                        tooltip: 'Snap Flush to West Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosX = 0.0;
                            selectedPlacement.targetWall = 'West Wall (W)';
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: '➡ East (0\')',
                        tooltip: 'Snap Flush to East Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosX = double.parse((_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth).toStringAsFixed(2));
                            selectedPlacement.targetWall = 'East Wall (E)';
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: '🎯 Center',
                        tooltip: 'Center in Master Bedroom',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosX = double.parse(((_dims.roomWidth - curBreadth) / 2.0).clamp(0.0, _dims.roomWidth).toStringAsFixed(2));
                            selectedPlacement.customPosY = double.parse(((_dims.roomLength - curLength) / 2.0).clamp(0.0, _dims.roomLength).toStringAsFixed(2));
                            selectedPlacement.targetWall = 'Center Floor';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 7. Edit Specs Dialog & Action Buttons
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showEditItemDimensionDialog(pIndex, selectedItemCalc),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Edit Specs', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),

                // Amazon Product Quick Action
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF9900).withValues(alpha: 0.2),
                    foregroundColor: const Color(0xFFFF9900),
                    side: const BorderSide(color: Color(0xFFFF9900), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (selectedPlacement.amazonUrl != null && selectedPlacement.amazonUrl!.trim().isNotEmpty) {
                      UrlLauncherHelper.openUrl(selectedPlacement.amazonUrl!);
                    } else {
                      _showEditItemDimensionDialog(pIndex, selectedItemCalc);
                    }
                  },
                  icon: Icon(
                    selectedPlacement.amazonUrl != null && selectedPlacement.amazonUrl!.trim().isNotEmpty
                        ? Icons.open_in_new
                        : Icons.add_link,
                    size: 14,
                  ),
                  label: Text(
                    selectedPlacement.amazonUrl != null && selectedPlacement.amazonUrl!.trim().isNotEmpty
                        ? 'Open Amazon'
                        : 'Amazon Link',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 6),

                // 3D Simulation Quick Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFFFF9900),
                    side: const BorderSide(color: Color(0xFFFF9900), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    _applyInputs();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BedroomSimulationScreen(
                          dims: _dims,
                          placements: _placements,
                          initialFocusItemId: selectedPlacement.id,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.view_in_ar, size: 14),
                  label: const Text('Simulate in 3D', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),

                // Duplicate Item Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981), width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final newId = 'item_${DateTime.now().millisecondsSinceEpoch}';
                    final copy = selectedPlacement.copyWith(
                      id: newId,
                      itemName: '${selectedPlacement.itemName} (Copy)',
                      customPosX: ((selectedPlacement.customPosX ?? 0.0) + 1.0).clamp(0.0, _dims.roomWidth - curBreadth),
                      customPosY: ((selectedPlacement.customPosY ?? 0.0) + 1.0).clamp(0.0, _dims.roomLength - curLength),
                    );
                    setState(() {
                      _placements.add(copy);
                      _selectedItemId = newId;
                    });
                  },
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Duplicate', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 6),

                // Delete Item Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                  tooltip: 'Delete Item',
                  onPressed: () {
                    setState(() {
                      _placements.removeAt(pIndex);
                      _selectedItemId = null;
                    });
                  },
                ),
                const SizedBox(width: 4),

                // Close / Deselect Button
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                  tooltip: 'Deselect Item',
                  onPressed: () => setState(() => _selectedItemId = null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _flushSnapButton({
    required String label,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _showEditItemDimensionDialog(int index, MathematicalItemDimension calc) {
    if (index >= _placements.length) return;
    final p = _placements[index];

    final nameCtrl = TextEditingController(text: p.itemName);
    final widthCtrl = TextEditingController(
        text: (p.customWidth ?? calc.width).toStringAsFixed(2));
    final lengthCtrl = TextEditingController(
        text: (p.customLength ?? calc.length).toStringAsFixed(2));
    final heightCtrl = TextEditingController(
        text: (p.customHeight ?? calc.height).toStringAsFixed(2));
    final notesCtrl = TextEditingController(text: p.customNotes ?? '');
    final amazonUrlCtrl = TextEditingController(text: p.amazonUrl ?? '');
    final imageUrlCtrl = TextEditingController(text: p.imageUrl ?? '');
    final priceCtrl = TextEditingController(text: p.productPrice ?? '');
    String selectedWall = p.targetWall;
    String selectedFacing = p.facingDirection;
    int selectedRotation = p.rotationDegrees;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final hasAmazonUrl = amazonUrlCtrl.text.trim().isNotEmpty;
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Dimension: ${p.itemName}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Change dimensions, Amazon product link, and wall attachment/orientation.',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Item Name
                      TextField(
                        controller: nameCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Item Name / Description',
                          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Amazon Product Link & Instant Open Button
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: hasAmazonUrl ? const Color(0xFFFF9900).withValues(alpha: 0.6) : Colors.transparent),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Color(0xFFFF9900), size: 16),
                                const SizedBox(width: 6),
                                const Text('Amazon Product Link (Optional)', style: TextStyle(color: Color(0xFFFF9900), fontSize: 11.5, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                if (hasAmazonUrl)
                                  InkWell(
                                    onTap: () => UrlLauncherHelper.openUrl(amazonUrlCtrl.text.trim()),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF9900),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.open_in_new, size: 11, color: Colors.black),
                                          SizedBox(width: 3),
                                          Text('Open in New Tab', style: TextStyle(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: amazonUrlCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: 'https://www.amazon.com/dp/...',
                                hintStyle: TextStyle(color: Colors.white30, fontSize: 11),
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 4),
                                border: InputBorder.none,
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Direct Product Image URL & Price Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: imageUrlCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Product Image URL (Optional)',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                hintText: 'https://m.media-amazon.com/...',
                                hintStyle: const TextStyle(color: Colors.white24, fontSize: 10.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: priceCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                labelText: 'Price (e.g. \$299)',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Target Wall / Corner Dropdown
                      DropdownButtonFormField<String>(
                        value: _cardinalWallOptions.contains(selectedWall) ? selectedWall : _cardinalWallOptions.first,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12.5, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Attached Wall / Corner Placement',
                          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                        items: _cardinalWallOptions.map((w) {
                          return DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedWall = val;
                              selectedFacing = ArchitecturalPromptService.defaultFacingForWall(val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Facing Direction & Rotation Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: ArchitecturalPromptService.facingDirectionOptions.contains(selectedFacing)
                                  ? selectedFacing
                                  : ArchitecturalPromptService.facingDirectionOptions.first,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Facing Direction (Where to Face)',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              items: ArchitecturalPromptService.facingDirectionOptions.map((f) {
                                return DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedFacing = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              value: ArchitecturalPromptService.rotationOptions.contains(selectedRotation)
                                  ? selectedRotation
                                  : 0,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Rotation',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                              items: ArchitecturalPromptService.rotationOptions.map((r) {
                                return DropdownMenuItem(value: r, child: Text('$r°'));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedRotation = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Width, Length/Depth, Height fields
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: widthCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Width (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: lengthCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Length (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: heightCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                labelText: 'Height (${_dims.unit.symbol})',
                                labelStyle: const TextStyle(color: Colors.white70, fontSize: 11.5),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Custom Notes / Placement description
                      TextField(
                        controller: notesCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Custom Notes / Ergonomic Details',
                          labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
                          hintText: 'e.g. Corner aligned with 3ft walkway, floating base...',
                          hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _placements[index] = p.copyWith(
                        customWidth: null,
                        customLength: null,
                        customHeight: null,
                        facingDirection: ArchitecturalPromptService.defaultFacingForWall(selectedWall),
                        rotationDegrees: 0,
                      );
                    });
                    Navigator.of(dialogCtx).pop();
                  },
                  icon: const Icon(Icons.refresh, size: 15, color: Color(0xFFF59E0B)),
                  label: const Text('Reset to AI Math', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 12)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final newW = double.tryParse(widthCtrl.text);
                    final newL = double.tryParse(lengthCtrl.text);
                    final newH = double.tryParse(heightCtrl.text);
                    final newName = nameCtrl.text.trim();

                    setState(() {
                      _placements[index] = p.copyWith(
                        itemName: newName.isNotEmpty ? newName : p.itemName,
                        targetWall: selectedWall,
                        facingDirection: selectedFacing,
                        rotationDegrees: selectedRotation,
                        customWidth: newW,
                        customLength: newL,
                        customHeight: newH,
                        customNotes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : p.customNotes,
                        amazonUrl: amazonUrlCtrl.text.trim().isNotEmpty ? amazonUrlCtrl.text.trim() : null,
                        imageUrl: imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null,
                        productPrice: priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null,
                      );
                    });
                    Navigator.of(dialogCtx).pop();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSidebarItemInspector(
    RoomItemPlacement selectedPlacement,
    MathematicalItemDimension selectedItemCalc,
  ) {
    final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
    final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
    final curPosX = selectedPlacement.customPosX ?? 0.0;
    final curPosY = selectedPlacement.customPosY ?? 0.0;
    final curRotation = selectedPlacement.rotationDegrees;
    final itemColor = DynamicFloor2DPainter.getItemColor(selectedPlacement.id, selectedPlacement.itemName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Color chip + Name + Deselect
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: itemColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selectedPlacement.itemName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () => setState(() => _selectedItemId = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Deselect', style: TextStyle(color: Colors.white60, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Dimensions (Breadth & Length)
          Row(
            children: [
              // Breadth
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('↔ Breadth', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                                final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                                selectedPlacement.customWidth = double.parse((curBreadth - step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                                selectedPlacement.customLength = curLength;
                              });
                            },
                            child: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF38BDF8)),
                          ),
                          Text(
                            _dims.format(curBreadth),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                                final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                                selectedPlacement.customWidth = double.parse((curBreadth + step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                                selectedPlacement.customLength = curLength;
                              });
                            },
                            child: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF38BDF8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Length
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('↕ Length', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                                final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                                selectedPlacement.customLength = double.parse((curLength - step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                                selectedPlacement.customWidth = curBreadth;
                              });
                            },
                            child: const Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF10B981)),
                          ),
                          Text(
                            _dims.format(curLength),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                                final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                                selectedPlacement.customLength = double.parse((curLength + step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                                selectedPlacement.customWidth = curBreadth;
                              });
                            },
                            child: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Position Controls (X & Y)
          Row(
            children: [
              // Pos X
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📍 Pos X', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                                final maxX = (_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth);
                                selectedPlacement.customPosX = double.parse((curPosX - step).clamp(0.0, maxX).toStringAsFixed(2));
                              });
                            },
                            child: const Icon(Icons.arrow_left, size: 18, color: Color(0xFF818CF8)),
                          ),
                          Text(
                            _dims.format(curPosX),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                                final maxX = (_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth);
                                selectedPlacement.customPosX = double.parse((curPosX + step).clamp(0.0, maxX).toStringAsFixed(2));
                              });
                            },
                            child: const Icon(Icons.arrow_right, size: 18, color: Color(0xFF818CF8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Pos Y
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📍 Pos Y', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                                final maxY = (_dims.roomLength - curLength).clamp(0.0, _dims.roomLength);
                                selectedPlacement.customPosY = double.parse((curPosY - step).clamp(0.0, maxY).toStringAsFixed(2));
                              });
                            },
                            child: const Icon(Icons.arrow_drop_up, size: 18, color: Color(0xFFF43F5E)),
                          ),
                          Text(
                            _dims.format(curPosY),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                                final maxY = (_dims.roomLength - curLength).clamp(0.0, _dims.roomLength);
                                selectedPlacement.customPosY = double.parse((curPosY + step).clamp(0.0, maxY).toStringAsFixed(2));
                              });
                            },
                            child: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFFF43F5E)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Rotation Button
          InkWell(
            onTap: _rotateSelectedItem,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rotate_right, size: 14, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 4),
                  Text('Rotate: $curRotation° (↺ 90°)', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Wall Flush Snap Buttons
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _flushSnapButton(
                label: '⬆ South (0\')',
                tooltip: 'Snap Flush to South Wall (0.00 Margin)',
                onTap: () {
                  setState(() {
                    selectedPlacement.customPosY = 0.0;
                    selectedPlacement.targetWall = 'South Wall (S)';
                  });
                },
              ),
              _flushSnapButton(
                label: '⬇ North (0\')',
                tooltip: 'Snap Flush to North Wall (0.00 Margin)',
                onTap: () {
                  setState(() {
                    selectedPlacement.customPosY = double.parse((_dims.roomLength - curLength).clamp(0.0, _dims.roomLength).toStringAsFixed(2));
                    selectedPlacement.targetWall = 'North Wall (N)';
                  });
                },
              ),
              _flushSnapButton(
                label: '⬅ West (0\')',
                tooltip: 'Snap Flush to West Wall (0.00 Margin)',
                onTap: () {
                  setState(() {
                    selectedPlacement.customPosX = 0.0;
                    selectedPlacement.targetWall = 'West Wall (W)';
                  });
                },
              ),
              _flushSnapButton(
                label: '➡ East (0\')',
                tooltip: 'Snap Flush to East Wall (0.00 Margin)',
                onTap: () {
                  setState(() {
                    selectedPlacement.customPosX = double.parse((_dims.roomWidth - curBreadth).clamp(0.0, _dims.roomWidth).toStringAsFixed(2));
                    selectedPlacement.targetWall = 'East Wall (E)';
                  });
                },
              ),
              _flushSnapButton(
                label: '🎯 Center',
                tooltip: 'Center in Room',
                onTap: () {
                  setState(() {
                    selectedPlacement.customPosX = double.parse(((_dims.roomWidth - curBreadth) / 2).clamp(0.0, _dims.roomWidth).toStringAsFixed(2));
                    selectedPlacement.customPosY = double.parse(((_dims.roomLength - curLength) / 2).clamp(0.0, _dims.roomLength).toStringAsFixed(2));
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDedicatedStudioSidebar(
    List<MathematicalItemDimension> calculatedItems,
    String fullPrompt,
    RoomItemPlacement? selectedPlacement,
    MathematicalItemDimension? selectedItemCalc,
  ) {
    final active = DesignOptionManagerService.activeDesign;

    return Container(
      width: 420,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(left: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Sidebar Header with collapse button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Studio Controls & Specs',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                tooltip: 'Collapse Sidebar (Full Screen Canvas)',
                onPressed: () => setState(() => _isSidebarOpen = false),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // SELECTED ITEM INSPECTOR (Shown whenever an item is clicked/selected)
          if (selectedPlacement != null && selectedItemCalc != null)
            _buildSidebarItemInspector(selectedPlacement, selectedItemCalc),

          // SECTION 1: Design Options & Finalization Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Design Options',
                      style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: active.isFinalized
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        active.isFinalized ? 'Finalized' : 'Active Draft',
                        style: TextStyle(
                          color: active.isFinalized ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _showAllDesignsModal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_open, size: 16, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            active.name,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _saveActiveDesign,
                      icon: const Icon(Icons.save, size: 13),
                      label: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _copyCurrentDesignAsNew,
                      icon: const Icon(Icons.copy_all, size: 13),
                      label: const Text('Duplicate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _showCreateNewDesignDialog,
                      icon: const Icon(Icons.add, size: 13),
                      label: const Text('+ New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: active.isFinalized ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: _toggleFinalizeActiveDesign,
                      icon: Icon(active.isFinalized ? Icons.check_circle : Icons.task_alt, size: 13),
                      label: Text(
                        active.isFinalized ? 'Finalized' : 'Finalize',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // SECTION 2: CAD Layers & Dimension Units Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CAD Layers & Dimension Units',
                  style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _sidebarToggleChip(
                      label: 'Rulers & Dims',
                      icon: Icons.straighten,
                      isActive: _showDimensions,
                      onTap: () => setState(() => _showDimensions = !_showDimensions),
                    ),
                    _sidebarToggleChip(
                      label: 'CAD Grid',
                      icon: Icons.grid_on,
                      isActive: _showGrid,
                      onTap: () => setState(() => _showGrid = !_showGrid),
                    ),
                    _sidebarToggleChip(
                      label: 'Room Stamps & Areas',
                      icon: Icons.tag,
                      isActive: _showRoomLabels,
                      onTap: () => setState(() => _showRoomLabels = !_showRoomLabels),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Active CAD Unit:',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _sidebarUnitSegment('ft', DimensionUnit.feet),
                    const SizedBox(width: 4),
                    _sidebarUnitSegment('in', DimensionUnit.inches),
                    const SizedBox(width: 4),
                    _sidebarUnitSegment('m', DimensionUnit.meters),
                    const SizedBox(width: 4),
                    _sidebarUnitSegment('cm', DimensionUnit.centimeters),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // SECTION 3: Selected Furniture Quick Inspector
          if (selectedPlacement != null && selectedItemCalc != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.touch_app, color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                selectedPlacement.itemName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 18),
                        tooltip: 'Delete Item',
                        onPressed: () {
                          setState(() {
                            _placements.removeWhere((p) => p.id == selectedPlacement.id);
                            _selectedItemId = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Steppers for breadth and length
                  Row(
                    children: [
                      Expanded(
                        child: _buildSidebarStepper(
                          label: '↔ Breadth',
                          value: _dims.format(selectedPlacement.customWidth ?? selectedItemCalc.width),
                          onMinus: () {
                            setState(() {
                              final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
                              final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
                              final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                              final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                              selectedPlacement.customWidth = double.parse((curBreadth - step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                              selectedPlacement.customLength = curLength;
                            });
                          },
                          onPlus: () {
                            setState(() {
                              final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
                              final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
                              final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: false);
                              final minVal = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, _dims.unit);
                              selectedPlacement.customWidth = double.parse((curBreadth + step).clamp(minVal, _dims.roomWidth).toStringAsFixed(2));
                              selectedPlacement.customLength = curLength;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSidebarStepper(
                          label: '↕ Length',
                          value: _dims.format(selectedPlacement.customLength ?? selectedItemCalc.length),
                          onMinus: () {
                            setState(() {
                              final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
                              final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
                              final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                              final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                              selectedPlacement.customLength = double.parse((curLength - step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                              selectedPlacement.customWidth = curBreadth;
                            });
                          },
                          onPlus: () {
                            setState(() {
                              final curBreadth = selectedPlacement.customWidth ?? selectedItemCalc.width;
                              final curLength = selectedPlacement.customLength ?? selectedItemCalc.length;
                              final step = DynamicFloorDimensions.getStepperStep(_dims.unit, isLength: true);
                              final minVal = DynamicFloorDimensions.convertValue(1.0, DimensionUnit.feet, _dims.unit);
                              selectedPlacement.customLength = double.parse((curLength + step).clamp(minVal, _dims.roomLength).toStringAsFixed(2));
                              selectedPlacement.customWidth = curBreadth;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rotation and Flush Snap Buttons
                  Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFFF59E0B),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _rotateSelectedItem,
                        icon: const Icon(Icons.rotate_right, size: 14),
                        label: const Text('Rotate 90°', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedPlacement.facingDirection,
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Quick Flush Wall Snapping (0.00 Margin):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _flushSnapButton(
                        label: 'South (0\')',
                        tooltip: 'Snap Flush to South Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            final itemLen = selectedPlacement.customLength ?? selectedItemCalc.length;
                            selectedPlacement.customPosY = _dims.roomLength - itemLen;
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: 'North (0\')',
                        tooltip: 'Snap Flush to North Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosY = 0.0;
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: 'West (0\')',
                        tooltip: 'Snap Flush to West Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            selectedPlacement.customPosX = 0.0;
                          });
                        },
                      ),
                      _flushSnapButton(
                        label: 'East (0\')',
                        tooltip: 'Snap Flush to East Wall (0.00 Margin)',
                        onTap: () {
                          setState(() {
                            final itemW = selectedPlacement.customWidth ?? selectedItemCalc.width;
                            selectedPlacement.customPosX = _dims.roomWidth - itemW;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // SECTION 4: AI Master Prompt & Items Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI Master Prompt',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _copyPromptToClipboard(fullPrompt),
                icon: const Icon(Icons.copy, size: 13),
                label: const Text('Copy Prompt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Cardinal Walls (N, S, E, W) Specs Pill Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.explore, color: Color(0xFF38BDF8), size: 15),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cardinal Walls Matrix (N, S, E, W)',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.spaceAround,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _cardinalPill('N', 'North (Bottom)', _dims.format(_dims.totalWidth), const Color(0xFFEF4444)),
                    _cardinalPill('S', 'South (Top)', _dims.format(_dims.totalWidth), const Color(0xFF38BDF8)),
                    _cardinalPill('E', 'East (Right)', _dims.format(_dims.totalLength), const Color(0xFF10B981)),
                    _cardinalPill('W', 'West (Left)', _dims.format(_dims.totalLength), const Color(0xFF818CF8)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Add / Assign Item to Cardinal Wall
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe Item & Position (N, S, E, W, Corners)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Items are drawn live on the 2D CAD blueprint and sized via spatial math.',
                  style: TextStyle(color: Colors.white60, fontSize: 10.5),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _promptItemInputCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'e.g. King Bed, Study Table, Wardrobe, Recliner...',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedPromptWall,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          items: _cardinalWallOptions.map((w) {
                            return DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedPromptWall = val;
                                _selectedPromptFacing = ArchitecturalPromptService.defaultFacingForWall(val);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: ArchitecturalPromptService.facingDirectionOptions.contains(_selectedPromptFacing)
                              ? _selectedPromptFacing
                              : ArchitecturalPromptService.facingDirectionOptions.first,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          items: ArchitecturalPromptService.facingDirectionOptions.map((f) {
                            return DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPromptFacing = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final raw = _promptItemInputCtrl.text.trim();
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
                                targetWall: _selectedPromptWall,
                                facingDirection: _selectedPromptFacing,
                              ));
                            }
                            _promptItemInputCtrl.clear();
                          });
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14),
                          SizedBox(width: 2),
                          Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Mathematical Items Dimension Breakdown
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: Color(0xFFF59E0B), size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Calculated Items & Live Design (Click to Edit)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (calculatedItems.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.add_home_outlined, color: Color(0xFF38BDF8), size: 30),
                  SizedBox(height: 8),
                  Text(
                    'No Items Added Yet',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Type any furniture or fixture above and choose its wall or corner to place it on the 2D CAD blueprint.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ...calculatedItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            return InkWell(
              onTap: () {
                setState(() => _selectedItemId = item.id);
                _showEditItemDimensionDialog(idx, item);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131C2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedItemId == item.id ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                    width: _selectedItemId == item.id ? 1.5 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.targetWall,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.facingDirection,
                                  style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 9.5),
                                ),
                              ),
                              Text(
                                item.itemName,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.isCustom)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('Custom', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.edit, size: 14, color: Color(0xFF38BDF8)),
                              tooltip: 'Edit Dimension',
                              onPressed: () => _showEditItemDimensionDialog(idx, item),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              icon: const Icon(Icons.close, size: 14, color: Colors.white38),
                              tooltip: 'Remove',
                              onPressed: () {
                                setState(() {
                                  if (idx < _placements.length) {
                                    _placements.removeAt(idx);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 2,
                      children: [
                        Text(
                          'Size: ${_dims.format(item.width)} × ${_dims.format(item.length)} × ${_dims.format(item.height)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          'Buffer: ${_dims.format(item.clearance)}',
                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 10.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.formula,
                      style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // 4. Live Copyable Prompt Output Area
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B1120),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.terminal, color: Color(0xFF38BDF8), size: 15),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Prompt Preview (2-3 2D & 3D)',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => _copyPromptToClipboard(fullPrompt),
                      child: const Row(
                        children: [
                          Icon(Icons.copy, size: 13, color: Color(0xFF38BDF8)),
                          SizedBox(width: 4),
                          Text('Copy', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF1E293B), height: 16),
                SizedBox(
                  height: 200,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      fullPrompt,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Bottom Full-Width Copy Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _copyPromptToClipboard(fullPrompt),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text(
                'Copy Master AI Prompt (2-3 2D & 3D)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarToggleChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF334155),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFF10B981) : Colors.white60,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFF10B981) : Colors.white70,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarUnitSegment(String label, DimensionUnit unit) {
    final isSelected = _dims.unit == unit;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _dims.unit = unit;
          });
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarStepper({
    required String label,
    required String value,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: onMinus,
                child: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFF38BDF8)),
              ),
              Text(
                value,
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
              ),
              InkWell(
                onTap: onPlus,
                child: const Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF38BDF8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardinalPill(String code, String name, String dim, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            '[$code] $dim',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(color: Colors.white54, fontSize: 9.5),
        ),
      ],
    );
  }

  Widget _sectionBox(String title, Color color, List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: fields,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
