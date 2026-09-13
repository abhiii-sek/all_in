import 'package:flutter/material.dart';
import 'dynamic_floor_model.dart';

class DynamicFloorItem {
  final String id;
  final String name;
  final String category;
  final double width;
  final double length;
  final double height;
  final double x;
  final double y;
  final Color color;
  final String recommendationReason;
  final String? imagePath;
  final String? notes;

  const DynamicFloorItem({
    required this.id,
    required this.name,
    required this.category,
    required this.width,
    required this.length,
    this.height = 2.8,
    required this.x,
    required this.y,
    required this.color,
    required this.recommendationReason,
    this.imagePath,
    this.notes,
  });
}

class DynamicFloorStyle {
  final String id;
  final String title;
  final String description;
  final int score;
  final List<String> highlights;
  final List<DynamicFloorItem> items;

  const DynamicFloorStyle({
    required this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.highlights,
    this.items = const [],
  });
}

class DynamicFloorLayoutEngine {
  static List<DynamicFloorStyle> generateStyles(DynamicFloorDimensions dims) {
    return [
      _buildMasterLayout(dims),
      _buildWorkstationLayout(dims),
      _buildHospitalityLoungeLayout(dims),
      _buildMaxStorageLayout(dims),
    ];
  }

  // --- STYLE 1: MASTER SUITE (OPTIMAL ARCHITECTURAL PROPORTIONS) ---
  static DynamicFloorStyle _buildMasterLayout(DynamicFloorDimensions d) {
    return DynamicFloorStyle(
      id: 'style_master',
      title: '1. Blueprint Master (Dynamic Engineered)',
      description:
          'Standard architectural partition with ${d.format(d.roomWidth)} × ${d.format(d.roomLength)} Master Suite, ${d.format(d.bathWidth)} × ${d.format(d.bathLength)} Ensuite Bath, and ${d.format(d.kitchenWidth)} × ${d.format(d.kitchenLength)} Kitchen.',
      score: 98,
      highlights: [
        'Direct ensuite wet-dry bathroom isolation (${d.format(d.bathWidth)} span)',
        'Natural daylight orientation for bedroom and kitchen windows',
        'Direct corridor access from gallery entrance',
      ],
      items: const [],
    );
  }

  // --- STYLE 2: WORKSTATION & STUDY SUITE ---
  static DynamicFloorStyle _buildWorkstationLayout(DynamicFloorDimensions d) {
    return DynamicFloorStyle(
      id: 'style_workstation',
      title: '2. Executive Circulation & Study Blueprint',
      description: 'Extended corridor clearance with dedicated deep study niche and quiet zone partition.',
      score: 95,
      highlights: [
        'Unobstructed continuous walkway corridor (${d.format(d.galleryWidth)} width)',
        'Acoustic separation between Kitchen core and Master Suite',
        'Optimized electrical and plumbing chase alignments',
      ],
      items: const [],
    );
  }

  // --- STYLE 3: LUXURY HOSPITALITY LOUNGE ---
  static DynamicFloorStyle _buildHospitalityLoungeLayout(DynamicFloorDimensions d) {
    return DynamicFloorStyle(
      id: 'style_hospitality',
      title: '3. Open-Concept Flow & Lounge Blueprint',
      description: 'Maximized open living foyer flow connecting kitchen breakfast bar directly to suite corridor.',
      score: 94,
      highlights: [
        'Open-concept kitchen connectivity with hallway',
        'Enhanced cross-ventilation between bedroom and balcony',
        'Spacious bathroom vanity zone with wide entry opening',
      ],
      items: const [],
    );
  }

  // --- STYLE 4: MAXIMUM EFFICIENCY & UTILITY CORE ---
  static DynamicFloorStyle _buildMaxStorageLayout(DynamicFloorDimensions d) {
    return DynamicFloorStyle(
      id: 'style_storage',
      title: '4. Maximum Utility & Space Efficiency Blueprint',
      description: 'Compact staircase core with high floor area ratio and maximized usable carpet area.',
      score: 92,
      highlights: [
        'Over 85% usable carpet area efficiency',
        'Centralized wet wall plumbing riser shaft',
        'Dedicated storage corridor alcove along gallery wall',
      ],
      items: const [],
    );
  }
}
