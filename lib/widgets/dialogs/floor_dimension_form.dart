import 'package:flutter/material.dart';
import '../../models/dynamic_floor_model.dart';

class FloorDimensionFormDialog extends StatefulWidget {
  final DynamicFloorDimensions initialDimensions;
  final Function(DynamicFloorDimensions updated) onSave;

  const FloorDimensionFormDialog({
    super.key,
    required this.initialDimensions,
    required this.onSave,
  });

  @override
  State<FloorDimensionFormDialog> createState() => _FloorDimensionFormDialogState();
}

class _FloorDimensionFormDialogState extends State<FloorDimensionFormDialog> {
  late DimensionUnit _unit;
  late TextEditingController _roomW;
  late TextEditingController _roomL;
  late TextEditingController _bathW;
  late TextEditingController _bathL;
  late TextEditingController _showerD;
  late TextEditingController _commodeW;
  late TextEditingController _basinW;
  late TextEditingController _kitchW;
  late TextEditingController _kitchL;
  late TextEditingController _kitchCounterD;
  late TextEditingController _bfastRun;
  late TextEditingController _stairW;
  late TextEditingController _galleryW;
  late TextEditingController _ceilingH;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDimensions;
    _unit = d.unit;
    _roomW = TextEditingController(text: d.roomWidth.toStringAsFixed(2));
    _roomL = TextEditingController(text: d.roomLength.toStringAsFixed(2));
    _bathW = TextEditingController(text: d.bathWidth.toStringAsFixed(2));
    _bathL = TextEditingController(text: d.bathLength.toStringAsFixed(2));
    _showerD = TextEditingController(text: d.showerDepth.toStringAsFixed(2));
    _commodeW = TextEditingController(text: d.commodeWidth.toStringAsFixed(2));
    _basinW = TextEditingController(text: d.basinWidth.toStringAsFixed(2));
    _kitchW = TextEditingController(text: d.kitchenWidth.toStringAsFixed(2));
    _kitchL = TextEditingController(text: d.kitchenLength.toStringAsFixed(2));
    _kitchCounterD = TextEditingController(text: d.kitchenCounterDepth.toStringAsFixed(2));
    _bfastRun = TextEditingController(text: d.breakfastCounterRun.toStringAsFixed(2));
    _stairW = TextEditingController(text: d.staircaseWidth.toStringAsFixed(2));
    _galleryW = TextEditingController(text: d.galleryWidth.toStringAsFixed(2));
    _ceilingH = TextEditingController(text: d.ceilingHeight.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _roomW.dispose();
    _roomL.dispose();
    _bathW.dispose();
    _bathL.dispose();
    _showerD.dispose();
    _commodeW.dispose();
    _basinW.dispose();
    _kitchW.dispose();
    _kitchL.dispose();
    _kitchCounterD.dispose();
    _bfastRun.dispose();
    _stairW.dispose();
    _galleryW.dispose();
    _ceilingH.dispose();
    super.dispose();
  }

  void _save() {
    final updated = DynamicFloorDimensions(
      unit: _unit,
      roomWidth: double.tryParse(_roomW.text) ?? 10.5,
      roomLength: double.tryParse(_roomL.text) ?? 18.5,
      bathWidth: double.tryParse(_bathW.text) ?? 5.91,
      bathLength: double.tryParse(_bathL.text) ?? 7.5,
      showerDepth: double.tryParse(_showerD.text) ?? 3.01,
      commodeWidth: double.tryParse(_commodeW.text) ?? 2.85,
      basinWidth: double.tryParse(_basinW.text) ?? 2.14,
      kitchenWidth: double.tryParse(_kitchW.text) ?? 7.6,
      kitchenLength: double.tryParse(_kitchL.text) ?? 9.8,
      kitchenCounterDepth: double.tryParse(_kitchCounterD.text) ?? 2.17,
      breakfastCounterRun: double.tryParse(_bfastRun.text) ?? 2.03,
      staircaseWidth: double.tryParse(_stairW.text) ?? 4.5,
      galleryWidth: double.tryParse(_galleryW.text) ?? 2.8,
      ceilingHeight: double.tryParse(_ceilingH.text) ?? 9.5,
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = _unit.label;

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF1E293B)),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.straighten, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Text(
                'Enter Exact Floor Dimensions',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SegmentedButton<DimensionUnit>(
            segments: const [
              ButtonSegment(value: DimensionUnit.feet, label: Text('ft')),
              ButtonSegment(value: DimensionUnit.inches, label: Text('in')),
              ButtonSegment(value: DimensionUnit.meters, label: Text('m')),
              ButtonSegment(value: DimensionUnit.centimeters, label: Text('cm')),
            ],
            selected: {_unit},
            onSelectionChanged: (val) {
              setState(() {
                final oldUnit = _unit;
                final newUnit = val.first;
                if (oldUnit != newUnit) {
                  final cur = DynamicFloorDimensions(
                    unit: oldUnit,
                    roomWidth: double.tryParse(_roomW.text) ?? 10.5,
                    roomLength: double.tryParse(_roomL.text) ?? 18.5,
                    bathWidth: double.tryParse(_bathW.text) ?? 5.91,
                    bathLength: double.tryParse(_bathL.text) ?? 7.5,
                    showerDepth: double.tryParse(_showerD.text) ?? 3.01,
                    commodeWidth: double.tryParse(_commodeW.text) ?? 2.85,
                    basinWidth: double.tryParse(_basinW.text) ?? 2.14,
                    kitchenWidth: double.tryParse(_kitchW.text) ?? 7.6,
                    kitchenLength: double.tryParse(_kitchL.text) ?? 9.8,
                    kitchenCounterDepth: double.tryParse(_kitchCounterD.text) ?? 2.17,
                    breakfastCounterRun: double.tryParse(_bfastRun.text) ?? 2.03,
                    staircaseWidth: double.tryParse(_stairW.text) ?? 4.5,
                    galleryWidth: double.tryParse(_galleryW.text) ?? 2.8,
                    ceilingHeight: double.tryParse(_ceilingH.text) ?? 9.5,
                  );
                  cur.switchUnit(newUnit);
                  _unit = newUnit;
                  _roomW.text = cur.roomWidth.toStringAsFixed(2);
                  _roomL.text = cur.roomLength.toStringAsFixed(2);
                  _bathW.text = cur.bathWidth.toStringAsFixed(2);
                  _bathL.text = cur.bathLength.toStringAsFixed(2);
                  _showerD.text = cur.showerDepth.toStringAsFixed(2);
                  _commodeW.text = cur.commodeWidth.toStringAsFixed(2);
                  _basinW.text = cur.basinWidth.toStringAsFixed(2);
                  _kitchW.text = cur.kitchenWidth.toStringAsFixed(2);
                  _kitchL.text = cur.kitchenLength.toStringAsFixed(2);
                  _kitchCounterD.text = cur.kitchenCounterDepth.toStringAsFixed(2);
                  _bfastRun.text = cur.breakfastCounterRun.toStringAsFixed(2);
                  _stairW.text = cur.staircaseWidth.toStringAsFixed(2);
                  _galleryW.text = cur.galleryWidth.toStringAsFixed(2);
                  _ceilingH.text = cur.ceilingHeight.toStringAsFixed(2);
                }
              });
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your measurements in $unitLabel. All walls, doorways, windows, and architectural 2D floor plans will automatically update.',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 16),

              // 1. Master Bedroom + Living
              _buildSection(
                '🛏️ Master Room (Bed + Living)',
                const Color(0xFF6366F1),
                [
                  _field('Room Total Width', _roomW),
                  _field('Room Total Length', _roomL),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Ensuite Bathroom
              _buildSection(
                '🚿 Ensuite Bathroom',
                const Color(0xFF06B6D4),
                [
                  _field('Bathroom Width', _bathW),
                  _field('Bathroom Length', _bathL),
                  _field('Shower Zone Depth', _showerD),
                  _field('Commode Area Width', _commodeW),
                  _field('Basin Vanity Width', _basinW),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Modular Kitchen
              _buildSection(
                '🍳 Modular Kitchen',
                const Color(0xFFEF4444),
                [
                  _field('Kitchen Width', _kitchW),
                  _field('Kitchen Length', _kitchL),
                  _field('Counter Depth', _kitchCounterD),
                  _field('Breakfast Bar Run', _bfastRun),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Core & Height
              _buildSection(
                '🏛️ Circulation & Height',
                const Color(0xFFF59E0B),
                [
                  _field('Staircase Width', _stairW),
                  _field('Gallery Corridor Width', _galleryW),
                  _field('Ceiling Height (Floor to Slab)', _ceilingH),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: _save,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Apply Exact Dimensions', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSection(String title, Color color, List<Widget> fields) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: fields,
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return SizedBox(
      width: 170,
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white, fontSize: 12.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
