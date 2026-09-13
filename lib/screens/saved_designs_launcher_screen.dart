import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/architectural_design_option.dart';
import '../models/dynamic_floor_model.dart';
import '../services/design_option_manager_service.dart';
import 'main_floor_experience_screen.dart';
import 'bedroom_simulation_screen.dart';

/// Startup Launcher & Saved Designs Hub.
/// Greets user on app startup, allowing instant 1-click continuation of their
/// previous/last edited floor plan, creation of brand new custom design options,
/// and full management (open, duplicate, finalize, delete) of all saved designs.
class SavedDesignsLauncherScreen extends StatefulWidget {
  const SavedDesignsLauncherScreen({super.key});

  @override
  State<SavedDesignsLauncherScreen> createState() => _SavedDesignsLauncherScreenState();
}

class _SavedDesignsLauncherScreenState extends State<SavedDesignsLauncherScreen> {
  String _searchQuery = '';
  int _selectedFilterTab = 0; // 0: All, 1: Finalized, 2: Drafts

  @override
  void initState() {
    super.initState();
    _refreshState();
  }

  void _refreshState() {
    if (mounted) setState(() {});
  }

  void _openDesignInStudio(ArchitecturalDesignOption design) async {
    DesignOptionManagerService.switchActiveDesign(design.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => const MainFloorExperienceScreen(),
      ),
    );
    _refreshState();
  }

  void _openDesignIn3DSimulation(ArchitecturalDesignOption design) async {
    DesignOptionManagerService.switchActiveDesign(design.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BedroomSimulationScreen(
          dims: design.dims,
          placements: design.placements,
        ),
      ),
    );
    _refreshState();
  }

  void _showCreateNewDesignDialog() {
    final nameCtrl = TextEditingController(text: 'Design Option ${DesignOptionManagerService.designs.length + 1}');
    final descCtrl = TextEditingController();
    DimensionUnit selectedUnit = DimensionUnit.feet;
    final rWidthCtrl = TextEditingController(text: '10.5');
    final rLengthCtrl = TextEditingController(text: '18.5');
    final bWidthCtrl = TextEditingController(text: '5.91');
    final bLengthCtrl = TextEditingController(text: '7.5');
    final kWidthCtrl = TextEditingController(text: '7.6');
    final kLengthCtrl = TextEditingController(text: '9.8');

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
                'Create New Floor Design Option',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Define the title and core room boundaries for your new floor plan design option:',
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
                      labelText: 'Design Notes / Objectives (Optional)',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Dimension Unit: ', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 10),
                      DropdownButton<DimensionUnit>(
                        value: selectedUnit,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                        items: DimensionUnit.values.map((u) {
                          return DropdownMenuItem(value: u, child: Text(u.label));
                        }).toList(),
                        onChanged: (u) {
                          if (u != null) {
                            setDlgState(() => selectedUnit = u);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Initial Spatial Dimensions:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: rWidthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Room Width (${selectedUnit.symbol})',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: rLengthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Room Length (${selectedUnit.symbol})',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: bWidthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Bath Width (${selectedUnit.symbol})',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: bLengthCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Bath Length (${selectedUnit.symbol})',
                            labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              label: const Text('Create & Launch Studio', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.pop(ctx);
                final rw = double.tryParse(rWidthCtrl.text) ?? 10.5;
                final rl = double.tryParse(rLengthCtrl.text) ?? 18.5;
                final bw = double.tryParse(bWidthCtrl.text) ?? 5.91;
                final bl = double.tryParse(bLengthCtrl.text) ?? 7.5;
                final kw = double.tryParse(kWidthCtrl.text) ?? 7.6;
                final kl = double.tryParse(kLengthCtrl.text) ?? 9.8;

                final customDims = DynamicFloorDimensions(
                  unit: selectedUnit,
                  roomWidth: rw,
                  roomLength: rl,
                  bathWidth: bw,
                  bathLength: bl,
                  kitchenWidth: kw,
                  kitchenLength: kl,
                );

                final newOpt = DesignOptionManagerService.createNewDesignOption(
                  name: nameCtrl.text,
                  description: descCtrl.text,
                  dims: customDims,
                );
                _openDesignInStudio(newOpt);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDuplicateDialog(ArchitecturalDesignOption source) {
    final nameCtrl = TextEditingController(text: '${source.name} (Copy)');
    final descCtrl = TextEditingController(text: 'Duplicated from "${source.name}" for custom alterations.');

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
            Text(
              'Duplicate Design Option',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create a complete independent clone of "${source.name}". You can customize all dimensions and furniture without changing the original.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Cloned Name',
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
                labelText: 'Notes',
                labelStyle: const TextStyle(color: Colors.white60),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
            label: const Text('Duplicate & Open', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              final copy = DesignOptionManagerService.duplicateDesignOption(
                source.id,
                newName: nameCtrl.text,
                newDescription: descCtrl.text,
              );
              _openDesignInStudio(copy);
            },
          ),
        ],
      ),
    );
  }

  void _showFinalizeDialog(ArchitecturalDesignOption design) {
    if (design.isFinalized) {
      DesignOptionManagerService.unlockFinalizedDesign(design.id);
      _refreshState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0284C7),
          behavior: SnackBarBehavior.floating,
          content: Text('Design "${design.name}" unlocked for working revisions.'),
        ),
      );
      return;
    }

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
              'Finalize & Approve Plan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Finalize "${design.name}". Stamps this plan with an official certified approval seal and locks in all spatial calculations.',
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Approval Certification Notes',
                labelStyle: const TextStyle(color: Color(0xFFF59E0B)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
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
              DesignOptionManagerService.finalizeDesign(design.id, approvalNotes: notesCtrl.text);
              _refreshState();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Plan "${design.name}" is now FINALIZED & APPROVED! ✅'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ArchitecturalDesignOption design) {
    if (DesignOptionManagerService.designs.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          content: Text('Cannot delete the last remaining design option.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text(
              'Delete Design Option',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${design.name}"? This action cannot be undone.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete, size: 16),
            label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              DesignOptionManagerService.deleteDesignOption(design.id);
              _refreshState();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                  content: Text('Deleted "${design.name}".'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDesigns = DesignOptionManagerService.designs;
    final latestDesign = DesignOptionManagerService.latestEditedDesign;

    // Filter by query and tabs
    var filtered = allDesigns.where((d) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = d.name.toLowerCase().contains(q);
        final matchDesc = d.description.toLowerCase().contains(q);
        if (!matchName && !matchDesc) return false;
      }
      if (_selectedFilterTab == 1) return d.isFinalized;
      if (_selectedFilterTab == 2) return !d.isFinalized;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.architecture, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HomeCraft OS • Blueprint CAD Studio',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                ),
                Text(
                  'Floor Layout Designer & Saved Projects Hub',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: const Color(0xFF0F172A),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _showCreateNewDesignDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ Add New Design', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO BANNER: Continue with Old / Last Edited Design
            _buildContinueHeroCard(latestDesign),
            const SizedBox(height: 28),

            // SECTION HEADER: All Saved Designs
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.folder_open, color: Color(0xFF38BDF8), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Saved Floor Design Options (${allDesigns.length})',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Switch between multiple design options, duplicate revisions, or finalize construction fabrication plans.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                // Search Bar
                SizedBox(
                  width: 260,
                  height: 38,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search saved designs...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 18),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Filter Tabs (All, Finalized, Working Drafts)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterTab(0, 'All Designs (${allDesigns.length})'),
                _buildFilterTab(1, '⭐ Finalized & Approved (${allDesigns.where((d) => d.isFinalized).length})'),
                _buildFilterTab(2, '✏️ Working Drafts (${allDesigns.where((d) => !d.isFinalized).length})'),
              ],
            ),
            const SizedBox(height: 18),

            // Designs Cards Grid
            if (filtered.isEmpty)
              _buildEmptySearchResult()
            else
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final isWide = constraints.maxWidth >= 900;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 2 : 1,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 280,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final design = filtered[i];
                      return _buildDesignCard(design, isLatest: design.id == latestDesign.id);
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueHeroCard(ArchitecturalDesignOption latest) {
    final dateFormat = DateFormat('MMM d, y • h:mm a');
    final areaSqFt = (latest.dims.roomWidth * latest.dims.roomLength) +
        (latest.dims.kitchenWidth * latest.dims.kitchenLength) +
        (latest.dims.bathWidth * latest.dims.bathLength);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF131C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.flash_on, color: Color(0xFF38BDF8), size: 36),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⚡ CONTINUE WORKING',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (latest.isFinalized)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Color(0xFF10B981), size: 12),
                              SizedBox(width: 4),
                              Text(
                                'FINALIZED & APPROVED',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 10.5, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    latest.name,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Room: ${latest.dims.format(latest.dims.roomWidth)} × ${latest.dims.format(latest.dims.roomLength)} • Bath: ${latest.dims.format(latest.dims.bathWidth)} × ${latest.dims.format(latest.dims.bathLength)} • Carpet: ${areaSqFt.toStringAsFixed(1)} sq.ft • ${latest.placements.length} Placed Items',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last modified: ${dateFormat.format(latest.lastModified)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9900),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                onPressed: () => _openDesignIn3DSimulation(latest),
                icon: const Icon(Icons.view_in_ar, size: 20),
                label: const Text('🌟 3D Simulation', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                onPressed: () => _openDesignInStudio(latest),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Open in 2D Studio', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilterTab = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDesignCard(ArchitecturalDesignOption design, {required bool isLatest}) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final totalAreaSqFt = (design.dims.roomWidth * design.dims.roomLength) +
        (design.dims.kitchenWidth * design.dims.kitchenLength) +
        (design.dims.bathWidth * design.dims.bathLength);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLatest
              ? const Color(0xFF38BDF8)
              : (design.isFinalized ? const Color(0xFF10B981).withValues(alpha: 0.6) : const Color(0xFF1E293B)),
          width: isLatest ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Status badge & Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (design.isFinalized ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  design.isFinalized ? Icons.verified : Icons.architecture,
                  color: design.isFinalized ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            design.name,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (design.isFinalized)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FINALIZED ✅',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'DRAFT ✏️',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      design.description.isNotEmpty ? design.description : 'Standard custom architectural floor plan.',
                      style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Middle: Quick Specs Grid
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131C2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSpecItem('Room Size', '${design.dims.format(design.dims.roomWidth)} × ${design.dims.format(design.dims.roomLength)}'),
                _buildSpecItem('Bath Size', '${design.dims.format(design.dims.bathWidth)} × ${design.dims.format(design.dims.bathLength)}'),
                _buildSpecItem('Total Area', '${totalAreaSqFt.toStringAsFixed(0)} sq.ft'),
                _buildSpecItem('Items', '${design.placements.length} Placed'),
              ],
            ),
          ),

          // Bottom Info & Actions (Flexible wrap)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Modified: ${dateFormat.format(design.lastModified)}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_all, size: 18),
                    color: Colors.white70,
                    tooltip: 'Duplicate / Copy',
                    onPressed: () => _showDuplicateDialog(design),
                  ),
                  IconButton(
                    icon: Icon(design.isFinalized ? Icons.lock_open : Icons.task_alt, size: 18),
                    color: design.isFinalized ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    tooltip: design.isFinalized ? 'Unlock Plan' : 'Finalize & Approve',
                    onPressed: () => _showFinalizeDialog(design),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    color: Colors.redAccent,
                    tooltip: 'Delete Design',
                    onPressed: () => _showDeleteDialog(design),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9900).withValues(alpha: 0.2),
                      foregroundColor: const Color(0xFFFF9900),
                      side: const BorderSide(color: Color(0xFFFF9900), width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _openDesignIn3DSimulation(design),
                    icon: const Icon(Icons.view_in_ar, size: 13),
                    label: const Text('3D Sim', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _openDesignInStudio(design),
                    icon: const Icon(Icons.edit, size: 13),
                    label: const Text('Open Studio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11.5)),
      ],
    );
  }

  Widget _buildEmptySearchResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.search_off, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No Saved Designs Match Your Filter',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try changing your search query or create a brand new design option.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: const Color(0xFF0F172A),
              ),
              onPressed: _showCreateNewDesignDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New Design Option', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
