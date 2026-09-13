import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architectural_design_option.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';

/// Central state manager & persistent storage for Architectural Floor Design Options.
/// Allows saving finalised designs, creating new design options from scratch,
/// duplicating/copying old designs to make custom changes, and permanently
/// persisting all designs to local storage across app sessions and reloads.
class DesignOptionManagerService {
  static const String _storageKey = 'homecraft_saved_design_options_v2';
  static const String _activeIdKey = 'homecraft_active_design_id_v2';

  static final List<ArchitecturalDesignOption> _savedDesigns = [];
  static String _activeDesignId = '';
  static bool _isInitialized = false;

  /// Initializes the service by loading persistent designs from local storage.
  /// If no saved designs exist, seeds with standard default layouts.
  static Future<void> init({bool forceReload = false}) async {
    if (_isInitialized && !forceReload) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJsonString = prefs.getString(_storageKey);

      if (savedJsonString != null && savedJsonString.trim().isNotEmpty) {
        final dynamic decoded = jsonDecode(savedJsonString);
        if (decoded is List) {
          _savedDesigns.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              _savedDesigns.add(ArchitecturalDesignOption.fromJson(item));
            }
          }
        }
      } else if (forceReload) {
        _savedDesigns.clear();
      }

      final savedActiveId = prefs.getString(_activeIdKey);
      if (savedActiveId != null && savedActiveId.isNotEmpty) {
        _activeDesignId = savedActiveId;
      }
    } catch (e) {
      // Fallback on in-memory defaults if decoding fails
    }

    if (_savedDesigns.isEmpty) {
      _initDefaultDesigns();
      _persistDesigns();
    } else if (_activeDesignId.isEmpty || !_savedDesigns.any((d) => d.id == _activeDesignId)) {
      _activeDesignId = _savedDesigns.first.id;
    }

    _isInitialized = true;
  }

  /// Synchronous getter returning all saved designs.
  static List<ArchitecturalDesignOption> get designs {
    if (_savedDesigns.isEmpty && !_isInitialized) {
      _initDefaultDesigns();
    }
    return List.unmodifiable(_savedDesigns);
  }

  /// Active design ID currently being edited in CAD Studio.
  static String get activeDesignId {
    if (_activeDesignId.isEmpty && designs.isNotEmpty) {
      _activeDesignId = designs.first.id;
    }
    return _activeDesignId;
  }

  /// The active design option model currently loaded.
  static ArchitecturalDesignOption get activeDesign {
    final list = designs;
    return list.firstWhere(
      (d) => d.id == activeDesignId,
      orElse: () => list.first,
    );
  }

  /// Returns the most recently edited or created design option (for quick 1-click continue).
  static ArchitecturalDesignOption get latestEditedDesign {
    final list = designs;
    if (list.isEmpty) return activeDesign;
    final sorted = List<ArchitecturalDesignOption>.from(list)
      ..sort((a, b) => b.lastModified.compareTo(a.lastModified));
    return sorted.first;
  }

  static void _initDefaultDesigns() {
    final defaultDims = DynamicFloorDimensions(
      unit: DimensionUnit.feet,
      roomWidth: 10.5,
      roomLength: 18.5,
      bathWidth: 5.91,
      bathLength: 7.5,
      kitchenWidth: 7.6,
      kitchenLength: 9.8,
    );

    // 1. Design Option A (Standard Master Suite)
    final optA = ArchitecturalDesignOption(
      id: 'option_a_standard',
      name: 'Option A: Master Suite (Balanced)',
      description: 'Standard ergonomic layout with West Bed, East Wardrobe, South TV console, and Dressing mirror.',
      dims: defaultDims.clone(),
      placements: [
        RoomItemPlacement(
          id: 'item_bed_std',
          itemName: 'King Size Bed (6×6.5 ft)',
          targetWall: 'West Wall (W)',
          facingDirection: 'Facing East (→)',
          rotationDegrees: 90,
          customWidth: 6.5,
          customLength: 6.0,
          customPosX: 0.0,
          customPosY: 4.5,
        ),
        RoomItemPlacement(
          id: 'item_wardrobe_std',
          itemName: 'Full Height 3-Door Wardrobe',
          targetWall: 'East Wall (E)',
          facingDirection: 'Facing West (←)',
          rotationDegrees: 270,
          customWidth: 2.2,
          customLength: 6.8,
          customPosX: defaultDims.roomWidth - 2.2,
          customPosY: 1.5,
        ),
        RoomItemPlacement(
          id: 'item_tv_std',
          itemName: 'TV Media & Entertainment Console',
          targetWall: 'South Wall (S)',
          facingDirection: 'Facing North (↑)',
          rotationDegrees: 0,
          customWidth: 5.0,
          customLength: 1.5,
          customPosX: 2.8,
          customPosY: 0.0,
        ),
        RoomItemPlacement(
          id: 'item_dress_std',
          itemName: 'Dressing Frame & Mirror',
          targetWall: 'North-West Corner (N-W)',
          facingDirection: 'Facing South (↓)',
          rotationDegrees: 180,
          customWidth: 3.5,
          customLength: 1.8,
          customPosX: 0.0,
          customPosY: defaultDims.roomLength - 1.8,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      lastModified: DateTime.now().subtract(const Duration(hours: 3)),
      isFinalized: false,
    );

    // 2. Design Option B (Deep Storage & Workstation)
    final optB = ArchitecturalDesignOption(
      id: 'option_b_executive',
      name: 'Option B: Executive Suite & Workstation',
      description: 'Optimized for remote work with dedicated study desk, expansive wardrobe, and queen bed.',
      dims: defaultDims.clone(),
      placements: [
        RoomItemPlacement(
          id: 'item_bed_b',
          itemName: 'Queen Size Bed (5×6.5 ft)',
          targetWall: 'West Wall (W)',
          facingDirection: 'Facing East (→)',
          rotationDegrees: 90,
          customWidth: 6.5,
          customLength: 5.0,
          customPosX: 0.0,
          customPosY: 3.0,
        ),
        RoomItemPlacement(
          id: 'item_wardrobe_b',
          itemName: 'Wall-to-Wall Luxury Wardrobe Run',
          targetWall: 'East Wall (E)',
          facingDirection: 'Facing West (←)',
          rotationDegrees: 270,
          customWidth: 2.2,
          customLength: 9.0,
          customPosX: defaultDims.roomWidth - 2.2,
          customPosY: 0.5,
        ),
        RoomItemPlacement(
          id: 'item_study_b',
          itemName: 'Ergonomic Executive Study Desk',
          targetWall: 'North Wall (N)',
          facingDirection: 'Facing South (↓)',
          rotationDegrees: 180,
          customWidth: 4.8,
          customLength: 2.4,
          customPosX: 0.5,
          customPosY: defaultDims.roomLength - 2.4,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      lastModified: DateTime.now().subtract(const Duration(minutes: 45)),
      isFinalized: false,
    );

    _savedDesigns.clear();
    _savedDesigns.addAll([optA, optB]);
    _activeDesignId = optA.id;
  }

  /// Sets the active design option by ID and persists active pointer.
  static ArchitecturalDesignOption switchActiveDesign(String designId) {
    final idx = _savedDesigns.indexWhere((d) => d.id == designId);
    if (idx != -1) {
      _activeDesignId = designId;
      _persistActiveId();
      return _savedDesigns[idx];
    }
    return activeDesign;
  }

  /// Saves / overwrites changes to the currently active design option with immediate local persistence.
  static ArchitecturalDesignOption saveCurrentDesign({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
    String? newName,
    String? newDescription,
  }) {
    final current = activeDesign;
    final now = DateTime.now();

    final updated = current.copyWith(
      name: newName ?? current.name,
      description: newDescription ?? current.description,
      dims: dims.clone(),
      placements: placements.map((p) => p.copyWith()).toList(),
      lastModified: now,
    );

    final idx = _savedDesigns.indexWhere((d) => d.id == current.id);
    if (idx != -1) {
      _savedDesigns[idx] = updated;
    } else {
      _savedDesigns.add(updated);
    }
    _activeDesignId = updated.id;
    _persistDesigns();
    return updated;
  }

  /// Creates and saves a brand new design option with custom name and dimensions.
  static ArchitecturalDesignOption createNewDesignOption({
    required String name,
    String description = '',
    DynamicFloorDimensions? dims,
    List<RoomItemPlacement>? initialPlacements,
  }) {
    final now = DateTime.now();
    final newId = 'design_${now.millisecondsSinceEpoch}_${math.Random().nextInt(999)}';
    final newOption = ArchitecturalDesignOption(
      id: newId,
      name: name.trim().isEmpty ? 'Design Option ${_savedDesigns.length + 1}' : name.trim(),
      description: description.trim(),
      dims: dims != null ? dims.clone() : DynamicFloorDimensions(),
      placements: initialPlacements != null ? initialPlacements.map((p) => p.copyWith()).toList() : [],
      createdAt: now,
      lastModified: now,
      isFinalized: false,
    );

    _savedDesigns.add(newOption);
    _activeDesignId = newOption.id;
    _persistDesigns();
    return newOption;
  }

  /// Duplicates an existing design option into a brand new design.
  static ArchitecturalDesignOption duplicateDesignOption(
    String sourceDesignId, {
    String? newName,
    String? newDescription,
  }) {
    final source = _savedDesigns.firstWhere(
      (d) => d.id == sourceDesignId,
      orElse: () => activeDesign,
    );

    final cloned = source.duplicate(
      newName: newName ?? '${source.name} (Copy)',
      newDescription: newDescription,
    );

    _savedDesigns.add(cloned);
    _activeDesignId = cloned.id;
    _persistDesigns();
    return cloned;
  }

  /// Finalizes and approves the design plan with a certified timestamp & notes.
  static ArchitecturalDesignOption finalizeDesign(
    String designId, {
    String? approvalNotes,
  }) {
    final idx = _savedDesigns.indexWhere((d) => d.id == designId);
    if (idx != -1) {
      final now = DateTime.now();
      final finalized = _savedDesigns[idx].copyWith(
        isFinalized: true,
        finalizedAt: now,
        finalizedNotes: approvalNotes ?? 'Verified and approved for construction fabrication.',
        lastModified: now,
      );
      _savedDesigns[idx] = finalized;
      _persistDesigns();
      return finalized;
    }
    return activeDesign;
  }

  /// Reopens / unlocks a finalized design for revision.
  static ArchitecturalDesignOption unlockFinalizedDesign(String designId) {
    final idx = _savedDesigns.indexWhere((d) => d.id == designId);
    if (idx != -1) {
      final reopened = _savedDesigns[idx].copyWith(
        isFinalized: false,
        lastModified: DateTime.now(),
      );
      _savedDesigns[idx] = reopened;
      _persistDesigns();
      return reopened;
    }
    return activeDesign;
  }

  /// Deletes a saved design option. Ensures at least one design remains available.
  static bool deleteDesignOption(String designId) {
    if (_savedDesigns.length <= 1) return false;
    _savedDesigns.removeWhere((d) => d.id == designId);
    if (_activeDesignId == designId) {
      _activeDesignId = _savedDesigns.first.id;
    }
    _persistDesigns();
    return true;
  }

  /// Asynchronously persists all design options to SharedPreferences.
  static Future<void> _persistDesigns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _savedDesigns.map((d) => d.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(jsonList));
      await prefs.setString(_activeIdKey, _activeDesignId);
    } catch (e) {
      // Storage error handled gracefully
    }
  }

  /// Persists the active design ID pointer.
  static Future<void> _persistActiveId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeIdKey, _activeDesignId);
    } catch (e) {
      // Storage error handled gracefully
    }
  }
}
