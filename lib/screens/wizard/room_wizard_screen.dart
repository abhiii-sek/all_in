import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../../models/room_item.dart';
import '../../models/wall_opening.dart';
import '../../services/project_state.dart';
import '../../widgets/common/inspiration_image_picker.dart';

class RoomWizardScreen extends StatefulWidget {
  final ProjectState projectState;
  final RoomModel? existingRoom;

  const RoomWizardScreen({
    super.key,
    required this.projectState,
    this.existingRoom,
  });

  @override
  State<RoomWizardScreen> createState() => _RoomWizardScreenState();
}

class _RoomWizardScreenState extends State<RoomWizardScreen> {
  int _currentStep = 0;

  // Controllers for Step 1
  late TextEditingController _nameController;
  late RoomType _selectedType;
  late TextEditingController _wallTopCtrl;
  late TextEditingController _wallRightCtrl;
  late TextEditingController _wallBottomCtrl;
  late TextEditingController _wallLeftCtrl;
  late TextEditingController _ceilingHeightCtrl;

  // Openings for Step 2
  int _doorWallIndex = 2; // Bottom wall
  late TextEditingController _doorWidthCtrl;
  late TextEditingController _doorOffsetCtrl;
  final DoorSwing _doorSwing = DoorSwing.inwardLeft;

  int _winWallIndex = 0; // Top wall
  late TextEditingController _winWidthCtrl;
  late TextEditingController _winOffsetCtrl;
  late TextEditingController _winSillCtrl;

  // Items for Step 3
  final List<RoomItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    final r = widget.existingRoom;
    _nameController = TextEditingController(text: r?.name ?? 'Master Bedroom');
    _selectedType = r?.roomType ?? RoomType.bedroom;
    _wallTopCtrl = TextEditingController(text: (r?.wallTop ?? 4.2).toString());
    _wallRightCtrl = TextEditingController(text: (r?.wallRight ?? 3.6).toString());
    _wallBottomCtrl = TextEditingController(text: (r?.wallBottom ?? 4.2).toString());
    _wallLeftCtrl = TextEditingController(text: (r?.wallLeft ?? 3.6).toString());
    _ceilingHeightCtrl = TextEditingController(text: (r?.ceilingHeight ?? 2.9).toString());

    _doorWidthCtrl = TextEditingController(text: '0.9');
    _doorOffsetCtrl = TextEditingController(text: '0.3');
    _winWidthCtrl = TextEditingController(text: '1.5');
    _winOffsetCtrl = TextEditingController(text: '0.8');
    _winSillCtrl = TextEditingController(text: '0.9');

    _populateDefaultItemsForType(_selectedType);
  }

  void _populateDefaultItemsForType(RoomType type) {
    _selectedItems.clear();
    switch (type) {
      case RoomType.bathroom:
        _selectedItems.addAll([
          RoomItem.createDefault(ItemCategory.showerArea),
          RoomItem.createDefault(ItemCategory.commode),
          RoomItem.createDefault(ItemCategory.washBasin),
          RoomItem.createDefault(ItemCategory.geyser),
        ]);
        break;
      case RoomType.kitchen:
        _selectedItems.addAll([
          RoomItem.createDefault(ItemCategory.refrigerator),
          RoomItem.createDefault(ItemCategory.gasHob),
          RoomItem.createDefault(ItemCategory.chimney),
          RoomItem.createDefault(ItemCategory.kitchenSink),
          RoomItem.createDefault(ItemCategory.ovenTower),
        ]);
        break;
      case RoomType.bedroom:
      case RoomType.livingRoom:
      case RoomType.studyRoom:
      case RoomType.custom:
        _selectedItems.addAll([
          RoomItem.createDefault(ItemCategory.bed),
          RoomItem.createDefault(ItemCategory.wardrobe),
          RoomItem.createDefault(ItemCategory.studyDesk),
          RoomItem.createDefault(ItemCategory.tvUnit),
          RoomItem.createDefault(ItemCategory.acUnit),
        ]);
        break;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wallTopCtrl.dispose();
    _wallRightCtrl.dispose();
    _wallBottomCtrl.dispose();
    _wallLeftCtrl.dispose();
    _ceilingHeightCtrl.dispose();
    _doorWidthCtrl.dispose();
    _doorOffsetCtrl.dispose();
    _winWidthCtrl.dispose();
    _winOffsetCtrl.dispose();
    _winSillCtrl.dispose();
    super.dispose();
  }

  void _saveAndGenerate() {
    final top = double.tryParse(_wallTopCtrl.text) ?? 4.0;
    final right = double.tryParse(_wallRightCtrl.text) ?? 3.5;
    final bottom = double.tryParse(_wallBottomCtrl.text) ?? top;
    final left = double.tryParse(_wallLeftCtrl.text) ?? right;
    final h = double.tryParse(_ceilingHeightCtrl.text) ?? 2.9;

    final openings = [
      WallOpening(
        id: 'door_main',
        type: OpeningType.door,
        wallIndex: _doorWallIndex,
        offsetFromCorner: double.tryParse(_doorOffsetCtrl.text) ?? 0.3,
        width: double.tryParse(_doorWidthCtrl.text) ?? 0.9,
        doorSwing: _doorSwing,
      ),
      WallOpening(
        id: 'win_main',
        type: _selectedType == RoomType.bathroom ? OpeningType.ventilator : OpeningType.window,
        wallIndex: _winWallIndex,
        offsetFromCorner: double.tryParse(_winOffsetCtrl.text) ?? 0.8,
        width: double.tryParse(_winWidthCtrl.text) ?? 1.5,
        sillHeight: double.tryParse(_winSillCtrl.text) ?? 0.9,
      ),
    ];

    final room = RoomModel(
      id: widget.existingRoom?.id ?? 'room_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty ? 'New Room' : _nameController.text.trim(),
      roomType: _selectedType,
      wallTop: top,
      wallRight: right,
      wallBottom: bottom,
      wallLeft: left,
      ceilingHeight: h,
      openings: openings,
      requestedItems: List.from(_selectedItems),
    );

    if (widget.existingRoom != null) {
      widget.projectState.updateRoom(room);
    } else {
      widget.projectState.addRoomToSelectedFloor(room);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          widget.existingRoom == null ? '📐 Accurate Room Blueprint Wizard' : 'Edit Room Blueprint',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        elevation: 0,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep++);
          } else {
            _saveAndGenerate();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          } else {
            Navigator.of(context).pop();
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: details.onStepContinue,
                    icon: Icon(_currentStep == 2 ? Icons.auto_awesome : Icons.arrow_forward),
                    label: Text(
                      _currentStep == 2 ? 'Generate 2D CAD Blueprint' : 'Next Step',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      side: const BorderSide(color: Color(0xFF334155)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Step 1: Exact 4 Walls & Room Type
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('Dimensions'),
            content: _buildStep1Dimensions(),
          ),

          // Step 2: Doors & Windows Openings
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            title: const Text('Openings'),
            content: _buildStep2Openings(),
          ),

          // Step 3: Items & Style Inspiration Images
          Step(
            isActive: _currentStep >= 2,
            title: const Text('Items & Photos'),
            content: _buildStep3ItemsAndPhotos(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Dimensions() {
    final top = double.tryParse(_wallTopCtrl.text) ?? 0;
    final right = double.tryParse(_wallRightCtrl.text) ?? 0;
    final sqM = top * right;
    final sqFt = sqM * 10.7639;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room Name
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Room Name (e.g. Master Bedroom, Kids Bedroom)',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),

        // Room Type Selector
        const Text(
          'Select Room Zone Type:',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: RoomType.values.map((type) {
            final isSel = _selectedType == type;
            return ChoiceChip(
              label: Text(_getRoomTypeName(type)),
              selected: isSel,
              selectedColor: const Color(0xFF38BDF8),
              backgroundColor: const Color(0xFF1E293B),
              labelStyle: TextStyle(
                color: isSel ? Colors.black : Colors.white70,
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = type;
                    _populateDefaultItemsForType(type);
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // 4 Wall Blueprint Metric Inputs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.straighten, color: Color(0xFF38BDF8), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Exact 4 Wall Lengths (in meters or feet)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricField('Wall A (North / Top)', _wallTopCtrl, '4.20 m'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricField('Wall B (East / Right)', _wallRightCtrl, '3.60 m'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricField('Wall C (South / Bottom)', _wallBottomCtrl, '4.20 m'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricField('Wall D (West / Left)', _wallLeftCtrl, '3.60 m'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMetricField('Ceiling Height (Floor to Slab)', _ceilingHeightCtrl, '2.90 m'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Calculated Floor Area:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      '${sqFt.toStringAsFixed(1)} sq.ft (${sqM.toStringAsFixed(2)} m²)',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Openings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Entry Door Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.door_front_door_outlined, color: Color(0xFFF59E0B), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Entry Door Location & Swing',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Which wall has the entry door?', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Wall A (Top)')),
                  ButtonSegment(value: 1, label: Text('Wall B (Right)')),
                  ButtonSegment(value: 2, label: Text('Wall C (Bottom)')),
                  ButtonSegment(value: 3, label: Text('Wall D (Left)')),
                ],
                selected: {_doorWallIndex},
                onSelectionChanged: (val) => setState(() => _doorWallIndex = val.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricField('Door Width (m)', _doorWidthCtrl, '0.90 m'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricField('Corner Offset (m)', _doorOffsetCtrl, '0.30 m'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Windows & Ventilators Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.window_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Window & Natural Ventilation',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Which wall has the main window?', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Wall A (Top)')),
                  ButtonSegment(value: 1, label: Text('Wall B (Right)')),
                  ButtonSegment(value: 2, label: Text('Wall C (Bottom)')),
                  ButtonSegment(value: 3, label: Text('Wall D (Left)')),
                ],
                selected: {_winWallIndex},
                onSelectionChanged: (val) => setState(() => _winWallIndex = val.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricField('Window Width (m)', _winWidthCtrl, '1.50 m'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricField('Sill Height from floor (m)', _winSillCtrl, '0.90 m'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3ItemsAndPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selected Fixtures & Furniture:',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tap any item to upload reference inspiration pictures (e.g. Wardrobe design, Bed headboard, Tile finish) and custom notes.',
          style: TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const SizedBox(height: 14),

        // List of items with attached image uploaders
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (ctx, i) {
            final item = _selectedItems[i];
            return InspirationImagePicker(
              item: item,
              onItemUpdated: (updated) {
                setState(() {
                  _selectedItems[i] = updated;
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetricField(String label, TextEditingController ctrl, String hint) {
    return TextField(
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  String _getRoomTypeName(RoomType type) {
    switch (type) {
      case RoomType.bathroom:
        return '🚿 Bathroom';
      case RoomType.kitchen:
        return '🍳 Kitchen';
      case RoomType.bedroom:
        return '🛏️ Bedroom';
      case RoomType.livingRoom:
        return '🛋️ Living Room';
      case RoomType.studyRoom:
        return '💻 Study / Work';
      case RoomType.custom:
        return '📐 Custom Zone';
    }
  }
}
