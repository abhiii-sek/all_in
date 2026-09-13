import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/project_state.dart';
import 'wizard/room_wizard_screen.dart';
import 'blueprint_studio_screen.dart';
import 'exact_floor_studio_screen.dart';

class HomeScreen extends StatefulWidget {
  final ProjectState projectState;

  const HomeScreen({
    super.key,
    required this.projectState,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.projectState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.projectState.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showAddFloorDialog() {
    final nameCtrl = TextEditingController(text: 'Second Floor');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: const Text('Add New Floor / Level', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Floor Name (e.g. Ground Floor, First Floor, Terrace)',
            labelStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                widget.projectState.addFloor(nameCtrl.text.trim());
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Create Floor'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final floors = widget.projectState.floors;
    final selectedFloor = widget.projectState.selectedFloor;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.home_work_outlined, color: Color(0xFF38BDF8), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'HomeCraft OS • Architectural 2D CAD Studio',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const ExactFloorStudioScreen(),
                ),
              );
            },
            icon: const Icon(Icons.architecture, size: 18),
            label: const Text('Open Floor CAD Studio', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => RoomWizardScreen(projectState: widget.projectState),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Room Blueprint', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar: Floor Switcher
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(right: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PROJECT FLOORS',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8), size: 20),
                        tooltip: 'Add Floor',
                        onPressed: _showAddFloorDialog,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: floors.length,
                    itemBuilder: (ctx, i) {
                      final floor = floors[i];
                      final isSelected = floor.id == widget.projectState.selectedFloorId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFF1E293B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        leading: Icon(
                          Icons.layers_outlined,
                          color: isSelected ? const Color(0xFF38BDF8) : Colors.white54,
                          size: 20,
                        ),
                        title: Text(
                          floor.name,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13.5,
                          ),
                        ),
                        subtitle: Text(
                          '${floor.rooms.length} Rooms • ${floor.totalFloorAreaSqFt.toStringAsFixed(0)} sq.ft',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        onTap: () {
                          widget.projectState.selectFloor(floor.id);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Main Area: Rooms Grid on Selected Floor
          Expanded(
            child: selectedFloor == null || selectedFloor.rooms.isEmpty
                ? _buildEmptyState()
                : Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Floor Header Banner
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    selectedFloor.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${selectedFloor.rooms.length} active room blueprints | Total Floor Area: ${selectedFloor.totalFloorAreaSqFt.toStringAsFixed(1)} sq.ft',
                                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Rooms Grid
                        Expanded(
                          child: GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 380,
                              mainAxisSpacing: 20,
                              crossAxisSpacing: 20,
                              mainAxisExtent: 250,
                            ),
                            itemCount: selectedFloor.rooms.length,
                            itemBuilder: (ctx, i) {
                              final room = selectedFloor.rooms[i];
                              return _buildRoomCard(room);
                            },
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

  Widget _buildRoomCard(RoomModel room) {
    return InkWell(
      onTap: () {
        widget.projectState.selectRoom(room.id);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => BlueprintStudioScreen(
              room: room,
              projectState: widget.projectState,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E293B)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header Row: Icon, Name & Type Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getRoomIcon(room.roomType), color: const Color(0xFF38BDF8), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${room.floorAreaSqFt.toStringAsFixed(1)} sq.ft (${room.floorAreaSqM.toStringAsFixed(1)} m²)',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white54, size: 18),
                  color: const Color(0xFF1E293B),
                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => RoomWizardScreen(
                            projectState: widget.projectState,
                            existingRoom: room,
                          ),
                        ),
                      );
                    } else if (val == 'delete') {
                      widget.projectState.deleteRoom(room.id);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit Dimensions', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Delete Room', style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 4 Wall Dimensions Badge Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF131C2E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(child: _wallPill('A', '${room.wallTop.toStringAsFixed(1)}m')),
                  Expanded(child: _wallPill('B', '${room.wallRight.toStringAsFixed(1)}m')),
                  Expanded(child: _wallPill('C', '${room.wallBottom.toStringAsFixed(1)}m')),
                  Expanded(child: _wallPill('D', '${room.wallLeft.toStringAsFixed(1)}m')),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Footer Action: View 3D / 2D Studio Button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${room.generatedLayouts.length} AI Layouts',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFF38BDF8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                    ),
                  ),
                  onPressed: () {
                    widget.projectState.selectRoom(room.id);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => BlueprintStudioScreen(
                          room: room,
                          projectState: widget.projectState,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.architecture, size: 15),
                  label: const Text('2D Studio', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _wallPill(String wall, String dim) {
    return Column(
      children: [
        Text(wall, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
        const SizedBox(height: 2),
        Text(dim, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.architecture, color: Color(0xFF38BDF8), size: 64),
          const SizedBox(height: 16),
          const Text(
            'No Room Blueprints on this Floor Yet',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a Bathroom, Modular Kitchen, or Bedroom to calculate precise 4-wall dimensions and 2D CAD blueprints.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => RoomWizardScreen(projectState: widget.projectState),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Create First Room Blueprint', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getRoomIcon(RoomType type) {
    switch (type) {
      case RoomType.bathroom:
        return Icons.bathtub_outlined;
      case RoomType.kitchen:
        return Icons.countertops_outlined;
      case RoomType.bedroom:
        return Icons.bed_outlined;
      case RoomType.livingRoom:
        return Icons.weekend_outlined;
      case RoomType.studyRoom:
        return Icons.laptop_chromebook_outlined;
      case RoomType.custom:
        return Icons.space_dashboard_outlined;
    }
  }
}
