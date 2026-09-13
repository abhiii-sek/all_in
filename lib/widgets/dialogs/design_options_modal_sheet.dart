import 'package:flutter/material.dart';
import '../../models/architectural_design_option.dart';
import '../../models/dynamic_floor_model.dart';
import '../../services/architectural_prompt_service.dart';
import '../../services/design_option_manager_service.dart';

/// Interactive modal sheet to view, switch, duplicate, save, and finalize architectural design options.
class DesignOptionsModalSheet extends StatefulWidget {
  final DynamicFloorDimensions currentDims;
  final List<RoomItemPlacement> currentPlacements;
  final Function(ArchitecturalDesignOption selectedDesign) onDesignSelected;
  final VoidCallback onStateUpdated;

  const DesignOptionsModalSheet({
    super.key,
    required this.currentDims,
    required this.currentPlacements,
    required this.onDesignSelected,
    required this.onStateUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required DynamicFloorDimensions currentDims,
    required List<RoomItemPlacement> currentPlacements,
    required Function(ArchitecturalDesignOption selectedDesign) onDesignSelected,
    required VoidCallback onStateUpdated,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DesignOptionsModalSheet(
        currentDims: currentDims,
        currentPlacements: currentPlacements,
        onDesignSelected: onDesignSelected,
        onStateUpdated: onStateUpdated,
      ),
    );
  }

  @override
  State<DesignOptionsModalSheet> createState() => _DesignOptionsModalSheetState();
}

class _DesignOptionsModalSheetState extends State<DesignOptionsModalSheet> {
  void _saveCurrentActiveDesign() {
    final updated = DesignOptionManagerService.saveCurrentDesign(
      dims: widget.currentDims,
      placements: widget.currentPlacements,
    );
    widget.onDesignSelected(updated);
    widget.onStateUpdated();
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
                'Saved all changes to "${updated.name}" successfully!',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateNewDesignDialog() {
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
              Icon(Icons.add_circle, color: Color(0xFF38BDF8), size: 24),
              SizedBox(width: 10),
              Text(
                'Create New Design Option',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new independent design option to explore alternative room layouts.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Design Option Name',
                    labelStyle: const TextStyle(color: Color(0xFF38BDF8)),
                    hintText: 'e.g. Option C: Open Lounge Concept',
                    hintStyle: const TextStyle(color: Colors.white38),
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
                    labelText: 'Description / Notes',
                    labelStyle: const TextStyle(color: Colors.white70),
                    hintText: 'e.g. Centered bed with floating study desk',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start with empty floor (No items)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Keep room dimensions but clear all placed furniture', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  value: startBlank,
                  activeColor: const Color(0xFF38BDF8),
                  onChanged: (val) => setDlgState(() => startBlank = val),
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
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Create Design', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                final newOpt = DesignOptionManagerService.createNewDesignOption(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  dims: widget.currentDims,
                  initialPlacements: startBlank ? [] : widget.currentPlacements,
                );
                widget.onDesignSelected(newOpt);
                widget.onStateUpdated();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateDesignDialog(ArchitecturalDesignOption source) {
    final nameCtrl = TextEditingController(text: '${source.name} (Copy)');
    final descCtrl = TextEditingController(text: 'Duplicated from "${source.name}" for custom modifications.');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.copy, color: Color(0xFF10B981), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Copy Design Option to New Design',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create a separate working copy of "${source.name}". You can modify dimensions, stretch items, and save as a new layout without overwriting the original.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'New Copy Design Name',
                  labelStyle: const TextStyle(color: Color(0xFF10B981)),
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
                  labelText: 'Modification Notes',
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
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.copy_all, size: 18),
            label: const Text('Duplicate & Open', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final copyOpt = DesignOptionManagerService.duplicateDesignOption(
                source.id,
                newName: nameCtrl.text,
                newDescription: descCtrl.text,
              );
              widget.onDesignSelected(copyOpt);
              widget.onStateUpdated();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  void _showFinalizeDialog(ArchitecturalDesignOption design) {
    final notesCtrl = TextEditingController(text: 'All dimensions and 4-wall clearances verified for final execution.');

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
            Icon(Icons.verified, color: Color(0xFFF59E0B), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Finalize & Approve Design Plan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mark "${design.name}" as the finalized and approved architectural plan. A certification seal will be recorded on the 4K blueprint sheet.',
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
            icon: const Icon(Icons.check_circle, size: 18),
            label: const Text('Finalize Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final finOpt = DesignOptionManagerService.finalizeDesign(
                design.id,
                approvalNotes: notesCtrl.text,
              );
              widget.onDesignSelected(finOpt);
              widget.onStateUpdated();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final designsList = DesignOptionManagerService.designs;
    final activeId = DesignOptionManagerService.activeDesignId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF38BDF8), width: 2.0)),
      ),
      child: Column(
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.dashboard_customize, color: Color(0xFF38BDF8), size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Architectural Design Options',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'Create, duplicate, save, and finalize alternative floor designs',
                        style: TextStyle(fontSize: 12, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add New Design', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showCreateNewDesignDialog,
                ),
              ],
            ),
          ),

          const Divider(color: Color(0xFF1E293B), height: 20),

          // Quick Action Ribbon: Save Current / Copy Current / Finalize Current
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Active: ${DesignOptionManagerService.activeDesign.name}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _saveCurrentActiveDesign,
                ),
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy as New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _showDuplicateDesignDialog(DesignOptionManagerService.activeDesign),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // List of saved design options
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: designsList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final design = designsList[index];
                final isActive = design.id == activeId;
                final totalArea = design.dims.totalWidth * design.dims.totalLength;

                return Container(
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFF13233E) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                      width: isActive ? 2.0 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Title, Active Badge, Finalized Badge
                        Row(
                          children: [
                            Icon(
                              isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isActive ? const Color(0xFF38BDF8) : Colors.white38,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                design.name,
                                style: TextStyle(
                                  color: isActive ? const Color(0xFF38BDF8) : Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (design.isFinalized)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF065F46),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: Color(0xFF34D399), size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'FINALIZED',
                                      style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DRAFT',
                                  style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),

                        if (design.description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            design.description,
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Metric pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildInfoChip(
                              Icons.straighten,
                              '${design.dims.format(design.dims.totalWidth)} × ${design.dims.format(design.dims.totalLength)}',
                              const Color(0xFF38BDF8),
                            ),
                            _buildInfoChip(
                              Icons.square_foot,
                              design.dims.formatArea(totalArea),
                              const Color(0xFFFBBF24),
                            ),
                            _buildInfoChip(
                              Icons.chair,
                              '${design.placements.length} Furniture Items',
                              const Color(0xFF34D399),
                            ),
                            _buildInfoChip(
                              Icons.schedule,
                              'Modified ${design.lastModified.hour.toString().padLeft(2, '0')}:${design.lastModified.minute.toString().padLeft(2, '0')}',
                              const Color(0xFF94A3B8),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 10),

                        // Actions row
                        Row(
                          children: [
                            if (!isActive)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF38BDF8),
                                  foregroundColor: const Color(0xFF0F172A),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Activate Layout', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () {
                                  final switched = DesignOptionManagerService.switchActiveDesign(design.id);
                                  widget.onDesignSelected(switched);
                                  widget.onStateUpdated();
                                  setState(() {});
                                },
                              ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF475569)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              icon: const Icon(Icons.copy, size: 14),
                              label: const Text('Duplicate to New', style: TextStyle(fontSize: 12)),
                              onPressed: () => _showDuplicateDesignDialog(design),
                            ),
                            const Spacer(),
                            if (!design.isFinalized)
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF59E0B)),
                                icon: const Icon(Icons.verified_outlined, size: 16),
                                label: const Text('Finalize', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () => _showFinalizeDialog(design),
                              )
                            else
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                icon: const Icon(Icons.lock_open, size: 16),
                                label: const Text('Reopen', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  final unlocked = DesignOptionManagerService.unlockFinalizedDesign(design.id);
                                  widget.onDesignSelected(unlocked);
                                  widget.onStateUpdated();
                                  setState(() {});
                                },
                              ),
                            if (designsList.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                                tooltip: 'Delete Design Option',
                                onPressed: () {
                                  DesignOptionManagerService.deleteDesignOption(design.id);
                                  widget.onStateUpdated();
                                  setState(() {});
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
