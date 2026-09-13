import 'package:flutter/material.dart';
import '../../models/room_model.dart';
import '../../services/project_state.dart';

class LayoutSelectionSheet extends StatelessWidget {
  final RoomModel room;
  final ProjectState projectState;

  const LayoutSelectionSheet({
    super.key,
    required this.room,
    required this.projectState,
  });

  @override
  Widget build(BuildContext context) {
    if (room.generatedLayouts.isEmpty) {
      return const SizedBox.shrink();
    }

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
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Spatial Layout Options (${room.generatedLayouts.length} Generated)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: room.generatedLayouts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final opt = room.generatedLayouts[i];
              final isSelected = room.selectedLayoutIndex == i;

              return InkWell(
                onTap: () {
                  projectState.selectLayoutForRoom(room.id, i);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                          Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                color: isSelected ? const Color(0xFF38BDF8) : Colors.white38,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                opt.title,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.star, color: Color(0xFF10B981), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${opt.score}% Score',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        opt.description,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: opt.highlights.map((h) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '✓ $h',
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
