import 'package:flutter/material.dart';

enum LayoutStyleType {
  blueprintMaster, // Exact specification from user's drawing
  executiveWorkstation, // With dedicated study desk & home office
  luxuryHospitality, // With L-shape lounge & floating king bed
  maxStorageFamily, // With full-height loft storage & high capacity
}

class FloorItemModel {
  final String id;
  final String name;
  final String category;
  final double widthFt;
  final double lengthFt;
  final double heightFt;
  final double xFt; // X coordinate from top-left origin of floor
  final double yFt; // Y coordinate from top-left origin of floor
  final double rotationDeg;
  final Color color;
  final String? notes;
  final String? imagePath;

  const FloorItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.widthFt,
    required this.lengthFt,
    this.heightFt = 2.8,
    required this.xFt,
    required this.yFt,
    this.rotationDeg = 0.0,
    required this.color,
    this.notes,
    this.imagePath,
  });

  FloorItemModel copyWith({
    String? id,
    String? name,
    String? category,
    double? widthFt,
    double? lengthFt,
    double? heightFt,
    double? xFt,
    double? yFt,
    double? rotationDeg,
    Color? color,
    String? notes,
    String? imagePath,
  }) {
    return FloorItemModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      widthFt: widthFt ?? this.widthFt,
      lengthFt: lengthFt ?? this.lengthFt,
      heightFt: heightFt ?? this.heightFt,
      xFt: xFt ?? this.xFt,
      yFt: yFt ?? this.yFt,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      color: color ?? this.color,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class FloorLayoutStyle {
  final LayoutStyleType type;
  final String title;
  final String description;
  final int score;
  final List<String> highlights;
  final List<FloorItemModel> items;

  const FloorLayoutStyle({
    required this.type,
    required this.title,
    required this.description,
    required this.score,
    required this.highlights,
    required this.items,
  });
}

class ExactFloorPlanData {
  // Total Floor Bounds (in feet)
  static const double totalWidthFt = 18.0;
  static const double totalLengthFt = 26.5;

  // Left Wing (Room + Bathroom)
  static const double leftWingWidthFt = 10.4;
  static const double mainRoomLengthFt = 18.5;
  static const double bathroomLengthFt = 7.5;
  static const double bathroomWidthFt = 5.91;

  // Right Wing (Kitchen + Staircase + Gallery)
  static const double rightWingWidthFt = 7.6;
  static const double kitchenLengthFt = 9.8;
  static const double galleryWidthFt = 2.8;

  // =========================================================================
  // 4 PRE-CONFIGURED ARCHITECTURAL STYLES
  // =========================================================================
  static List<FloorLayoutStyle> getStyles() {
    return [
      _buildBlueprintMasterStyle(),
      _buildExecutiveWorkstationStyle(),
      _buildLuxuryHospitalityStyle(),
      _buildMaxStorageStyle(),
    ];
  }

  // --- STYLE 1: EXACT BLUEPRINT MASTER (As per User Drawing) ---
  static FloorLayoutStyle _buildBlueprintMasterStyle() {
    return const FloorLayoutStyle(
      type: LayoutStyleType.blueprintMaster,
      title: '1. Blueprint Master (Exact Spec)',
      description:
          'Exact implementation of your uploaded architectural plan: King Bed (5.52\' x 6.25\'), Living Sofa (5.52\' x 5.42\'), Linear Wardrobe & Media Wall, 3-Tier Bathroom, and Kitchen with Breakfast Counter.',
      score: 99,
      highlights: [
        'Bed (5.52\' x 6.25\') on solid feature wall with 2.8\' central walkway',
        '3-Seater Sofa (5.52\' x 5.42\') aligned with 55" TV Unit (5.26\' x 1.67\')',
        'Full storage run: Wardrobe (6.18\' x 2.12\') + Dressing Table (2.14\' x 1.67\')',
        'Kitchen with Breakfast Counter (2.03\'), Gas (3.61\' x 2.38\'), Sink & Fridge (2.17\')',
        'Ensuite Bathroom: Shower (5.91\' x 3.01\'), Commode (2.85\' x 4.10\'), Basin (2.14\' x 3.33\')',
      ],
      items: [
        // --- MASTER ROOM ---
        FloorItemModel(
          id: 'bed_1',
          name: 'King Bed (5.52\' × 6.25\')',
          category: 'Bedroom',
          widthFt: 5.52,
          lengthFt: 6.25,
          heightFt: 3.2,
          xFt: 0.6,
          yFt: 0.6,
          color: Color(0xFF6366F1), // Indigo
          notes: 'Standard King Bed with upholstered headboard & integrated side lighting',
        ),
        FloorItemModel(
          id: 'sofa_1',
          name: 'Sofa Unit (5.52\' × 5.42\')',
          category: 'Living',
          widthFt: 5.52,
          lengthFt: 5.42,
          heightFt: 2.7,
          xFt: 0.6,
          yFt: 12.0,
          color: Color(0xFFF59E0B), // Amber
          notes: 'Comfortable 3-seater lounge sofa with direct line of sight to TV unit',
        ),
        FloorItemModel(
          id: 'wardrobe_1',
          name: 'Sliding Wardrobe (2.12\' × 6.18\')',
          category: 'Storage',
          widthFt: 2.12,
          lengthFt: 6.18,
          heightFt: 8.0,
          xFt: 7.8,
          yFt: 0.6,
          color: Color(0xFF8B5CF6), // Purple
          notes: 'Sliding 3-door floor-to-ceiling wardrobe with upper luggage loft',
        ),
        FloorItemModel(
          id: 'dressing_1',
          name: 'Dressing Table (1.67\' × 2.14\')',
          category: 'Bedroom',
          widthFt: 1.67,
          lengthFt: 2.14,
          heightFt: 3.0,
          xFt: 8.2,
          yFt: 7.2,
          color: Color(0xFFEC4899), // Pink
          notes: 'Vanity mirror console with warm backlit LED ring',
        ),
        FloorItemModel(
          id: 'tv_1',
          name: 'TV Media Unit (1.67\' × 5.26\')',
          category: 'Entertainment',
          widthFt: 1.67,
          lengthFt: 5.26,
          heightFt: 1.6,
          xFt: 8.2,
          yFt: 10.0,
          color: Color(0xFF64748B), // Slate
          notes: '55" Wall mounted smart TV with floating media console',
        ),

        // --- BATHROOM ---
        FloorItemModel(
          id: 'shower_1',
          name: 'Shower Area (5.91\' × 3.01\')',
          category: 'Bathroom',
          widthFt: 5.91,
          lengthFt: 3.01,
          heightFt: 7.0,
          xFt: 0.6,
          yFt: 19.2,
          color: Color(0xFF06B6D4), // Cyan
          notes: 'Toughened glass partition with rain shower & floor drain slope',
        ),
        FloorItemModel(
          id: 'commode_1',
          name: 'WC Commode (2.85\' × 4.10\')',
          category: 'Bathroom',
          widthFt: 2.85,
          lengthFt: 4.10,
          heightFt: 2.6,
          xFt: 0.6,
          yFt: 22.4,
          color: Color(0xFF10B981), // Emerald
          notes: 'Wall-hung commode with concealed cistern',
        ),
        FloorItemModel(
          id: 'basin_1',
          name: 'Wash Basin (2.14\' × 3.33\')',
          category: 'Bathroom',
          widthFt: 2.14,
          lengthFt: 3.33,
          heightFt: 2.8,
          xFt: 3.8,
          yFt: 22.8,
          color: Color(0xFF14B8A6), // Teal
          notes: 'Countertop ceramic basin with under-counter storage',
        ),

        // --- KITCHEN ---
        FloorItemModel(
          id: 'gas_1',
          name: 'Gas Stove & Chimney (3.61\' × 2.38\')',
          category: 'Kitchen',
          widthFt: 3.61,
          lengthFt: 2.38,
          heightFt: 2.9,
          xFt: 10.8,
          yFt: 0.6,
          color: Color(0xFFEF4444), // Red
          notes: '4-Burner Gas Hob with high-suction chimney hood above',
        ),
        FloorItemModel(
          id: 'breakfast_1',
          name: 'Breakfast Counter (2.03\' Run)',
          category: 'Kitchen',
          widthFt: 2.03,
          lengthFt: 4.2,
          heightFt: 3.2,
          xFt: 10.8,
          yFt: 3.4,
          color: Color(0xFFD97706), // Amber
          notes: 'Quartz top breakfast bar with 2 bar stools',
        ),
        FloorItemModel(
          id: 'sink_1',
          name: 'Kitchen Sink (2.17\' × 3.49\')',
          category: 'Kitchen',
          widthFt: 2.17,
          lengthFt: 3.49,
          heightFt: 2.8,
          xFt: 15.2,
          yFt: 2.8,
          color: Color(0xFF0284C7), // Sky Blue
          notes: 'Double bowl stainless steel sink with pull-out mixer faucet',
        ),
        FloorItemModel(
          id: 'fridge_1',
          name: 'Refrigerator (2.17\' × 2.5\')',
          category: 'Kitchen',
          widthFt: 2.17,
          lengthFt: 2.5,
          heightFt: 6.0,
          xFt: 15.2,
          yFt: 6.8,
          color: Color(0xFF475569), // Dark Slate
          notes: 'Double door frost-free refrigerator',
        ),
      ],
    );
  }

  // --- STYLE 2: EXECUTIVE WORKSTATION & STUDY SUITE ---
  static FloorLayoutStyle _buildExecutiveWorkstationStyle() {
    return FloorLayoutStyle(
      type: LayoutStyleType.executiveWorkstation,
      title: '2. Executive Workstation & Study Suite',
      description:
          'Adds an ergonomic 4.5\' study & work-from-home desk alongside the sofa zone, perfectly side-lit with dedicated power conduits and high-capacity storage.',
      score: 96,
      highlights: [
        'Dedicated Work-From-Home Desk (4.5\' x 2.0\') with ergonomic chair space',
        'Queen Bed (5.0\' x 6.25\') preserving spacious walkways',
        'Extended Wardrobe with built-in bookshelf',
        'Parallel Galley Kitchen setup for rapid meal prep',
      ],
      items: [
        ..._buildBlueprintMasterStyle().items.where((i) => i.id != 'sofa_1' && i.id != 'bed_1'),
        const FloorItemModel(
          id: 'bed_2',
          name: 'Queen Bed (5.0\' × 6.25\')',
          category: 'Bedroom',
          widthFt: 5.0,
          lengthFt: 6.25,
          heightFt: 3.0,
          xFt: 0.6,
          yFt: 0.6,
          color: Color(0xFF6366F1),
        ),
        const FloorItemModel(
          id: 'study_desk_1',
          name: 'Executive Study Desk (4.5\' × 2.0\')',
          category: 'Workspace',
          widthFt: 4.5,
          lengthFt: 2.0,
          heightFt: 2.5,
          xFt: 0.6,
          yFt: 11.2,
          color: Color(0xFF0EA5E9),
          notes: 'Dual monitor desk with cable grommets & ergonomic chair space',
        ),
        const FloorItemModel(
          id: 'compact_sofa',
          name: '2-Seater Accent Lounge (4.8\' × 2.6\')',
          category: 'Living',
          widthFt: 4.8,
          lengthFt: 2.6,
          heightFt: 2.7,
          xFt: 0.6,
          yFt: 14.8,
          color: Color(0xFFF59E0B),
        ),
      ],
    );
  }

  // --- STYLE 3: LUXURY HOSPITALITY & ENTERTAINMENT SUITE ---
  static FloorLayoutStyle _buildLuxuryHospitalityStyle() {
    return FloorLayoutStyle(
      type: LayoutStyleType.luxuryHospitality,
      title: '3. Luxury Hospitality & Lounge Suite',
      description:
          'Features an L-Shape Sectional Chaise Lounge, Floating King Bed with warm cove perimeter lighting, and expanded Breakfast Island in Kitchen.',
      score: 94,
      highlights: [
        'L-Shape Sectional Lounge (5.52\' x 5.8\') with chaise',
        'Floating King Bed with ambient headboard lighting',
        'Island Breakfast Bar with under-counter wine chiller space',
        'Frameless walk-in glass shower enclosure',
      ],
      items: [
        ..._buildBlueprintMasterStyle().items.where((i) => i.id != 'sofa_1'),
        const FloorItemModel(
          id: 'l_sofa_1',
          name: 'L-Shape Sectional Sofa (5.52\' × 5.8\')',
          category: 'Living',
          widthFt: 5.52,
          lengthFt: 5.8,
          heightFt: 2.7,
          xFt: 0.6,
          yFt: 11.6,
          color: Color(0xFFF59E0B),
          notes: 'Plush velvet L-sectional with built-in storage chaise',
        ),
      ],
    );
  }

  // --- STYLE 4: MAXIMUM STORAGE & FAMILY SUITE ---
  static FloorLayoutStyle _buildMaxStorageStyle() {
    return FloorLayoutStyle(
      type: LayoutStyleType.maxStorageFamily,
      title: '4. Maximum Storage & Family Suite',
      description:
          'Maximizes storage capacity with hydraulic storage bed, extended 8.5\' wardrobe run with top loft, and high-capacity kitchen pantry tall-unit.',
      score: 92,
      highlights: [
        'Hydraulic Under-Bed Storage (5.52\' x 6.25\')',
        'Extended 4-Door Wardrobe (8.2\' x 2.12\') with full loft',
        'Full Appliance Tall Unit in Kitchen for Microwave & Oven',
      ],
      items: [
        ..._buildBlueprintMasterStyle().items.where((i) => i.id != 'wardrobe_1'),
        const FloorItemModel(
          id: 'max_wardrobe',
          name: 'Extended 4-Door Wardrobe (2.12\' × 8.2\')',
          category: 'Storage',
          widthFt: 2.12,
          lengthFt: 8.2,
          heightFt: 8.5,
          xFt: 7.8,
          yFt: 0.6,
          color: Color(0xFF8B5CF6),
          notes: 'Full-length floor to false ceiling wardrobe with internal organizers',
        ),
      ],
    );
  }
}
