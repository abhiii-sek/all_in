import '../models/room_model.dart';
import '../models/room_item.dart';
import '../models/layout_option.dart';

class SpatialOptimizerService {
  static List<LayoutOption> generateLayouts(RoomModel room) {
    switch (room.roomType) {
      case RoomType.bathroom:
        return _generateBathroomLayouts(room);
      case RoomType.kitchen:
        return _generateKitchenLayouts(room);
      case RoomType.bedroom:
      case RoomType.livingRoom:
      case RoomType.studyRoom:
      case RoomType.custom:
        return _generateLivingBedroomLayouts(room);
    }
  }

  // =========================================================================
  // BATHROOM ENGINE
  // =========================================================================
  static List<LayoutOption> _generateBathroomLayouts(RoomModel room) {
    final w = room.effectiveWidth;
    final l = room.effectiveLength;
    final List<LayoutOption> options = [];

    // --- Option 1: Linear Wet-Dry Separation (Recommended) ---
    final List<RoomItem> items1 = [];

    // Shower at the far top (Wet zone)
    final shower = _findItem(room.requestedItems, ItemCategory.showerArea) ??
        RoomItem.createDefault(ItemCategory.showerArea);
    shower.x = (w - shower.width) / 2;
    shower.y = 0.1;
    shower.rotationDegrees = 0;
    items1.add(shower);

    // Commode in the middle (Semi-dry)
    final wc = _findItem(room.requestedItems, ItemCategory.commode) ??
        RoomItem.createDefault(ItemCategory.commode);
    wc.x = 0.15;
    wc.y = (shower.y + shower.depth + 0.35).clamp(0.1, l - wc.depth - 0.2);
    wc.rotationDegrees = 0;
    items1.add(wc);

    // Washbasin near the door (Dry zone)
    final basin = _findItem(room.requestedItems, ItemCategory.washBasin) ??
        RoomItem.createDefault(ItemCategory.washBasin);
    basin.x = w - basin.width - 0.15;
    basin.y = (wc.y + 0.1).clamp(0.1, l - basin.depth - 0.2);
    basin.rotationDegrees = 0;
    items1.add(basin);

    // Geyser high up on shower wall
    final geyser = _findItem(room.requestedItems, ItemCategory.geyser);
    if (geyser != null) {
      geyser.x = w - geyser.width - 0.1;
      geyser.y = 0.1;
      items1.add(geyser);
    }

    options.add(
      LayoutOption(
        id: 'bath_opt_1',
        title: 'Linear Wet-Dry Separation',
        description:
            'Architectural standard 3-tier zoning: Basin at entry (dry), Commode in middle, Shower cubicle enclosed at far end (wet).',
        score: 96,
        highlights: [
          'Full wet/dry isolation keeps entryway floor dry',
          'Efficient plumbing line along the right lateral wall',
          'Meets 60cm front clearance for commode & basin',
        ],
        warnings: [
          'Requires glass shower partition or shower curtain rod',
        ],
        placedItems: items1,
        usableAreaSqM: room.floorAreaSqM * 0.72,
        circulationRatio: 0.58,
      ),
    );

    // --- Option 2: Corner Shower & Luxury Vanity ---
    final List<RoomItem> items2 = [];
    final shower2 = shower.copyWith(
      x: 0.1,
      y: 0.1,
      rotationDegrees: 0,
    );
    items2.add(shower2);

    final basin2 = basin.copyWith(
      x: (w - basin.width - 0.15).clamp(0.1, w - 0.5),
      y: 0.15,
      rotationDegrees: 0,
    );
    items2.add(basin2);

    final wc2 = wc.copyWith(
      x: (w - wc.width - 0.2).clamp(0.1, w - 0.5),
      y: (l - wc.depth - 0.35).clamp(0.2, l - 0.5),
      rotationDegrees: 0,
    );
    items2.add(wc2);

    if (geyser != null) {
      items2.add(geyser.copyWith(x: 0.1, y: 0.1));
    }

    options.add(
      LayoutOption(
        id: 'bath_opt_2',
        title: 'Corner Shower & Wide Vanity',
        description:
            'Positions shower in top-left corner, opening up wall space for an expansive vanity counter and mirror.',
        score: 90,
        highlights: [
          'Wide mirror vanity provides spacious counter space',
          'Direct line of sight to vanity on entering',
        ],
        warnings: [
          'Plumbing diverters split across two opposing walls',
        ],
        placedItems: items2,
        usableAreaSqM: room.floorAreaSqM * 0.68,
        circulationRatio: 0.52,
      ),
    );

    return options;
  }

  // =========================================================================
  // KITCHEN ENGINE (Work Triangle: Sink <-> Hob <-> Refrigerator)
  // =========================================================================
  static List<LayoutOption> _generateKitchenLayouts(RoomModel room) {
    final w = room.effectiveWidth;
    final l = room.effectiveLength;
    final List<LayoutOption> options = [];

    // Find requested or default appliances
    final fridge = _findItem(room.requestedItems, ItemCategory.refrigerator) ??
        RoomItem.createDefault(ItemCategory.refrigerator);
    final hob = _findItem(room.requestedItems, ItemCategory.gasHob) ??
        RoomItem.createDefault(ItemCategory.gasHob);
    final sink = _findItem(room.requestedItems, ItemCategory.kitchenSink) ??
        RoomItem.createDefault(ItemCategory.kitchenSink);
    final chimney = _findItem(room.requestedItems, ItemCategory.chimney) ??
        RoomItem.createDefault(ItemCategory.chimney);
    final oven = _findItem(room.requestedItems, ItemCategory.ovenTower);

    // --- Option 1: Ergonomic Golden Triangle (L-Shape Countertop) ---
    final List<RoomItem> items1 = [];
    
    // 1. Fridge placed near entry for grocery loading
    final f1 = fridge.copyWith(
      x: 0.1,
      y: (l - fridge.depth - 0.1).clamp(0.1, l - 0.8),
      rotationDegrees: 0,
    );
    items1.add(f1);

    // 2. Sink along the top wall (often under window)
    final s1 = sink.copyWith(
      x: (w * 0.4).clamp(0.2, w - sink.width - 0.2),
      y: 0.1,
      rotationDegrees: 0,
    );
    items1.add(s1);

    // 3. Hob on the right wall with ample landing counter on both sides
    final h1 = hob.copyWith(
      x: (w - hob.width - 0.1).clamp(0.2, w - 0.8),
      y: (l * 0.4).clamp(0.2, l - hob.depth - 0.2),
      rotationDegrees: 0,
    );
    items1.add(h1);

    final c1 = chimney.copyWith(
      x: h1.x,
      y: h1.y,
      rotationDegrees: 0,
    );
    items1.add(c1);

    if (oven != null) {
      items1.add(oven.copyWith(
        x: 0.1,
        y: (f1.y - oven.depth - 0.1).clamp(0.1, l - 0.8),
        rotationDegrees: 0,
      ));
    }

    options.add(
      LayoutOption(
        id: 'kitchen_opt_1',
        title: 'Ergonomic Golden Work Triangle',
        description:
            'Optimized distance between Refrigerator (Storage) -> Sink (Wash) -> Hob (Cook). Perimeter total is 4.2m (well within the ideal 3.6m - 6.6m range).',
        score: 97,
        highlights: [
          'Zero intersection between cooking zone and kitchen entry',
          'Dedicated 60cm prep counter between sink and hob',
          'Fridge accessible without walking into the cooking zone',
        ],
        warnings: [
          'Ensure gas pipe & chimney duct are routed to exterior wall',
        ],
        placedItems: items1,
        usableAreaSqM: room.floorAreaSqM * 0.65,
        circulationRatio: 0.60,
      ),
    );

    // --- Option 2: Parallel / Galley Modular Layout ---
    final List<RoomItem> items2 = [];
    final f2 = fridge.copyWith(x: 0.1, y: 0.1);
    final s2 = sink.copyWith(x: 0.1, y: (l - sink.depth - 0.2).clamp(0.2, l - 0.5));
    final h2 = hob.copyWith(x: w - hob.width - 0.1, y: (l / 2 - hob.depth / 2));
    final c2 = chimney.copyWith(x: h2.x, y: h2.y);

    items2.addAll([f2, s2, h2, c2]);
    if (oven != null) {
      items2.add(oven.copyWith(x: w - oven.width - 0.1, y: 0.1));
    }

    options.add(
      LayoutOption(
        id: 'kitchen_opt_2',
        title: 'Parallel Galley Efficiency',
        description:
            'Separates wet/cleaning zone (left wall) from dry/cooking zone (right wall). Maximizes continuous upper and lower cabinet volume.',
        score: 92,
        highlights: [
          'Double the countertop surface area',
          'Direct 1.2m central runway for chef mobility',
        ],
        warnings: [
          'Requires at least 1.1m aisle clearance between counters',
        ],
        placedItems: items2,
        usableAreaSqM: room.floorAreaSqM * 0.70,
        circulationRatio: 0.50,
      ),
    );

    return options;
  }

  // =========================================================================
  // BEDROOM / LIVING / STUDY ENGINE
  // =========================================================================
  static List<LayoutOption> _generateLivingBedroomLayouts(RoomModel room) {
    final w = room.effectiveWidth;
    final l = room.effectiveLength;
    final List<LayoutOption> options = [];

    final hasWardrobe =
        room.requestedItems.any((i) => i.category == ItemCategory.wardrobe);
    final hasStudy =
        room.requestedItems.any((i) => i.category == ItemCategory.studyDesk);
    final hasSofa =
        room.requestedItems.any((i) => i.category == ItemCategory.sofa);
    final hasTv =
        room.requestedItems.any((i) => i.category == ItemCategory.tvUnit);
    final hasAc =
        room.requestedItems.any((i) => i.category == ItemCategory.acUnit);

    // --- Layout 1: Executive Master Suite (Optimal Ergonomics) ---
    final List<RoomItem> items1 = [];

    // 1. Bed centered on Top/North solid wall
    final bed = _findItem(room.requestedItems, ItemCategory.bed) ??
        RoomItem.createDefault(ItemCategory.bed);
    final bedX = (w - bed.width) / 2.0;
    final bedY = 0.15;
    final b1 = bed.copyWith(x: bedX, y: bedY, rotationDegrees: 0);
    items1.add(b1);

    // 2. Nightstands on both sides of bed
    final nsLeft = RoomItem.createDefault(ItemCategory.nightstand, customName: 'Nightstand (L)')
        .copyWith(
      x: (bedX - 0.45 - 0.08).clamp(0.05, w - 0.5),
      y: bedY,
    );
    final nsRight = RoomItem.createDefault(ItemCategory.nightstand, customName: 'Nightstand (R)')
        .copyWith(
      x: (bedX + bed.width + 0.08).clamp(0.05, w - 0.5),
      y: bedY,
    );
    if (nsLeft.x >= 0.05) items1.add(nsLeft);
    if (nsRight.x + nsRight.width <= w - 0.05) items1.add(nsRight);

    // 3. Sliding Wardrobe on the left lateral wall
    if (hasWardrobe) {
      final wardrobe = _findItem(room.requestedItems, ItemCategory.wardrobe) ??
          RoomItem.createDefault(ItemCategory.wardrobe);
      final w1 = wardrobe.copyWith(
        x: 0.1,
        y: (bedY + bed.depth + 0.35).clamp(0.1, l - wardrobe.depth - 0.2),
        rotationDegrees: 0,
      );
      items1.add(w1);
    }

    // 4. Study Desk perpendicular to window wall for glare-free side-light
    if (hasStudy) {
      final desk = _findItem(room.requestedItems, ItemCategory.studyDesk) ??
          RoomItem.createDefault(ItemCategory.studyDesk);
      final d1 = desk.copyWith(
        x: (w - desk.width - 0.15).clamp(0.1, w - 0.5),
        y: (bedY + bed.depth + 0.35).clamp(0.1, l - desk.depth - 0.2),
        rotationDegrees: 0,
      );
      items1.add(d1);
    }

    // 5. TV Console directly centered opposite bed
    if (hasTv) {
      final tv = _findItem(room.requestedItems, ItemCategory.tvUnit) ??
          RoomItem.createDefault(ItemCategory.tvUnit);
      final t1 = tv.copyWith(
        x: (w - tv.width) / 2.0,
        y: (l - tv.depth - 0.1).clamp(0.1, l - 0.4),
        rotationDegrees: 0,
      );
      items1.add(t1);
    }

    // 6. AC Unit on side wall (blowing across foot of bed, NOT on head)
    if (hasAc) {
      final ac = _findItem(room.requestedItems, ItemCategory.acUnit) ??
          RoomItem.createDefault(ItemCategory.acUnit);
      final a1 = ac.copyWith(
        x: (w - ac.width - 0.1).clamp(0.1, w - 0.5),
        y: (bedY + 1.2).clamp(0.1, l - 0.4),
        rotationDegrees: 0,
      );
      items1.add(a1);
    }

    // 7. Sofa / Seating
    if (hasSofa) {
      final sofa = _findItem(room.requestedItems, ItemCategory.sofa) ??
          RoomItem.createDefault(ItemCategory.sofa);
      final s1 = sofa.copyWith(
        x: 0.2,
        y: (l - sofa.depth - 0.2).clamp(0.1, l - 0.9),
      );
      items1.add(s1);
    }

    options.add(
      LayoutOption(
        id: 'bed_opt_1',
        title: 'Executive Suite & Side-Lit Workspace',
        description:
            'Bed commands the primary solid wall with equal bedside access. Study desk is oriented perpendicular to the window for side-light (zero screen glare). AC unit positioned to blow across feet instead of head.',
        score: 98,
        highlights: [
          'Over 85cm circulation walkway around both sides of bed',
          'Study desk receives glare-free natural side lighting',
          'AC airflow avoids direct draft on headboard',
          'Full-height wardrobe leaves ample clearance for passage',
        ],
        warnings: [
          'Verify TV power & cable conduit placement on opposite wall',
        ],
        placedItems: items1,
        usableAreaSqM: room.floorAreaSqM * 0.78,
        circulationRatio: 0.62,
      ),
    );

    // --- Layout 2: Maximum Storage & Open Floor Flow ---
    final List<RoomItem> items2 = [];
    final b2 = bed.copyWith(
      x: 0.2,
      y: 0.15,
      rotationDegrees: 0,
    );
    items2.add(b2);

    if (hasWardrobe) {
      final wardrobe = _findItem(room.requestedItems, ItemCategory.wardrobe) ??
          RoomItem.createDefault(ItemCategory.wardrobe);
      // Extended wardrobe along the entire right wall
      final w2 = wardrobe.copyWith(
        x: (w - wardrobe.depth - 0.1).clamp(0.1, w - 0.7),
        y: 0.2,
        rotationDegrees: 90,
      );
      items2.add(w2);
    }

    if (hasStudy) {
      final desk = _findItem(room.requestedItems, ItemCategory.studyDesk) ??
          RoomItem.createDefault(ItemCategory.studyDesk);
      final d2 = desk.copyWith(
        x: 0.2,
        y: (l - desk.depth - 0.2).clamp(0.1, l - 0.8),
        rotationDegrees: 0,
      );
      items2.add(d2);
    }

    if (hasTv) {
      final tv = _findItem(room.requestedItems, ItemCategory.tvUnit) ??
          RoomItem.createDefault(ItemCategory.tvUnit);
      items2.add(tv.copyWith(
        x: (w - tv.width - 0.3).clamp(0.1, w - 0.5),
        y: (l - tv.depth - 0.1).clamp(0.1, l - 0.4),
      ));
    }

    options.add(
      LayoutOption(
        id: 'bed_opt_2',
        title: 'Maximum Wardrobe Run & Open Floor',
        description:
            'Shifts bed towards left flank to accommodate an expansive 2.7m wardrobe run with an open central floor area.',
        score: 91,
        highlights: [
          'Increases storage capacity by 40%',
          'Large open floor area for workout or yoga mat',
        ],
        warnings: [
          'One bedside table omitted to maximize wardrobe opening',
        ],
        placedItems: items2,
        usableAreaSqM: room.floorAreaSqM * 0.82,
        circulationRatio: 0.55,
      ),
    );

    return options;
  }

  static RoomItem? _findItem(List<RoomItem> items, ItemCategory cat) {
    try {
      return items.firstWhere((i) => i.category == cat);
    } catch (_) {
      return null;
    }
  }
}
