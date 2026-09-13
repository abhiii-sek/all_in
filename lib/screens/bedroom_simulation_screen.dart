import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dynamic_floor_model.dart';
import '../services/architectural_prompt_service.dart';
import '../services/url_launcher_helper.dart';
import '../widgets/blueprint_canvas/dynamic_floor_2d_painter.dart';

enum CameraPreset {
  isometric3D,
  firstPersonEyeLevel,
  topDownPlan,
  bedsideFocus,
  studyDeskFocus,
  wardrobeFocus,
}

enum SimulationNavMode {
  firstPersonWalk,
  orbit3D,
  cinematicDrone,
}

enum PlayerPosture {
  standing, // 5.5 ft
  sitting, // 3.8 ft
  lyingOnBed, // 2.2 ft
}

enum LightingMode {
  daylight,
  goldenHour,
  cozyNight,
  luxuryDark,
}

enum RgbMoodTheme {
  warmScandinavian,
  cyberpunkNeon,
  japandiTwilight,
  biophilicEmerald,
}

enum FlooringTheme {
  herringboneOak,
  carraraMarble,
  darkWalnut,
  tatamiMat,
  polishedTerrazzo,
}

enum WallFinishTheme {
  flutedWoodSlats,
  venetianPlaster,
  charcoalAcoustic,
  sandGreige,
}

/// Spatial Model for Placed 3D Furniture Items in the Simulation
class Item3DSpatial {
  final MathematicalItemDimension mathItem;
  final RoomItemPlacement placement;
  final double x;
  final double y;
  final double z;
  final double width;
  final double length;
  final double height;
  final String facingDirection;
  final String targetWall;
  final Color baseColor;
  final Color topColor;
  final bool isSelected;

  const Item3DSpatial({
    required this.mathItem,
    required this.placement,
    required this.x,
    required this.y,
    required this.z,
    required this.width,
    required this.length,
    required this.height,
    required this.facingDirection,
    required this.targetWall,
    required this.baseColor,
    required this.topColor,
    this.isSelected = false,
  });

  String get id => placement.id.isNotEmpty ? placement.id : mathItem.id;
  String get itemName => placement.itemName;
  String? get amazonUrl => placement.amazonUrl ?? mathItem.amazonUrl;
  String? get imageUrl => placement.imageUrl ?? mathItem.imageUrl;
  String? get productPrice => placement.productPrice ?? mathItem.productPrice;
  String? get productBrand => placement.productBrand ?? mathItem.productBrand;
  String? get customNotes => placement.customNotes;

  Offset get center2D => Offset(x + width / 2.0, y + length / 2.0);

  static List<Item3DSpatial> computeItemSpatials({
    required DynamicFloorDimensions dims,
    required List<RoomItemPlacement> placements,
    required List<MathematicalItemDimension> calculatedItems,
    String? selectedItemId,
  }) {
    if (placements.isEmpty) return [];

    const canvasSize = Size(1800, 1500);
    const scale = 28.0;
    final origin = DynamicFloor2DPainter.getOrigin(dims: dims, canvasSize: canvasSize, scale: scale);
    final rectMap = DynamicFloor2DPainter.calculateItemRects(
      dims: dims,
      items: calculatedItems,
      canvasSize: canvasSize,
      scale: scale,
    );

    final List<Item3DSpatial> results = [];

    for (int i = 0; i < calculatedItems.length; i++) {
      final mathItem = calculatedItems[i];
      final placement = (i < placements.length)
          ? placements[i]
          : RoomItemPlacement(itemName: mathItem.itemName, targetWall: mathItem.targetWall);

      final rect = rectMap[mathItem.id] ?? Rect.fromLTWH(origin.dx + 28, origin.dy + 28, 28 * 3.5, 28 * 3.5);
      final roomX = (rect.left - origin.dx) / scale;
      final roomY = (rect.top - origin.dy) / scale;
      final roomW = rect.width / scale;
      final roomL = rect.height / scale;

      // Determine 3D height
      double roomH = mathItem.height;
      if (placement.customHeight != null && placement.customHeight! > 0) {
        roomH = placement.customHeight!;
      } else if (roomH <= 0) {
        final name = mathItem.itemName.toLowerCase();
        if (name.contains('wardrobe') || name.contains('closet') || name.contains('cupboard') || name.contains('almirah')) {
          roomH = 7.5;
        } else if (name.contains('bed')) {
          roomH = 2.2;
        } else if (name.contains('study') || name.contains('desk') || name.contains('table') || name.contains('work')) {
          roomH = 2.5;
        } else if (name.contains('tv') || name.contains('media') || name.contains('console')) {
          roomH = 1.8;
        } else if (name.contains('sofa') || name.contains('couch') || name.contains('chair')) {
          roomH = 2.4;
        } else if (name.contains('book') || name.contains('shelf') || name.contains('cabinet')) {
          roomH = 6.5;
        } else {
          roomH = 3.0;
        }
      }

      final roomZ = placement.customElevation ?? mathItem.customElevation ?? 0.0;
      final baseColor = DynamicFloor2DPainter.getItemColor(placement.id, placement.itemName, i);
      final topColor = baseColor.withValues(alpha: 0.85);
      final isSelected = selectedItemId != null && (placement.id == selectedItemId || mathItem.id == selectedItemId);

      results.add(
        Item3DSpatial(
          mathItem: mathItem,
          placement: placement,
          x: roomX,
          y: roomY,
          z: roomZ,
          width: roomW,
          length: roomL,
          height: roomH,
          facingDirection: mathItem.facingDirection,
          targetWall: mathItem.targetWall,
          baseColor: baseColor,
          topColor: topColor,
          isSelected: isSelected,
        ),
      );
    }

    return results;
  }
}

class BedroomSimulationScreen extends StatefulWidget {
  final DynamicFloorDimensions dims;
  final List<RoomItemPlacement> placements;
  final String? initialFocusItemId;

  const BedroomSimulationScreen({
    super.key,
    required this.dims,
    required this.placements,
    this.initialFocusItemId,
  });

  @override
  State<BedroomSimulationScreen> createState() => _BedroomSimulationScreenState();
}

class _BedroomSimulationScreenState extends State<BedroomSimulationScreen>
    with TickerProviderStateMixin {
  late DynamicFloorDimensions _dims;
  late List<RoomItemPlacement> _placements;

  // Navigation & Camera State - Defaults to First-Person Walk
  SimulationNavMode _navMode = SimulationNavMode.firstPersonWalk;
  double _rotationYaw = 35.0; // degrees
  double _pitchAngle = 30.0; // degrees
  double _zoomScale = 1.0;
  Offset _panOffset = Offset.zero;
  CameraPreset _currentPreset = CameraPreset.firstPersonEyeLevel;

  // First-Person Walk & Sightline State
  double _walkPlayerX = 5.0; // ft inside room
  double _walkPlayerY = 3.5; // ft inside room
  double _walkPlayerYaw = 0.0; // degrees (0 = looking North towards headboard wall)
  double _walkPlayerPitch = 0.0; // degrees (tilt up/down)
  PlayerPosture _playerPosture = PlayerPosture.standing;
  bool _flashlightOn = false;

  // Exploded Dollhouse BIM View
  double _explodeFactor = 0.0;

  // 24-Hour Sun Path & Dynamic Shadows Engine
  double _timeOfDayHour = 14.5; // 2:30 PM
  LightingMode _lightingMode = LightingMode.daylight;
  RgbMoodTheme _rgbMood = RgbMoodTheme.warmScandinavian;

  // Interactive Room Elements State
  bool _bedsideLampOn = true;
  bool _studyLampOn = true;
  bool _tvScreenOn = true;
  bool _underBedGlowOn = true;
  bool _wardrobeDoorOpen = false;

  // Material & Finish Studio
  FlooringTheme _flooringTheme = FlooringTheme.herringboneOak;
  WallFinishTheme _wallFinishTheme = WallFinishTheme.flutedWoodSlats;

  // Spatial Analytics & Overlays
  final bool _showDimensionsOverlay = true;
  final bool _showProductPins = true;
  bool _showErgonomicsHeatmap = false;
  bool _showMiniRadar = true;

  // Cinematic Drone Tour State
  Timer? _droneTourTimer;
  double _droneProgress = 0.0;
  double _droneSpeedMultiplier = 1.0;
  String _droneCurrentCaption = 'Cinematic Drone • Master Bedroom Overview';

  // Selected Item / Amazon Product HUD State
  String? _selectedItemId;
  final GlobalKey _simulationBoundaryKey = GlobalKey();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _dims = widget.dims.clone();
    _placements = widget.placements.map((p) => p.copyWith()).toList();
    _walkPlayerX = _dims.roomWidth / 2.0;
    _walkPlayerY = 3.2;
    _selectedItemId = widget.initialFocusItemId;
    if (_selectedItemId != null) {
      _applyFocusToItem(_selectedItemId!);
    }
  }

  @override
  void dispose() {
    _droneTourTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  double get _currentEyeHeight {
    switch (_playerPosture) {
      case PlayerPosture.standing:
        return 5.5; // ft
      case PlayerPosture.sitting:
        return 3.8; // ft
      case PlayerPosture.lyingOnBed:
        return 2.2; // ft
    }
  }

  void _applyFocusToItem(String itemId) {
    final item = _placements.firstWhere((p) => p.id == itemId, orElse: () => _placements.first);
    final name = item.itemName.toLowerCase();
    setState(() {
      _selectedItemId = itemId;
      if (name.contains('bed')) {
        _setCameraPreset(CameraPreset.bedsideFocus);
      } else if (name.contains('study') || name.contains('desk') || name.contains('table')) {
        _setCameraPreset(CameraPreset.studyDeskFocus);
      } else if (name.contains('wardrobe') || name.contains('closet')) {
        _setCameraPreset(CameraPreset.wardrobeFocus);
      }
    });
  }

  void _setCameraPreset(CameraPreset preset) {
    final calcItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );
    final spatials = Item3DSpatial.computeItemSpatials(
      dims: _dims,
      placements: _placements,
      calculatedItems: calcItems,
      selectedItemId: _selectedItemId,
    );

    setState(() {
      _currentPreset = preset;
      _stopDroneTour();
      switch (preset) {
        case CameraPreset.isometric3D:
          _navMode = SimulationNavMode.orbit3D;
          _rotationYaw = 35.0;
          _pitchAngle = 30.0;
          _zoomScale = 1.0;
          _panOffset = Offset.zero;
          break;
        case CameraPreset.firstPersonEyeLevel:
          _navMode = SimulationNavMode.firstPersonWalk;
          _walkPlayerX = _dims.roomWidth / 2.0;
          _walkPlayerY = 3.2;
          _walkPlayerYaw = 0.0;
          _walkPlayerPitch = 0.0;
          _playerPosture = PlayerPosture.standing;
          break;
        case CameraPreset.topDownPlan:
          _navMode = SimulationNavMode.orbit3D;
          _rotationYaw = 0.0;
          _pitchAngle = 88.0;
          _zoomScale = 1.1;
          _panOffset = Offset.zero;
          break;
        case CameraPreset.bedsideFocus:
          _navMode = SimulationNavMode.firstPersonWalk;
          final bed = spatials.cast<Item3DSpatial?>().firstWhere(
            (s) => s != null && s.itemName.toLowerCase().contains('bed'),
            orElse: () => null,
          );
          if (bed != null) {
            _walkPlayerX = (bed.x + bed.width / 2.0).clamp(1.0, _dims.roomWidth - 1.0);
            _walkPlayerY = (bed.y + bed.length / 2.0).clamp(1.0, _dims.roomLength - 1.0);
          } else {
            _walkPlayerX = (_dims.roomWidth - 6.5) / 2.0 - 0.5;
            _walkPlayerY = _dims.roomLength - 4.5;
          }
          _walkPlayerYaw = 45.0;
          _playerPosture = PlayerPosture.lyingOnBed;
          break;
        case CameraPreset.studyDeskFocus:
          _navMode = SimulationNavMode.firstPersonWalk;
          final desk = spatials.cast<Item3DSpatial?>().firstWhere(
            (s) => s != null && (s.itemName.toLowerCase().contains('study') || s.itemName.toLowerCase().contains('desk')),
            orElse: () => null,
          );
          if (desk != null) {
            _walkPlayerX = (desk.x + desk.width / 2.0).clamp(1.0, _dims.roomWidth - 1.0);
            _walkPlayerY = (desk.y + desk.length / 2.0).clamp(1.0, _dims.roomLength - 1.0);
          } else {
            _walkPlayerX = _dims.roomWidth - 3.2;
            _walkPlayerY = _dims.roomLength - 4.0;
          }
          _walkPlayerYaw = -30.0;
          _playerPosture = PlayerPosture.sitting;
          break;
        case CameraPreset.wardrobeFocus:
          _navMode = SimulationNavMode.firstPersonWalk;
          final wardrobe = spatials.cast<Item3DSpatial?>().firstWhere(
            (s) => s != null && (s.itemName.toLowerCase().contains('wardrobe') || s.itemName.toLowerCase().contains('closet')),
            orElse: () => null,
          );
          if (wardrobe != null) {
            _walkPlayerX = (wardrobe.x + wardrobe.width / 2.0).clamp(1.0, _dims.roomWidth - 1.0);
            _walkPlayerY = (wardrobe.y + wardrobe.length / 2.0).clamp(1.0, _dims.roomLength - 1.0);
          } else {
            _walkPlayerX = 2.8;
            _walkPlayerY = 3.5;
          }
          _walkPlayerYaw = -90.0;
          _playerPosture = PlayerPosture.standing;
          break;
      }
    });
  }

  // Cinematic Drone Tour Engine
  void _startDroneTour() {
    setState(() {
      _navMode = SimulationNavMode.cinematicDrone;
      _explodeFactor = 0.0;
    });
    _droneTourTimer?.cancel();
    _droneTourTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) return;
      setState(() {
        _droneProgress = (_droneProgress + 0.003 * _droneSpeedMultiplier) % 1.0;
        _rotationYaw = (_droneProgress * 360.0);
        _pitchAngle = 24.0 + math.sin(_droneProgress * math.pi * 4) * 8.0;
        _zoomScale = 1.25 + math.cos(_droneProgress * math.pi * 2) * 0.25;
        _panOffset = Offset(
          math.sin(_droneProgress * math.pi * 2) * 40,
          math.cos(_droneProgress * math.pi * 2) * 20,
        );

        if (_droneProgress < 0.25) {
          _droneCurrentCaption = 'Cinematic Drone • Master Bedroom Architectural Tour';
        } else if (_droneProgress < 0.50) {
          _droneCurrentCaption = 'Cinematic Drone • Dynamic Lighting & Space Elevation';
        } else if (_droneProgress < 0.75) {
          _droneCurrentCaption = 'Cinematic Drone • Custom Placed Fixtures & Clearances';
        } else {
          _droneCurrentCaption = 'Cinematic Drone • Virtual Room Walkthrough & Overview';
        }
      });
    });
  }

  void _stopDroneTour() {
    _droneTourTimer?.cancel();
    _droneTourTimer = null;
    if (_navMode == SimulationNavMode.cinematicDrone) {
      setState(() {
        _navMode = SimulationNavMode.firstPersonWalk;
      });
    }
  }

  // First-Person Walk Movement Engine
  void _movePlayer(double deltaForward, double deltaStrafe) {
    final yawRad = (_walkPlayerYaw * math.pi / 180.0);
    final cosY = math.cos(yawRad);
    final sinY = math.sin(yawRad);

    // Forward/backward vector + strafe vector
    final dx = (-sinY * deltaForward + cosY * deltaStrafe);
    final dy = (cosY * deltaForward + sinY * deltaStrafe);

    const margin = 1.0;
    setState(() {
      _walkPlayerX = (_walkPlayerX + dx).clamp(margin, _dims.roomWidth - margin);
      _walkPlayerY = (_walkPlayerY + dy).clamp(margin, _dims.roomLength - margin);
    });
  }

  // Check Proximity to Placed Furniture Items
  RoomItemPlacement? _getClosestFurnitureProximity(List<Item3DSpatial> spatials) {
    if (spatials.isEmpty) return null;
    final playerPos = Offset(_walkPlayerX, _walkPlayerY);
    Item3DSpatial? closest;
    double minDistance = double.infinity;

    for (final s in spatials) {
      final itemCenter = s.center2D;
      final dist = (playerPos - itemCenter).distance;
      final threshold = s.itemName.toLowerCase().contains('bed') ? 5.0 : 3.8;
      if (dist <= threshold && dist < minDistance) {
        minDistance = dist;
        closest = s;
      }
    }

    return closest?.placement;
  }

  // Calculate Sightline Distance to TV or primary focus item from Current Eye Position
  double _calculateSightlineToTvDistance(List<Item3DSpatial> spatials) {
    if (spatials.isEmpty) return 0.0;
    final target = spatials.firstWhere(
      (s) => s.itemName.toLowerCase().contains('tv') ||
             s.itemName.toLowerCase().contains('media') ||
             s.itemName.toLowerCase().contains('console') ||
             s.itemName.toLowerCase().contains('screen'),
      orElse: () => spatials.firstWhere(
        (s) => s.itemName.toLowerCase().contains('bed'),
        orElse: () => spatials.first,
      ),
    );

    final targetPos = target.center2D;
    final targetZ = target.z + target.height / 2.0;
    final playerPos = Offset(_walkPlayerX, _walkPlayerY);
    final dist2D = (playerPos - targetPos).distance;
    final deltaZ = (targetZ - _currentEyeHeight).abs();
    return math.sqrt(dist2D * dist2D + deltaZ * deltaZ);
  }

  Offset _projectSpatialPoint(double x, double y, double z, Size size) {
    final yaw = _navMode == SimulationNavMode.firstPersonWalk ? _walkPlayerYaw : _rotationYaw;
    final pitch = _navMode == SimulationNavMode.firstPersonWalk ? (12.0 + _walkPlayerPitch) : _pitchAngle;
    final zoom = _navMode == SimulationNavMode.firstPersonWalk ? 1.75 : _zoomScale;
    final pan = _navMode == SimulationNavMode.firstPersonWalk
        ? Offset((_dims.roomWidth / 2 - _walkPlayerX) * 48, (_dims.roomLength / 2 - _walkPlayerY) * 38)
        : _panOffset;

    final center = Offset(size.width / 2 + pan.dx, size.height / 2 + pan.dy);
    final baseScale = (size.width < 800 ? 32.0 : 42.0) * zoom;
    final yawRad = (yaw * math.pi / 180.0);
    final pitchRad = (pitch * math.pi / 180.0);

    final cx = x - (_dims.roomWidth / 2.0);
    final cy = y - (_dims.roomLength / 2.0);
    final cz = z;

    final rx = cx * math.cos(yawRad) - cy * math.sin(yawRad);
    final ry = cx * math.sin(yawRad) + cy * math.cos(yawRad);
    final rz = cz;

    final px = rx * baseScale;
    final py = (-ry * math.sin(pitchRad) - rz * math.cos(pitchRad)) * baseScale;

    return Offset(center.dx + px, center.dy + py);
  }

  // Calculate Total Amazon Staged Cost
  double _calculateTotalAmazonCost() {
    double total = 0.0;
    for (final p in _placements) {
      if (p.productPrice != null && p.productPrice!.isNotEmpty) {
        final clean = p.productPrice!.replaceAll(RegExp(r'[^0-9.]'), '');
        final val = double.tryParse(clean);
        if (val != null) {
          total += val;
        }
      }
    }
    return total;
  }

  int _countAmazonLinkedItems() {
    return _placements.where((p) => p.amazonUrl != null && p.amazonUrl!.trim().isNotEmpty).length;
  }

  void _showAmazonStagingSummarySheet() {
    final totalCost = _calculateTotalAmazonCost();
    final amazonItems = _placements.where((p) => p.amazonUrl != null && p.amazonUrl!.trim().isNotEmpty).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9900).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.shopping_cart, color: Color(0xFFFF9900), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Amazon Room Staging Cart',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${amazonItems.length} Linked Products in Bedroom',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      'Total: \$${totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFF1E293B)),
              const SizedBox(height: 8),

              if (amazonItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No Amazon products linked yet. Tap any furniture item in 3D to attach an Amazon URL!',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: amazonItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final it = amazonItems[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: it.imageUrl != null && it.imageUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        it.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.chair, color: Color(0xFFFF9900)),
                                      ),
                                    )
                                  : const Icon(Icons.chair, color: Color(0xFFFF9900)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.itemName,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    it.productBrand ?? 'Amazon Choice',
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (it.productPrice != null && it.productPrice!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Text(
                                  it.productPrice!,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text('View'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF9900),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () => UrlLauncherHelper.openUrl(it.amazonUrl!),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF334155)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 16),
                      label: const Text('Add Amazon Item'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF38BDF8),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddNewProductModal();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddNewProductModal() {
    final nameCtrl = TextEditingController(text: 'Modern Floating Nightstand');
    final amazonUrlCtrl = TextEditingController(text: 'https://www.amazon.com/dp/B08XYZ1234');
    final imageUrlCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '\$129.00');
    final brandCtrl = TextEditingController(text: 'Amazon Basics');
    String selectedWall = 'West Wall (W)';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9900).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_shopping_cart, color: Color(0xFFFF9900), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Add Amazon Product to 3D Room', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dialogTextField(nameCtrl, 'Product Name', Icons.chair),
                  const SizedBox(height: 12),
                  _dialogTextField(amazonUrlCtrl, 'Amazon Product URL', Icons.link),
                  const SizedBox(height: 12),
                  _dialogTextField(imageUrlCtrl, 'Image URL (Optional)', Icons.image),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _dialogTextField(priceCtrl, 'Price (e.g. \$129.00)', Icons.attach_money)),
                      const SizedBox(width: 10),
                      Expanded(child: _dialogTextField(brandCtrl, 'Brand / Seller', Icons.storefront)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Place on Wall:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedWall,
                        dropdownColor: const Color(0xFF1E293B),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'West Wall (W)', child: Text('West Wall (W) - Bedside')),
                          DropdownMenuItem(value: 'North Wall (N)', child: Text('North Wall (N) - Back Wall')),
                          DropdownMenuItem(value: 'East Wall (E)', child: Text('East Wall (E) - TV / Console')),
                          DropdownMenuItem(value: 'South Wall (S)', child: Text('South Wall (S) - Entry Wall')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedWall = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9900),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                final newPlacement = RoomItemPlacement(
                  id: 'item_custom_${DateTime.now().millisecondsSinceEpoch}',
                  itemName: nameCtrl.text.trim(),
                  targetWall: selectedWall,
                  amazonUrl: amazonUrlCtrl.text.trim(),
                  imageUrl: imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null,
                  productPrice: priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null,
                  productBrand: brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
                );
                setState(() {
                  _placements.add(newPlacement);
                  _selectedItemId = newPlacement.id;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF10B981),
                    content: Text('Added "${nameCtrl.text}" to 3D simulation!'),
                  ),
                );
              },
              child: const Text('Simulate in 3D', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogTextField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
      ),
    );
  }

  List<Widget> _buildFloatingProductBadges(Size viewportSize, List<Item3DSpatial> spatials) {
    if (!_showProductPins || _navMode == SimulationNavMode.firstPersonWalk) {
      return const [];
    }

    final List<Widget> badges = [];
    for (final s in spatials) {
      final hasImg = s.imageUrl != null && s.imageUrl!.trim().isNotEmpty;
      final hasAmazon = s.amazonUrl != null && s.amazonUrl!.trim().isNotEmpty;
      if (!hasImg && !hasAmazon) continue;

      final screenPos = _projectSpatialPoint(
        s.x + s.width / 2.0,
        s.y + s.length / 2.0,
        s.z + s.height + 0.4,
        viewportSize,
      );

      if (screenPos.dx >= 40 &&
          screenPos.dx <= viewportSize.width - 40 &&
          screenPos.dy >= 60 &&
          screenPos.dy <= viewportSize.height - 80) {
        badges.add(
          Positioned(
            left: screenPos.dx - 80,
            top: screenPos.dy - 65,
            child: _buildFloatingProductTag(s),
          ),
        );
      }
    }
    return badges;
  }

  Widget _buildFloatingProductTag(Item3DSpatial s) {
    final hasImg = s.imageUrl != null && s.imageUrl!.trim().isNotEmpty;
    final isSelected = _selectedItemId == s.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItemId = s.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFFF9900),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9900).withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasImg) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  s.imageUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 32,
                    height: 32,
                    color: const Color(0xFF1E293B),
                    child: const Icon(Icons.shopping_bag, color: Color(0xFFFF9900), size: 16),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      s.itemName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9900),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text('AMAZON', style: TextStyle(color: Colors.black, fontSize: 7.5, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                if (s.productPrice != null && s.productPrice!.isNotEmpty)
                  Text(
                    s.productPrice!,
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSimulationAppBar() {
    final amazonCount = _countAmazonLinkedItems();
    return AppBar(
      backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.92),
      elevation: 0,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '3D Room Simulation',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${_dims.roomWidth.toStringAsFixed(1)}\' × ${_dims.roomLength.toStringAsFixed(1)}\'',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${_placements.length} Placed Items • Parametric 3D BIM',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        // Flashlight toggle in walk mode
        if (_navMode == SimulationNavMode.firstPersonWalk)
          IconButton(
            tooltip: _flashlightOn ? 'Turn Flashlight Off' : 'Turn Flashlight On',
            icon: Icon(
              _flashlightOn ? Icons.flashlight_on : Icons.flashlight_off,
              color: _flashlightOn ? const Color(0xFFFBBF24) : Colors.white60,
              size: 20,
            ),
            onPressed: () => setState(() => _flashlightOn = !_flashlightOn),
          ),

        // Radar toggle in walk mode
        if (_navMode == SimulationNavMode.firstPersonWalk)
          IconButton(
            tooltip: _showMiniRadar ? 'Hide 2D Radar' : 'Show 2D Radar',
            icon: Icon(
              Icons.radar,
              color: _showMiniRadar ? const Color(0xFF38BDF8) : Colors.white60,
              size: 20,
            ),
            onPressed: () => setState(() => _showMiniRadar = !_showMiniRadar),
          ),

        // Ergonomics heatmap toggle in orbit mode
        if (_navMode == SimulationNavMode.orbit3D)
          IconButton(
            tooltip: _showErgonomicsHeatmap ? 'Hide Ergonomics Heatmap' : 'Show Ergonomics Heatmap',
            icon: Icon(
              Icons.grid_on_rounded,
              color: _showErgonomicsHeatmap ? const Color(0xFF10B981) : Colors.white60,
              size: 20,
            ),
            onPressed: () => setState(() => _showErgonomicsHeatmap = !_showErgonomicsHeatmap),
          ),

        // Amazon Cart & Staging Summary
        if (amazonCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: InkWell(
              onTap: _showAmazonStagingSummarySheet,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9900).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF9900), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shopping_cart_outlined, color: Color(0xFFFF9900), size: 16),
                    const SizedBox(width: 5),
                    Text(
                      '$amazonCount Amazon Item${amazonCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Color(0xFFFF9900),
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Reset camera view
        IconButton(
          tooltip: 'Reset View',
          icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
          onPressed: () => _setCameraPreset(CameraPreset.firstPersonEyeLevel),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTopModeSwitcher() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
              ),
              child: const Text(
                'WALKTHROUGH 2.0',
                style: TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _modeTabButton(
              label: '🚶 First-Person Walk',
              isActive: _navMode == SimulationNavMode.firstPersonWalk,
              onTap: () {
                _stopDroneTour();
                setState(() {
                  _navMode = SimulationNavMode.firstPersonWalk;
                  _explodeFactor = 0.0;
                });
              },
            ),
            const SizedBox(width: 4),
            _modeTabButton(
              label: '🌐 3D Orbit',
              isActive: _navMode == SimulationNavMode.orbit3D,
              onTap: () {
                _stopDroneTour();
                setState(() {
                  _navMode = SimulationNavMode.orbit3D;
                });
              },
            ),
            const SizedBox(width: 4),
            _modeTabButton(
              label: '🎬 Drone Tour',
              isActive: _navMode == SimulationNavMode.cinematicDrone,
              onTap: () {
                _startDroneTour();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeTabButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF38BDF8), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calcItems = ArchitecturalPromptService.calculateDimensions(
      dims: _dims,
      placements: _placements,
    );
    final spatials = Item3DSpatial.computeItemSpatials(
      dims: _dims,
      placements: _placements,
      calculatedItems: calcItems,
      selectedItemId: _selectedItemId,
    );

    final selectedPlacement = _placements.cast<RoomItemPlacement?>().firstWhere(
      (p) => p?.id == _selectedItemId,
      orElse: () => null,
    );

    final nearbyPlacement = _getClosestFurnitureProximity(spatials);
    final sightlineToTv = _calculateSightlineToTvDistance(spatials);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.keyW || event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _movePlayer(0.6, 0);
          } else if (event.logicalKey == LogicalKeyboardKey.keyS || event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _movePlayer(-0.6, 0);
          } else if (event.logicalKey == LogicalKeyboardKey.keyA || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _movePlayer(0, -0.6);
          } else if (event.logicalKey == LogicalKeyboardKey.keyD || event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _movePlayer(0, 0.6);
          } else if (event.logicalKey == LogicalKeyboardKey.keyQ) {
            setState(() => _walkPlayerYaw = (_walkPlayerYaw - 15) % 360);
          } else if (event.logicalKey == LogicalKeyboardKey.keyE) {
            setState(() => _walkPlayerYaw = (_walkPlayerYaw + 15) % 360);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF080D1A),
        appBar: _buildSimulationAppBar(),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              children: [
                // 1. Interactive 3D Canvas
                Positioned.fill(
                  child: GestureDetector(
                    onScaleUpdate: _navMode == SimulationNavMode.orbit3D
                        ? (details) {
                            setState(() {
                              if (details.pointerCount == 1) {
                                _rotationYaw = (_rotationYaw - details.focalPointDelta.dx * 0.45) % 360;
                                _pitchAngle = (_pitchAngle + details.focalPointDelta.dy * 0.35).clamp(5.0, 89.0);
                              } else if (details.pointerCount >= 2) {
                                _zoomScale = (_zoomScale * details.scale).clamp(0.5, 3.5);
                              }
                            });
                          }
                        : (details) {
                            // In Walk mode, dragging rotates eye orientation
                            setState(() {
                              _walkPlayerYaw = (_walkPlayerYaw - details.focalPointDelta.dx * 0.35) % 360;
                              _walkPlayerPitch = (_walkPlayerPitch - details.focalPointDelta.dy * 0.25).clamp(-30.0, 30.0);
                            });
                          },
                    child: CustomPaint(
                      key: _simulationBoundaryKey,
                      painter: _Bedroom3DSimulationPainter(
                        dims: _dims,
                        calculatedItems: calcItems,
                        placements: _placements,
                        spatials: spatials,
                        selectedItemId: _selectedItemId,
                        rotationYaw: _navMode == SimulationNavMode.firstPersonWalk ? _walkPlayerYaw : _rotationYaw,
                        pitchAngle: _navMode == SimulationNavMode.firstPersonWalk ? (12.0 + _walkPlayerPitch) : _pitchAngle,
                        zoomScale: _navMode == SimulationNavMode.firstPersonWalk ? 1.75 : _zoomScale,
                        panOffset: _navMode == SimulationNavMode.firstPersonWalk
                            ? Offset((_dims.roomWidth / 2 - _walkPlayerX) * 48, (_dims.roomLength / 2 - _walkPlayerY) * 38)
                            : _panOffset,
                        lightingMode: _lightingMode,
                        timeOfDayHour: _timeOfDayHour,
                        rgbMood: _rgbMood,
                        flooringTheme: _flooringTheme,
                        wallFinishTheme: _wallFinishTheme,
                        explodeFactor: _explodeFactor,
                        showDimensions: _showDimensionsOverlay,
                        showProductPins: _showProductPins,
                        showErgonomicsHeatmap: _showErgonomicsHeatmap,
                        bedsideLampOn: _bedsideLampOn,
                        studyLampOn: _studyLampOn,
                        tvScreenOn: _tvScreenOn,
                        underBedGlowOn: _underBedGlowOn,
                        wardrobeDoorOpen: _wardrobeDoorOpen,
                        navMode: _navMode,
                        playerX: _walkPlayerX,
                        playerY: _walkPlayerY,
                        eyeHeight: _currentEyeHeight,
                        flashlightOn: _flashlightOn,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),

                // 2. 3D Floating Product Image Hologram / Billboard Cards
                ..._buildFloatingProductBadges(viewportSize, spatials),

                // 3. Navigation Mode Selector & Cinematic Banner
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: _buildTopModeSwitcher(),
                ),

                // 4. Mini Architectural Radar in Top-Left (during First-Person Walk)
                if (_navMode == SimulationNavMode.firstPersonWalk && _showMiniRadar)
                  Positioned(
                    top: 72,
                    left: 16,
                    child: _buildMiniRadarCard(sightlineToTv, spatials),
                  ),

                // 5. Proximity Action Pill (Interactive Object Trigger)
                if (_navMode == SimulationNavMode.firstPersonWalk && nearbyPlacement != null)
                  Positioned(
                    top: 72,
                    right: 16,
                    child: _buildProximityActionCard(nearbyPlacement),
                  ),

                // 6. First-Person Walk Dual Analog Controller
                if (_navMode == SimulationNavMode.firstPersonWalk)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: _buildWalkControlBar(sightlineToTv),
                  ),

                // 7. Cinematic Drone Tour Director Overlay
                if (_navMode == SimulationNavMode.cinematicDrone)
                  Positioned(
                    bottom: 90,
                    left: 20,
                    right: 20,
                    child: _buildCinematicDirectorHUD(),
                  ),

                // 8. Floating Amazon Product HUD Inspector (when item tapped in 3D orbit)
                if (selectedPlacement != null && _navMode == SimulationNavMode.orbit3D)
                  Positioned(
                    bottom: 24,
                    right: 20,
                    width: 380,
                    child: _buildAmazonProductHUDCard(selectedPlacement),
                  ),

                // 9. Exploded BIM & Time-of-Day Floating Control Dock
                if (_navMode == SimulationNavMode.orbit3D)
                  Positioned(
                    bottom: 24,
                    left: 20,
                    child: _buildSpatialStudioDock(),
                  ),

                // 10. Right Side Camera Orbit Shortcuts
                if (_navMode == SimulationNavMode.orbit3D)
                  Positioned(
                    top: 80,
                    right: 16,
                    child: _buildOrbitQuickControls(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Mini Radar Card showing 2D floor overview with player position dot & vision cone
  Widget _buildMiniRadarCard(double sightlineDist, List<Item3DSpatial> spatials) {
    return Container(
      width: 160,
      height: 155,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('RADAR', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  '(${_walkPlayerX.toStringAsFixed(1)}\', ${_walkPlayerY.toStringAsFixed(1)}\')',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: Colors.white54, fontSize: 8.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              painter: _MiniRadarPainter(
                roomW: _dims.roomWidth,
                roomL: _dims.roomLength,
                playerX: _walkPlayerX,
                playerY: _walkPlayerY,
                playerYaw: _walkPlayerYaw,
                spatials: spatials,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TV Sight: ${sightlineDist.toStringAsFixed(1)} ft',
            style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Interactive Proximity Action Card (triggers when close to placed room item)
  Widget _buildProximityActionCard(RoomItemPlacement item) {
    final title = item.itemName;
    final nameLower = item.itemName.toLowerCase();
    IconData icon = Icons.inventory_2;
    List<Widget> actions = [];

    if (nameLower.contains('bed')) {
      icon = Icons.bed;
      actions.addAll([
        _proximityActionButton('🛏️ Lie Down', () => setState(() => _playerPosture = PlayerPosture.lyingOnBed)),
        _proximityActionButton('💡 Lamps', () => setState(() => _bedsideLampOn = !_bedsideLampOn)),
        _proximityActionButton('✨ Underglow', () => setState(() => _underBedGlowOn = !_underBedGlowOn)),
      ]);
    } else if (nameLower.contains('wardrobe') || nameLower.contains('closet') || nameLower.contains('cupboard') || nameLower.contains('almirah')) {
      icon = Icons.sensor_door;
      actions.add(
        _proximityActionButton(_wardrobeDoorOpen ? '🚪 Close' : '🚪 Slide Open', () => setState(() => _wardrobeDoorOpen = !_wardrobeDoorOpen)),
      );
    } else if (nameLower.contains('study') || nameLower.contains('desk') || nameLower.contains('table') || nameLower.contains('work')) {
      icon = Icons.desk;
      actions.addAll([
        _proximityActionButton('🪑 Sit Down', () => setState(() => _playerPosture = PlayerPosture.sitting)),
        _proximityActionButton('💡 Desk Lamp', () => setState(() => _studyLampOn = !_studyLampOn)),
      ]);
    } else if (nameLower.contains('tv') || nameLower.contains('media') || nameLower.contains('console') || nameLower.contains('entertainment')) {
      icon = Icons.tv;
      actions.add(
        _proximityActionButton(_tvScreenOn ? '📺 Turn Off' : '📺 Power ON', () => setState(() => _tvScreenOn = !_tvScreenOn)),
      );
    } else if (nameLower.contains('sofa') || nameLower.contains('couch') || nameLower.contains('chair') || nameLower.contains('seating')) {
      icon = Icons.chair;
      actions.add(
        _proximityActionButton('🪑 Sit Down', () => setState(() => _playerPosture = PlayerPosture.sitting)),
      );
    }

    if (item.amazonUrl != null && item.amazonUrl!.trim().isNotEmpty) {
      actions.add(
        _proximityActionButton('🛒 Amazon', () => UrlLauncherHelper.openUrl(item.amazonUrl!)),
      );
    }

    actions.add(
      _proximityActionButton('🔍 Inspect', () => setState(() { _selectedItemId = item.id; _navMode = SimulationNavMode.orbit3D; })),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF9900), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF9900).withValues(alpha: 0.2),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFFFF9900), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Nearby: $title',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: actions,
            ),
          ),
        ],
      ),
    );
  }

  Widget _proximityActionButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFF9900).withValues(alpha: 0.5)),
          ),
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFFFF9900), fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ),
    );
  }

  // Walk Control Bar with Dual Controls & Sightline Readout
  Widget _buildWalkControlBar(double sightlineDist) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Move Joystick D-Pad
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF38BDF8)),
                onPressed: () => _movePlayer(0, -0.6),
                tooltip: 'Strafe Left (A)',
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, color: Color(0xFF38BDF8)),
                    onPressed: () => _movePlayer(0.6, 0),
                    tooltip: 'Walk Forward (W)',
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, color: Color(0xFF38BDF8)),
                    onPressed: () => _movePlayer(-0.6, 0),
                    tooltip: 'Walk Backward (S)',
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Color(0xFF38BDF8)),
                onPressed: () => _movePlayer(0, 0.6),
                tooltip: 'Strafe Right (D)',
              ),
            ],
          ),

          // Center: Sightline HUD
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.visibility, color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Eye Sightline to TV: ${sightlineDist.toStringAsFixed(1)} ft',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Direct & Unobstructed 4K Line of Sight (WASD or Touch to Walk)',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // Posture Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<PlayerPosture>(
                value: _playerPosture,
                dropdownColor: const Color(0xFF0F172A),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF38BDF8), size: 16),
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                onChanged: (val) {
                  if (val != null) setState(() => _playerPosture = val);
                },
                items: const [
                  DropdownMenuItem(
                    value: PlayerPosture.standing,
                    child: Text('🧍 Standing (5.5 ft)'),
                  ),
                  DropdownMenuItem(
                    value: PlayerPosture.sitting,
                    child: Text('🪑 Sitting (3.8 ft)'),
                  ),
                  DropdownMenuItem(
                    value: PlayerPosture.lyingOnBed,
                    child: Text('🛏️ Lying on Bed (2.2 ft)'),
                  ),
                ],
              ),
            ),
          ),

          // Right: Look / Turn Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.turn_left, color: Color(0xFFF59E0B)),
                onPressed: () => setState(() => _walkPlayerYaw = (_walkPlayerYaw - 25) % 360),
                tooltip: 'Turn Left (Q)',
              ),
              IconButton(
                icon: const Icon(Icons.turn_right, color: Color(0xFFF59E0B)),
                onPressed: () => setState(() => _walkPlayerYaw = (_walkPlayerYaw + 25) % 360),
                tooltip: 'Turn Right (E)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Cinematic Director HUD
  Widget _buildCinematicDirectorHUD() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.videocam, color: Color(0xFFEF4444), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text('● REC DIRECTORS CUT', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 10)),
                    SizedBox(width: 8),
                    Text('360° Spline Flight', style: TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _droneCurrentCaption,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<double>(
            segments: const [
              ButtonSegment(value: 0.5, label: Text('0.5x', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: 1.0, label: Text('1x', style: TextStyle(fontSize: 10))),
              ButtonSegment(value: 2.0, label: Text('2x', style: TextStyle(fontSize: 10))),
            ],
            selected: {_droneSpeedMultiplier},
            onSelectionChanged: (val) => setState(() => _droneSpeedMultiplier = val.first),
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              selectedBackgroundColor: const Color(0xFF38BDF8),
              selectedForegroundColor: Colors.black,
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Exit Tour'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: _stopDroneTour,
          ),
        ],
      ),
    );
  }

  // Exploded BIM & Time-of-Day Studio Dock (in 3D Orbit)
  Widget _buildSpatialStudioDock() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          // 1. Exploded Dollhouse Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.unfold_more, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Exploded BIM (${(_explodeFactor * 100).toInt()}%)',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                width: 130,
                child: Slider(
                  value: _explodeFactor,
                  activeColor: const Color(0xFF38BDF8),
                  inactiveColor: const Color(0xFF1E293B),
                  onChanged: (val) => setState(() => _explodeFactor = val),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          const VerticalDivider(color: Color(0xFF334155), width: 1),
          const SizedBox(width: 12),

          // 2. 24-Hr Time of Day Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    _timeOfDayHour >= 6 && _timeOfDayHour <= 18 ? Icons.wb_sunny : Icons.nightlight_round,
                    color: const Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Sun Path (${_timeOfDayHour.toInt()}:00)',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(
                width: 130,
                child: Slider(
                  value: _timeOfDayHour,
                  min: 0.0,
                  max: 24.0,
                  activeColor: const Color(0xFFF59E0B),
                  inactiveColor: const Color(0xFF1E293B),
                  onChanged: (val) {
                    setState(() {
                      _timeOfDayHour = val;
                      if (val >= 7.0 && val <= 16.0) {
                        _lightingMode = LightingMode.daylight;
                      } else if (val > 16.0 && val <= 19.5) {
                        _lightingMode = LightingMode.goldenHour;
                      } else {
                        _lightingMode = LightingMode.cozyNight;
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          const VerticalDivider(color: Color(0xFF334155), width: 1),
          const SizedBox(width: 12),

          // 3. Flooring Theme Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Flooring Finish', style: TextStyle(color: Colors.white70, fontSize: 10)),
              DropdownButtonHideUnderline(
                child: DropdownButton<FlooringTheme>(
                  value: _flooringTheme,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: FlooringTheme.herringboneOak, child: Text('🪵 Herringbone Oak')),
                    DropdownMenuItem(value: FlooringTheme.carraraMarble, child: Text('🏛️ Carrara Marble')),
                    DropdownMenuItem(value: FlooringTheme.darkWalnut, child: Text('🍫 Dark Walnut')),
                    DropdownMenuItem(value: FlooringTheme.tatamiMat, child: Text('🌾 Tatami Mat')),
                    DropdownMenuItem(value: FlooringTheme.polishedTerrazzo, child: Text('✨ Terrazzo')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _flooringTheme = val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          const VerticalDivider(color: Color(0xFF334155), width: 1),
          const SizedBox(width: 12),

          // 4. Wall Finish & RGB Mood
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Wall & LED Mood', style: TextStyle(color: Colors.white70, fontSize: 10)),
              DropdownButtonHideUnderline(
                child: DropdownButton<WallFinishTheme>(
                  value: _wallFinishTheme,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: WallFinishTheme.flutedWoodSlats, child: Text('🪵 Fluted Wood Slats')),
                    DropdownMenuItem(value: WallFinishTheme.venetianPlaster, child: Text('🎨 Venetian Plaster')),
                    DropdownMenuItem(value: WallFinishTheme.charcoalAcoustic, child: Text('⬛ Charcoal Acoustic')),
                    DropdownMenuItem(value: WallFinishTheme.sandGreige, child: Text('🪨 Sand Greige')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _wallFinishTheme = val);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          const VerticalDivider(color: Color(0xFF334155), width: 1),
          const SizedBox(width: 12),

          // 5. RGB LED Mood Atmosphere
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('LED Atmosphere', style: TextStyle(color: Colors.white70, fontSize: 10)),
              DropdownButtonHideUnderline(
                child: DropdownButton<RgbMoodTheme>(
                  value: _rgbMood,
                  dropdownColor: const Color(0xFF0F172A),
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: RgbMoodTheme.warmScandinavian, child: Text('🕯️ Warm 2700K')),
                    DropdownMenuItem(value: RgbMoodTheme.cyberpunkNeon, child: Text('⚡ Cyber Neon')),
                    DropdownMenuItem(value: RgbMoodTheme.japandiTwilight, child: Text('🌅 Amber Twilight')),
                    DropdownMenuItem(value: RgbMoodTheme.biophilicEmerald, child: Text('🌿 Emerald Glow')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _rgbMood = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  // Floating Amazon Product HUD Inspector Card
  Widget _buildAmazonProductHUDCard(RoomItemPlacement item) {
    final hasAmazon = item.amazonUrl != null && item.amazonUrl!.trim().isNotEmpty;

    return Card(
      elevation: 16,
      color: const Color(0xFF0F172A).withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: hasAmazon ? const Color(0xFFFF9900) : const Color(0xFF38BDF8),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.shopping_bag, color: Color(0xFFFF9900), size: 26),
                          ),
                        )
                      : const Icon(Icons.bed, color: Color(0xFF38BDF8), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.itemName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasAmazon)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9900),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('AMAZON', style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Text(
                              item.targetWall,
                              style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            if (item.productPrice != null && item.productPrice!.isNotEmpty) ...[
                              const Text(' • ', style: TextStyle(color: Colors.white38)),
                              Text(
                                item.productPrice!,
                                style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _selectedItemId = null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF1E293B), height: 1),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _metricChip('Wall Anchor', item.targetWall),
                if (item.productBrand != null) _metricChip('Brand', item.productBrand!),
              ],
            ),

            if (item.customNotes != null && item.customNotes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: ${item.customNotes}',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 14),

            Row(
              children: [
                if (hasAmazon)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Open Amazon (New Tab)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9900),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () => UrlLauncherHelper.openUrl(item.amazonUrl!),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add_link, size: 16),
                      label: const Text('Attach Amazon Product'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF9900),
                        side: const BorderSide(color: Color(0xFFFF9900)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => _showEditProductDialog(item),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Edit Item',
                  icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                  onPressed: () => _showEditProductDialog(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProductDialog(RoomItemPlacement item) {
    final nameCtrl = TextEditingController(text: item.itemName);
    final amazonUrlCtrl = TextEditingController(text: item.amazonUrl ?? '');
    final imageUrlCtrl = TextEditingController(text: item.imageUrl ?? '');
    final priceCtrl = TextEditingController(text: item.productPrice ?? '');
    final notesCtrl = TextEditingController(text: item.customNotes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit ${item.itemName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogTextField(nameCtrl, 'Item Name', Icons.chair),
              const SizedBox(height: 10),
              _dialogTextField(amazonUrlCtrl, 'Amazon Product Link', Icons.link),
              const SizedBox(height: 10),
              _dialogTextField(imageUrlCtrl, 'Image URL', Icons.image),
              const SizedBox(height: 10),
              _dialogTextField(priceCtrl, 'Price (e.g. \$499.00)', Icons.attach_money),
              const SizedBox(height: 10),
              _dialogTextField(notesCtrl, 'Placement Notes', Icons.notes),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38BDF8),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              setState(() {
                item.itemName = nameCtrl.text.trim();
                item.amazonUrl = amazonUrlCtrl.text.trim().isNotEmpty ? amazonUrlCtrl.text.trim() : null;
                item.imageUrl = imageUrlCtrl.text.trim().isNotEmpty ? imageUrlCtrl.text.trim() : null;
                item.productPrice = priceCtrl.text.trim().isNotEmpty ? priceCtrl.text.trim() : null;
                item.customNotes = notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          Text(val, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOrbitQuickControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom In (+)',
            icon: const Icon(Icons.zoom_in, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => setState(() => _zoomScale = (_zoomScale + 0.15).clamp(0.5, 3.5)),
          ),
          IconButton(
            tooltip: 'Zoom Out (-)',
            icon: const Icon(Icons.zoom_out, color: Color(0xFF38BDF8), size: 20),
            onPressed: () => setState(() => _zoomScale = (_zoomScale - 0.15).clamp(0.5, 3.5)),
          ),
          IconButton(
            tooltip: 'Rotate Left (↺)',
            icon: const Icon(Icons.rotate_left, color: Colors.white70, size: 20),
            onPressed: () => setState(() => _rotationYaw = (_rotationYaw - 15) % 360),
          ),
          IconButton(
            tooltip: 'Rotate Right (↻)',
            icon: const Icon(Icons.rotate_right, color: Colors.white70, size: 20),
            onPressed: () => setState(() => _rotationYaw = (_rotationYaw + 15) % 360),
          ),
          IconButton(
            tooltip: 'Isometric 3D View',
            icon: Icon(Icons.view_in_ar_rounded, color: _currentPreset == CameraPreset.isometric3D ? const Color(0xFF38BDF8) : Colors.white70, size: 20),
            onPressed: () => _setCameraPreset(CameraPreset.isometric3D),
          ),
          IconButton(
            tooltip: 'Top-Down Plan View',
            icon: Icon(Icons.layers_rounded, color: _currentPreset == CameraPreset.topDownPlan ? const Color(0xFF38BDF8) : Colors.white70, size: 20),
            onPressed: () => _setCameraPreset(CameraPreset.topDownPlan),
          ),
        ],
      ),
    );
  }
}

/// Mini Radar Custom Painter for First Person HUD
class _MiniRadarPainter extends CustomPainter {
  final double roomW;
  final double roomL;
  final double playerX;
  final double playerY;
  final double playerYaw;
  final List<Item3DSpatial> spatials;

  _MiniRadarPainter({
    required this.roomW,
    required this.roomL,
    required this.playerX,
    required this.playerY,
    required this.playerYaw,
    this.spatials = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / roomW;
    final scaleY = size.height / roomL;

    // Room boundary
    final roomRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(roomRect, Paint()..color = const Color(0xFF1E293B));
    canvas.drawRect(
      roomRect,
      Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    // Render exact footprints of all items placed in the room
    for (final s in spatials) {
      final itemRect = Rect.fromLTWH(
        s.x * scaleX,
        s.y * scaleY,
        s.width * scaleX,
        s.length * scaleY,
      );
      canvas.drawRect(itemRect, Paint()..color = s.baseColor.withValues(alpha: 0.75));
      canvas.drawRect(
        itemRect,
        Paint()
          ..color = s.baseColor
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke,
      );
    }

    // Player Dot
    final pDot = Offset(playerX * scaleX, playerY * scaleY);
    canvas.drawCircle(pDot, 4.0, Paint()..color = const Color(0xFF10B981));

    // Player Vision Cone (FOV)
    final yawRad = (playerYaw * math.pi / 180.0);
    const fovHalf = 30.0 * math.pi / 180.0;
    const coneLen = 28.0;

    final p1 = Offset(pDot.dx - math.sin(yawRad - fovHalf) * coneLen, pDot.dy + math.cos(yawRad - fovHalf) * coneLen);
    final p2 = Offset(pDot.dx - math.sin(yawRad + fovHalf) * coneLen, pDot.dy + math.cos(yawRad + fovHalf) * coneLen);

    final conePath = Path()
      ..moveTo(pDot.dx, pDot.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();

    canvas.drawPath(conePath, Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.25));
  }

  @override
  bool shouldRepaint(covariant _MiniRadarPainter old) {
    return old.playerX != playerX ||
        old.playerY != playerY ||
        old.playerYaw != playerYaw ||
        old.spatials != spatials;
  }
}

/// High-Performance 3D CustomPainter for Bedroom Simulation
class _Bedroom3DSimulationPainter extends CustomPainter {
  final DynamicFloorDimensions dims;
  final List<MathematicalItemDimension> calculatedItems;
  final List<RoomItemPlacement> placements;
  final List<Item3DSpatial> spatials;
  final String? selectedItemId;
  final double rotationYaw;
  final double pitchAngle;
  final double zoomScale;
  final Offset panOffset;
  final LightingMode lightingMode;
  final double timeOfDayHour;
  final RgbMoodTheme rgbMood;
  final FlooringTheme flooringTheme;
  final WallFinishTheme wallFinishTheme;
  final double explodeFactor;
  final bool showDimensions;
  final bool showProductPins;
  final bool showErgonomicsHeatmap;
  final bool bedsideLampOn;
  final bool studyLampOn;
  final bool tvScreenOn;
  final bool underBedGlowOn;
  final bool wardrobeDoorOpen;
  final SimulationNavMode navMode;
  final double playerX;
  final double playerY;
  final double eyeHeight;
  final bool flashlightOn;

  _Bedroom3DSimulationPainter({
    required this.dims,
    required this.calculatedItems,
    required this.placements,
    required this.spatials,
    required this.selectedItemId,
    required this.rotationYaw,
    required this.pitchAngle,
    required this.zoomScale,
    required this.panOffset,
    required this.lightingMode,
    required this.timeOfDayHour,
    required this.rgbMood,
    required this.flooringTheme,
    required this.wallFinishTheme,
    required this.explodeFactor,
    required this.showDimensions,
    required this.showProductPins,
    required this.showErgonomicsHeatmap,
    required this.bedsideLampOn,
    required this.studyLampOn,
    required this.tvScreenOn,
    required this.underBedGlowOn,
    required this.wardrobeDoorOpen,
    required this.navMode,
    required this.playerX,
    required this.playerY,
    required this.eyeHeight,
    required this.flashlightOn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2 + panOffset.dx, size.height / 2 + panOffset.dy);

    final rW = dims.roomWidth;
    final rL = dims.roomLength;
    final rH = dims.ceilingHeight;

    final baseScale = (size.width < 800 ? 32.0 : 42.0) * zoomScale;
    final yawRad = (rotationYaw * math.pi / 180.0);
    final pitchRad = (pitchAngle * math.pi / 180.0);

    // 3D Point Projection Helper
    Offset project(double x, double y, double z, {double explodeDx = 0, double explodeDy = 0, double explodeDz = 0}) {
      final actualX = x + (explodeDx * explodeFactor);
      final actualY = y + (explodeDy * explodeFactor);
      final actualZ = z + (explodeDz * explodeFactor);

      final cx = actualX - (rW / 2.0);
      final cy = actualY - (rL / 2.0);
      final cz = actualZ;

      final rx = cx * math.cos(yawRad) - cy * math.sin(yawRad);
      final ry = cx * math.sin(yawRad) + cy * math.cos(yawRad);
      final rz = cz;

      final px = rx * baseScale;
      final py = (-ry * math.sin(pitchRad) - rz * math.cos(pitchRad)) * baseScale;

      return Offset(center.dx + px, center.dy + py);
    }

    // 1. Sky & Environment Lighting
    _drawEnvironmentSky(canvas, size, center);

    // 2. 3D Room Floor Slab & Custom Material Pattern
    _draw3DFloor(canvas, rW, rL, project);

    // 3. Ergonomics & Walking Corridor Flow Heatmap
    if (showErgonomicsHeatmap) {
      _drawErgonomicsFlowHeatmap(canvas, rW, rL, project);
    }

    // 4. Dynamic Soft Shadows cast by Furniture based on Sun Path
    _drawDynamicSunShadows(canvas, rW, rL, spatials, project);

    // 5. 3D Architectural Walls (Solid North & South Walls - No Windows)
    _draw3DWalls(canvas, rW, rL, rH, project);

    // 6. 3D Furniture Pieces (strictly placed items)
    _draw3DFurniture(canvas, rW, rL, rH, spatials, project);

    // 7. Ambient Electronics Glow & LED Under-Glow
    _drawAmbientLightingEffects(canvas, rW, rL, rH, spatials, project);

    // 8. 3D Architectural Dimensions
    if (showDimensions && explodeFactor < 0.1 && navMode != SimulationNavMode.firstPersonWalk) {
      _draw3DDimensionGuides(canvas, rW, rL, rH, project);
    }

    // 9. First-Person Sightline Crosshair & Flashlight
    if (navMode == SimulationNavMode.firstPersonWalk) {
      _drawFirstPersonSightlineHUD(canvas, size, center);
    }
  }

  void _drawEnvironmentSky(Canvas canvas, Size size, Offset center) {
    Color skyTop;
    Color skyBottom;

    if (timeOfDayHour >= 6.0 && timeOfDayHour <= 8.5) {
      skyTop = const Color(0xFF1E1B4B);
      skyBottom = const Color(0xFFF97316);
    } else if (timeOfDayHour > 8.5 && timeOfDayHour <= 16.5) {
      skyTop = const Color(0xFF0F172A);
      skyBottom = const Color(0xFF0284C7);
    } else if (timeOfDayHour > 16.5 && timeOfDayHour <= 19.5) {
      skyTop = const Color(0xFF31103F);
      skyBottom = const Color(0xFFEA580C);
    } else {
      skyTop = const Color(0xFF030712);
      skyBottom = const Color(0xFF0F172A);
    }

    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skyTop, skyBottom],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (int i = -10; i <= 10; i++) {
      final y = center.dy + i * 40.0;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _draw3DFloor(Canvas canvas, double rW, double rL, Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project) {
    final f00 = project(0, 0, 0);
    final f10 = project(rW, 0, 0);
    final f11 = project(rW, rL, 0);
    final f01 = project(0, rL, 0);

    final floorPath = Path()
      ..moveTo(f00.dx, f00.dy)
      ..lineTo(f10.dx, f10.dy)
      ..lineTo(f11.dx, f11.dy)
      ..lineTo(f01.dx, f01.dy)
      ..close();

    Color floorBaseColor;
    switch (flooringTheme) {
      case FlooringTheme.herringboneOak:
        floorBaseColor = const Color(0xFFD4A373);
        break;
      case FlooringTheme.carraraMarble:
        floorBaseColor = const Color(0xFFE2E8F0);
        break;
      case FlooringTheme.darkWalnut:
        floorBaseColor = const Color(0xFF3E2723);
        break;
      case FlooringTheme.tatamiMat:
        floorBaseColor = const Color(0xFFC5A059);
        break;
      case FlooringTheme.polishedTerrazzo:
        floorBaseColor = const Color(0xFFCBD5E1);
        break;
    }

    final floorPaint = Paint()
      ..color = floorBaseColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(floorPath, floorPaint);

    final plankPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (double x = 0.5; x < rW; x += 1.0) {
      final pA = project(x, 0, 0);
      final pB = project(x, rL, 0);
      canvas.drawLine(pA, pB, plankPaint);
    }

    const slabThickness = 0.4;
    final b00 = project(0, 0, -slabThickness);
    final b10 = project(rW, 0, -slabThickness);

    final edgePath = Path()
      ..moveTo(f00.dx, f00.dy)
      ..lineTo(f10.dx, f10.dy)
      ..lineTo(b10.dx, b10.dy)
      ..lineTo(b00.dx, b00.dy)
      ..close();

    final slabPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawPath(edgePath, slabPaint);
  }

  void _drawErgonomicsFlowHeatmap(
    Canvas canvas,
    double rW,
    double rL,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    final corridorPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final c00 = project(rW * 0.35, 1.0, 0.01);
    final c10 = project(rW * 0.65, 1.0, 0.01);
    final c11 = project(rW * 0.65, rL - 1.0, 0.01);
    final c01 = project(rW * 0.35, rL - 1.0, 0.01);

    final flowPath = Path()
      ..moveTo(c00.dx, c00.dy)
      ..lineTo(c10.dx, c10.dy)
      ..lineTo(c11.dx, c11.dy)
      ..lineTo(c01.dx, c01.dy)
      ..close();

    canvas.drawPath(flowPath, corridorPaint);

    final borderPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(flowPath, borderPaint);
  }

  void _drawDynamicSunShadows(
    Canvas canvas,
    double rW,
    double rL,
    List<Item3DSpatial> spatials,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    if (timeOfDayHour < 5.5 || timeOfDayHour > 19.0 || spatials.isEmpty) return;

    final sunAngleRad = ((timeOfDayHour - 6.0) / 12.0) * math.pi;
    final shadowDx = -math.cos(sunAngleRad) * 0.8;
    final shadowDy = math.sin(sunAngleRad) * 0.6;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    for (final s in spatials) {
      final s00 = project(s.x + shadowDx, s.y + shadowDy, 0.01);
      final s10 = project(s.x + s.width + shadowDx, s.y + shadowDy, 0.01);
      final s11 = project(s.x + s.width, s.y + s.length, 0.01);
      final s01 = project(s.x, s.y + s.length, 0.01);

      final shadowPath = Path()
        ..moveTo(s00.dx, s00.dy)
        ..lineTo(s10.dx, s10.dy)
        ..lineTo(s11.dx, s11.dy)
        ..lineTo(s01.dx, s01.dy)
        ..close();

      canvas.drawPath(shadowPath, shadowPaint);
    }
  }

  void _draw3DWalls(
    Canvas canvas,
    double rW,
    double rL,
    double rH,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    Color wallBaseColor;
    switch (wallFinishTheme) {
      case WallFinishTheme.flutedWoodSlats:
        wallBaseColor = const Color(0xFF334155);
        break;
      case WallFinishTheme.venetianPlaster:
        wallBaseColor = const Color(0xFFF1F5F9);
        break;
      case WallFinishTheme.charcoalAcoustic:
        wallBaseColor = const Color(0xFF0F172A);
        break;
      case WallFinishTheme.sandGreige:
        wallBaseColor = const Color(0xFFE2E8F0);
        break;
    }

    if (lightingMode == LightingMode.goldenHour) {
      wallBaseColor = const Color(0xFF3D2526);
    } else if (lightingMode == LightingMode.cozyNight) {
      wallBaseColor = const Color(0xFF0D1322);
    }

    final northOffset = explodeFactor * 4.0;
    final southOffset = explodeFactor * 4.0;
    final westOffset = explodeFactor * 4.0;
    final eastOffset = explodeFactor * 4.0;

    // 1. North Wall (Back Headboard Wall)
    final nwBottom0 = project(0, rL, 0, explodeDy: northOffset);
    final nwBottomW = project(rW, rL, 0, explodeDy: northOffset);
    final nwTopW = project(rW, rL, rH, explodeDy: northOffset);
    final nwTop0 = project(0, rL, rH, explodeDy: northOffset);

    final northWallPath = Path()
      ..moveTo(nwBottom0.dx, nwBottom0.dy)
      ..lineTo(nwBottomW.dx, nwBottomW.dy)
      ..lineTo(nwTopW.dx, nwTopW.dy)
      ..lineTo(nwTop0.dx, nwTop0.dy)
      ..close();

    canvas.drawPath(northWallPath, Paint()..color = wallBaseColor.withValues(alpha: 0.92));

    if (wallFinishTheme == WallFinishTheme.flutedWoodSlats) {
      final slatPaint = Paint()
        ..color = const Color(0xFFD4A373).withValues(alpha: 0.18)
        ..strokeWidth = 1.2;
      for (double x = 0.4; x < rW; x += 0.5) {
        final b = project(x, rL, 0, explodeDy: northOffset);
        final t = project(x, rL, rH, explodeDy: northOffset);
        canvas.drawLine(b, t, slatPaint);
      }
    }

    // 2. West Wall (Left Solid Wall)
    final wwBottom0 = project(0, 0, 0, explodeDx: -westOffset);
    final wwBottomL = project(0, rL, 0, explodeDx: -westOffset);
    final wwTopL = project(0, rL, rH, explodeDx: -westOffset);
    final wwTop0 = project(0, 0, rH, explodeDx: -westOffset);

    final westWallPath = Path()
      ..moveTo(wwBottom0.dx, wwBottom0.dy)
      ..lineTo(wwBottomL.dx, wwBottomL.dy)
      ..lineTo(wwTopL.dx, wwTopL.dy)
      ..lineTo(wwTop0.dx, wwTop0.dy)
      ..close();

    canvas.drawPath(westWallPath, Paint()..color = wallBaseColor.withValues(alpha: 0.96));

    // 3. East Wall (Right Wall with Main Entry Door)
    final ewBottom0 = project(rW, 0, 0, explodeDx: eastOffset);
    final ewBottomL = project(rW, rL, 0, explodeDx: eastOffset);
    final ewTopL = project(rW, rL, rH, explodeDx: eastOffset);
    final ewTop0 = project(rW, 0, rH, explodeDx: eastOffset);

    final eastWallPath = Path()
      ..moveTo(ewBottom0.dx, ewBottom0.dy)
      ..lineTo(ewBottomL.dx, ewBottomL.dy)
      ..lineTo(ewTopL.dx, ewTopL.dy)
      ..lineTo(ewTop0.dx, ewTop0.dy)
      ..close();

    canvas.drawPath(eastWallPath, Paint()..color = wallBaseColor.withValues(alpha: 0.85));

    const doorW = 3.0;
    const doorH = 7.0;
    const doorY1 = 0.5;
    const doorY2 = doorY1 + doorW;

    final dP1 = project(rW, doorY1, 0, explodeDx: eastOffset);
    final dP2 = project(rW, doorY2, 0, explodeDx: eastOffset);
    final dP3 = project(rW, doorY2, doorH, explodeDx: eastOffset);
    final dP4 = project(rW, doorY1, doorH, explodeDx: eastOffset);

    final doorPath = Path()
      ..moveTo(dP1.dx, dP1.dy)
      ..lineTo(dP2.dx, dP2.dy)
      ..lineTo(dP3.dx, dP3.dy)
      ..lineTo(dP4.dx, dP4.dy)
      ..close();

    canvas.drawPath(doorPath, Paint()..color = const Color(0xFFEAB308).withValues(alpha: 0.45));
    canvas.drawPath(
      doorPath,
      Paint()
        ..color = const Color(0xFFEAB308)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke,
    );

    // 4. South Wall (Entry Boundary Wall - Solid, No Window)
    final swBottom0 = project(0, 0, 0, explodeDy: -southOffset);
    final swBottomW = project(rW, 0, 0, explodeDy: -southOffset);
    final swTopW = project(rW, 0, rH, explodeDy: -southOffset);
    final swTop0 = project(0, 0, rH, explodeDy: -southOffset);

    final southWallPath = Path()
      ..moveTo(swBottom0.dx, swBottom0.dy)
      ..lineTo(swBottomW.dx, swBottomW.dy)
      ..lineTo(swTopW.dx, swTopW.dy)
      ..lineTo(swTop0.dx, swTop0.dy)
      ..close();

    canvas.drawPath(southWallPath, Paint()..color = wallBaseColor.withValues(alpha: 0.88));

    if (explodeFactor > 0.05) {
      final bimGuidePaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      canvas.drawLine(project(0, rL, 0), nwBottom0, bimGuidePaint);
      canvas.drawLine(project(rW, rL, 0), nwBottomW, bimGuidePaint);
      canvas.drawLine(project(0, 0, 0), wwBottom0, bimGuidePaint);
      canvas.drawLine(project(rW, 0, 0), ewBottom0, bimGuidePaint);
    }
  }

  void _draw3DFurniture(
    Canvas canvas,
    double rW,
    double rL,
    double rH,
    List<Item3DSpatial> spatials,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    if (spatials.isEmpty) return;

    for (final s in spatials) {
      final name = s.itemName.toLowerCase();
      final hasAmazon = s.amazonUrl != null && s.amazonUrl!.trim().isNotEmpty;

      if (name.contains('bed')) {
        // Draw 3D Bed with mattress, headboard slab, pillows
        _draw3DBox(
          canvas: canvas,
          x: s.x,
          y: s.y,
          z: s.z,
          w: s.width,
          l: s.length,
          h: s.height,
          color: s.baseColor,
          topColor: const Color(0xFFF1F5F9), // Linen white mattress
          name: s.itemName,
          project: project,
          hasAmazon: hasAmazon,
          price: s.productPrice,
          isSelected: s.isSelected,
        );

        // Headboard on target wall side
        _drawBedHeadboard(canvas, s, project);

        // Pillows
        _drawBedPillows(canvas, s.x, s.y, s.z + s.height, s.width, s.length, s.facingDirection, project);

      } else if (name.contains('wardrobe') || name.contains('closet') || name.contains('cupboard') || name.contains('almirah')) {
        final doorOffset = wardrobeDoorOpen ? 1.5 : 0.0;
        _draw3DBox(
          canvas: canvas,
          x: s.x,
          y: s.y,
          z: s.z,
          w: s.width,
          l: s.length,
          h: s.height,
          color: s.baseColor,
          topColor: s.topColor,
          name: s.itemName,
          project: project,
          hasAmazon: hasAmazon,
          price: s.productPrice,
          doorSlideOffset: doorOffset,
          isSelected: s.isSelected,
        );

      } else if (name.contains('study') || name.contains('desk') || name.contains('table') || name.contains('work')) {
        _draw3DBox(
          canvas: canvas,
          x: s.x,
          y: s.y,
          z: s.z,
          w: s.width,
          l: s.length,
          h: s.height,
          color: s.baseColor,
          topColor: s.topColor,
          name: s.itemName,
          project: project,
          hasAmazon: hasAmazon,
          price: s.productPrice,
          isSelected: s.isSelected,
        );

        if (studyLampOn) {
          _drawStudyMonitor(canvas, s.x + (s.width > 2.0 ? 0.3 : 0.1), s.y + (s.length > 2.0 ? 0.3 : 0.1), s.z + s.height, project);
        }

      } else if (name.contains('tv') || name.contains('media') || name.contains('console') || name.contains('entertainment')) {
        // Low console
        final consoleH = math.min(s.height, 1.8);
        _draw3DBox(
          canvas: canvas,
          x: s.x,
          y: s.y,
          z: s.z,
          w: s.width,
          l: s.length,
          h: consoleH,
          color: s.baseColor,
          topColor: s.topColor,
          name: s.itemName,
          project: project,
          hasAmazon: hasAmazon,
          price: s.productPrice,
          isSelected: s.isSelected,
        );

        if (tvScreenOn) {
          _drawOledTvScreen(
            canvas,
            s.x + (s.width > 1.2 ? (s.width - 0.2) : s.width * 0.1),
            s.y + s.length * 0.1,
            s.z + consoleH + 0.3,
            s.length * 0.8,
            2.2,
            project,
          );
        }

      } else {
        // Any custom item
        _draw3DBox(
          canvas: canvas,
          x: s.x,
          y: s.y,
          z: s.z,
          w: s.width,
          l: s.length,
          h: s.height,
          color: s.baseColor,
          topColor: s.topColor,
          name: s.itemName,
          project: project,
          hasAmazon: hasAmazon,
          price: s.productPrice,
          isSelected: s.isSelected,
        );
      }
    }
  }

  void _drawBedHeadboard(Canvas canvas, Item3DSpatial s, Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project) {
    final headboardH = s.height + 2.2;
    final facing = s.facingDirection;

    double hx = s.x;
    double hy = s.y;
    double hw = s.width;
    double hl = s.length;

    if (facing.contains('South') || facing.contains('↓') || s.targetWall.contains('North')) {
      // Headboard against North (y + length)
      hy = s.y + s.length - 0.4;
      hl = 0.4;
    } else if (facing.contains('North') || facing.contains('↑') || s.targetWall.contains('South')) {
      // Headboard against South (y)
      hl = 0.4;
    } else if (facing.contains('East') || facing.contains('→') || s.targetWall.contains('West')) {
      // Headboard against West (x)
      hw = 0.4;
    } else {
      // Headboard against East (x + width)
      hx = s.x + s.width - 0.4;
      hw = 0.4;
    }

    _draw3DBox(
      canvas: canvas,
      x: hx,
      y: hy,
      z: s.z,
      w: hw,
      l: hl,
      h: headboardH,
      color: const Color(0xFF334155),
      topColor: const Color(0xFF475569),
      name: '',
      project: project,
      drawPin: false,
    );
  }

  void _draw3DBox({
    required Canvas canvas,
    required double x,
    required double y,
    required double z,
    required double w,
    required double l,
    required double h,
    required Color color,
    required Color topColor,
    required String name,
    required Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
    bool hasAmazon = false,
    String? price,
    double doorSlideOffset = 0.0,
    bool isSelected = false,
    bool drawPin = true,
  }) {
    final p000 = project(x, y, z);
    final p100 = project(x + w, y, z);
    final p110 = project(x + w, y + l, z);

    final p001 = project(x, y, z + h);
    final p101 = project(x + w, y, z + h);
    final p111 = project(x + w, y + l, z + h);
    final p011 = project(x, y + l, z + h);

    final frontPath = Path()
      ..moveTo(p000.dx, p000.dy)
      ..lineTo(p100.dx, p100.dy)
      ..lineTo(p101.dx, p101.dy)
      ..lineTo(p001.dx, p001.dy)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = color);

    final rightPath = Path()
      ..moveTo(p100.dx, p100.dy)
      ..lineTo(p110.dx, p110.dy)
      ..lineTo(p111.dx, p111.dy)
      ..lineTo(p101.dx, p101.dy)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = color.withValues(alpha: 0.82));

    final topPath = Path()
      ..moveTo(p001.dx, p001.dy)
      ..lineTo(p101.dx, p101.dy)
      ..lineTo(p111.dx, p111.dy)
      ..lineTo(p011.dx, p011.dy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = topColor);

    final edgePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(topPath, edgePaint);
    canvas.drawPath(frontPath, edgePaint);
    canvas.drawPath(rightPath, edgePaint);

    if (isSelected) {
      final selectHaloPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(topPath, selectHaloPaint);
      canvas.drawPath(frontPath, selectHaloPaint);
      canvas.drawPath(rightPath, selectHaloPaint);
    }

    if (drawPin && showProductPins && navMode != SimulationNavMode.firstPersonWalk && name.isNotEmpty) {
      final centerPin = project(x + w / 2, y + l / 2, z + h + 0.6);
      _drawProductHologramPin(canvas, centerPin, name, hasAmazon, price, '$w\' × $l\'');
    }
  }

  void _drawBedPillows(Canvas canvas, double x, double y, double z, double w, double l, String facing, Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project) {
    final pilW = (w > l ? l : w) * 0.38;
    final pilL = (w > l ? w : l) * 0.22;

    double p1x = x + 0.3;
    double p1y = y + l - pilL - 0.3;
    double p2x = x + w - pilW - 0.3;
    double p2y = p1y;

    if (facing.contains('North') || facing.contains('↑')) {
      p1y = y + 0.3;
      p2y = y + 0.3;
    }

    final p1_00 = project(p1x, p1y, z);
    final p1_10 = project(p1x + pilW, p1y, z);
    final p1_11 = project(p1x + pilW, p1y + pilL, z);
    final p1_01 = project(p1x, p1y + pilL, z);

    final pil1Path = Path()
      ..moveTo(p1_00.dx, p1_00.dy)
      ..lineTo(p1_10.dx, p1_10.dy)
      ..lineTo(p1_11.dx, p1_11.dy)
      ..lineTo(p1_01.dx, p1_01.dy)
      ..close();
    canvas.drawPath(pil1Path, Paint()..color = const Color(0xFFE2E8F0));

    final p2_00 = project(p2x, p2y, z);
    final p2_10 = project(p2x + pilW, p2y, z);
    final p2_11 = project(p2x + pilW, p2y + pilL, z);
    final p2_01 = project(p2x, p2y + pilL, z);

    final pil2Path = Path()
      ..moveTo(p2_00.dx, p2_00.dy)
      ..lineTo(p2_10.dx, p2_10.dy)
      ..lineTo(p2_11.dx, p2_11.dy)
      ..lineTo(p2_01.dx, p2_01.dy)
      ..close();
    canvas.drawPath(pil2Path, Paint()..color = const Color(0xFFE2E8F0));
  }

  void _drawStudyMonitor(Canvas canvas, double x, double y, double z, Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project) {
    final m1 = project(x, y, z);
    final m2 = project(x + 1.6, y, z);
    final m3 = project(x + 1.6, y, z + 1.2);
    final m4 = project(x, y, z + 1.2);

    final monitorPath = Path()
      ..moveTo(m1.dx, m1.dy)
      ..lineTo(m2.dx, m2.dy)
      ..lineTo(m3.dx, m3.dy)
      ..lineTo(m4.dx, m4.dy)
      ..close();

    canvas.drawPath(monitorPath, Paint()..color = const Color(0xFF38BDF8));
  }

  void _drawOledTvScreen(Canvas canvas, double x, double y, double z, double length, double height, Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project) {
    final tv1 = project(x, y, z);
    final tv2 = project(x, y + length, z);
    final tv3 = project(x, y + length, z + height);
    final tv4 = project(x, y, z + height);

    final tvPath = Path()
      ..moveTo(tv1.dx, tv1.dy)
      ..lineTo(tv2.dx, tv2.dy)
      ..lineTo(tv3.dx, tv3.dy)
      ..lineTo(tv4.dx, tv4.dy)
      ..close();

    final glowPaint = Paint()
      ..color = const Color(0xFF6366F1).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(tvPath, glowPaint);

    final bezelPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(tvPath, bezelPaint);
  }

  void _drawProductHologramPin(Canvas canvas, Offset pinPos, String name, bool hasAmazon, String? price, String? dimStr) {
    final pinColor = hasAmazon ? const Color(0xFFFF9900) : const Color(0xFF38BDF8);

    canvas.drawCircle(pinPos, 12, Paint()..color = pinColor.withValues(alpha: 0.25));
    canvas.drawCircle(pinPos, 6, Paint()..color = pinColor);
    canvas.drawCircle(pinPos, 2.5, Paint()..color = Colors.black);

    final label = hasAmazon ? '🛒 $name${price != null ? ' ($price)' : ''}' : name;
    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        backgroundColor: Color(0xFF0F172A),
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(pinPos.dx - tp.width / 2, pinPos.dy - 24));
  }

  void _drawAmbientLightingEffects(
    Canvas canvas,
    double rW,
    double rL,
    double rH,
    List<Item3DSpatial> spatials,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    final bed = spatials.cast<Item3DSpatial?>().firstWhere(
      (s) => s != null && s.itemName.toLowerCase().contains('bed'),
      orElse: () => null,
    );

    if (bed != null) {
      if (underBedGlowOn) {
        final bedCenter = project(bed.x + bed.width / 2.0, bed.y + bed.length / 2.0, 0.1);
        Color glowColor = const Color(0xFF38BDF8);
        if (rgbMood == RgbMoodTheme.warmScandinavian) {
          glowColor = const Color(0xFFFBBF24);
        } else if (rgbMood == RgbMoodTheme.biophilicEmerald) {
          glowColor = const Color(0xFF10B981);
        }

        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [glowColor.withValues(alpha: 0.4), Colors.transparent],
          ).createShader(Rect.fromCircle(center: bedCenter, radius: 140));
        canvas.drawCircle(bedCenter, 140, glowPaint);
      }

      if (bedsideLampOn) {
        final lampCenter = project(bed.x - 0.2, bed.y + bed.length * 0.8, bed.z + bed.height + 0.6);
        final lampPaint = Paint()
          ..shader = RadialGradient(
            colors: [const Color(0xFFFDE047).withValues(alpha: 0.5), Colors.transparent],
          ).createShader(Rect.fromCircle(center: lampCenter, radius: 90));
        canvas.drawCircle(lampCenter, 90, lampPaint);
      }
    }
  }

  void _draw3DDimensionGuides(
    Canvas canvas,
    double rW,
    double rL,
    double rH,
    Offset Function(double, double, double, {double explodeDx, double explodeDy, double explodeDz}) project,
  ) {
    final dimPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final p0 = project(0, 0, 0);
    final pW = project(rW, 0, 0);
    final pL = project(0, rL, 0);

    canvas.drawLine(p0, pW, dimPaint);
    canvas.drawLine(p0, pL, dimPaint);
  }

  void _drawFirstPersonSightlineHUD(Canvas canvas, Size size, Offset center) {
    final cX = size.width / 2;
    final cY = size.height / 2;

    // Flashlight beam in dark mode
    if (flashlightOn || lightingMode == LightingMode.cozyNight) {
      final torchPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: flashlightOn ? 0.35 : 0.15),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cX, cY), radius: 240));
      canvas.drawCircle(Offset(cX, cY), 240, torchPaint);
    }

    final crosshairPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.8)
      ..strokeWidth = 1.5;

    canvas.drawLine(Offset(cX - 12, cY), Offset(cX - 4, cY), crosshairPaint);
    canvas.drawLine(Offset(cX + 4, cY), Offset(cX + 12, cY), crosshairPaint);
    canvas.drawLine(Offset(cX, cY - 12), Offset(cX, cY - 4), crosshairPaint);
    canvas.drawLine(Offset(cX, cY + 4), Offset(cX, cY + 12), crosshairPaint);

    canvas.drawCircle(Offset(cX, cY), 2.0, Paint()..color = const Color(0xFF10B981));
  }

  @override
  bool shouldRepaint(covariant _Bedroom3DSimulationPainter old) {
    return old.rotationYaw != rotationYaw ||
        old.pitchAngle != pitchAngle ||
        old.zoomScale != zoomScale ||
        old.panOffset != panOffset ||
        old.selectedItemId != selectedItemId ||
        old.lightingMode != lightingMode ||
        old.timeOfDayHour != timeOfDayHour ||
        old.rgbMood != rgbMood ||
        old.flooringTheme != flooringTheme ||
        old.wallFinishTheme != wallFinishTheme ||
        old.explodeFactor != explodeFactor ||
        old.showDimensions != showDimensions ||
        old.showProductPins != showProductPins ||
        old.showErgonomicsHeatmap != showErgonomicsHeatmap ||
        old.bedsideLampOn != bedsideLampOn ||
        old.studyLampOn != studyLampOn ||
        old.tvScreenOn != tvScreenOn ||
        old.underBedGlowOn != underBedGlowOn ||
        old.wardrobeDoorOpen != wardrobeDoorOpen ||
        old.navMode != navMode ||
        old.playerX != playerX ||
        old.playerY != playerY ||
        old.eyeHeight != eyeHeight ||
        old.flashlightOn != flashlightOn ||
        old.placements != placements ||
        old.spatials != spatials;
  }
}
