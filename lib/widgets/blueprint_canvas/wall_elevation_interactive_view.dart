import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../models/dynamic_floor_model.dart';
import '../../services/architectural_prompt_service.dart';
import 'wall_elevation_painter.dart';

class WallElevationInteractiveView extends StatefulWidget {
  final DynamicFloorDimensions dims;
  final List<MathematicalItemDimension> calculatedItems;
  final List<RoomItemPlacement> placements;
  final String activeWallKey;
  final Function(String newWallKey) onWallSelected;
  final Function(List<RoomItemPlacement> updatedPlacements) onPlacementsChanged;
  final VoidCallback onExport;

  const WallElevationInteractiveView({
    super.key,
    required this.dims,
    required this.calculatedItems,
    required this.placements,
    required this.activeWallKey,
    required this.onWallSelected,
    required this.onPlacementsChanged,
    required this.onExport,
  });

  @override
  State<WallElevationInteractiveView> createState() => _WallElevationInteractiveViewState();
}

class _WallElevationInteractiveViewState extends State<WallElevationInteractiveView> {
  final TransformationController _transController = TransformationController();
  final Map<int, Offset> _activePointers = <int, Offset>{};
  Offset? _lastCentroid;
  double? _lastSpan;
  double _lastTrackpadScale = 1.0;
  Offset? _canvasPanStartPos;
  Matrix4? _canvasPanStartMatrix;

  String? _selectedItemId;
  String? _draggingItemId;
  String? _resizingHandle; // 'top' for exclusive Height adjustment

  Offset? _dragStartPointerPos;
  double? _dragStartWallPosX;
  double? _dragStartElevation;
  double? _dragStartHeight;
  double? _dragStartWidth;

  final Size _canvasBaseSize = const Size(2200, 950);
  final double _canvasScale = 34.0;

  void _applyZoomAndPan({
    required double scaleFactor,
    required Offset panDelta,
    required Offset focalPoint,
    double minScale = 0.2,
    double maxScale = 5.0,
  }) {
    final Matrix4 matrix = _transController.value.clone();
    final double currentScale = matrix.getMaxScaleOnAxis();
    final double clampedScale = (currentScale * scaleFactor).clamp(minScale, maxScale);
    final double effectiveScale = clampedScale / currentScale;

    // 1. Pan Delta
    matrix.setEntry(0, 3, matrix.entry(0, 3) + panDelta.dx);
    matrix.setEntry(1, 3, matrix.entry(1, 3) + panDelta.dy);

    // 2. Zoom around focalPoint
    if ((effectiveScale - 1.0).abs() > 0.0001) {
      final double tx = matrix.entry(0, 3);
      final double ty = matrix.entry(1, 3);
      final double newTx = focalPoint.dx - (focalPoint.dx - tx) * effectiveScale;
      final double newTy = focalPoint.dy - (focalPoint.dy - ty) * effectiveScale;

      matrix.scale(effectiveScale, effectiveScale, 1.0);
      matrix.setEntry(0, 3, newTx);
      matrix.setEntry(1, 3, newTy);
    }

    _transController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final rectMap = WallElevationPainter.calculateWallItemRects(
      dims: widget.dims,
      wallKey: widget.activeWallKey,
      items: widget.calculatedItems,
      placements: widget.placements,
      canvasSize: _canvasBaseSize,
      scale: _canvasScale,
    );

    final selectedPlacementIndex = widget.placements.indexWhere((p) => p.id == _selectedItemId);
    final selectedPlacement = selectedPlacementIndex != -1 ? widget.placements[selectedPlacementIndex] : null;
    final selectedCalc = selectedPlacement != null
        ? widget.calculatedItems.firstWhere((it) => it.id == selectedPlacement.id, orElse: () => widget.calculatedItems.first)
        : null;

    final wallProps = (selectedPlacement != null && selectedCalc != null)
        ? WallElevationPainter.getWallItemProperties(widget.dims, selectedPlacement.targetWall, selectedPlacement, selectedCalc)
        : null;

    return Column(
      children: [
        // 1. Top Wall Selector Ribbon & Quick Action Bar
        _buildTopWallSelectorRibbon(),
        const SizedBox(height: 10),

        // 2. Interactive Elevation Canvas
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFF0B1120),
              child: Stack(
                children: [
                  InteractiveViewer(
                    transformationController: _transController,
                    panEnabled: false,
                    scaleEnabled: false,
                    minScale: 0.2,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(800),
                    child: Container(
                      width: _canvasBaseSize.width,
                      height: _canvasBaseSize.height,
                      color: const Color(0xFF0B1120),
                      child: Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerSignal: (signal) {
                          if (signal is PointerScrollEvent) {
                            final zoomFactor = signal.scrollDelta.dy < 0 ? 1.10 : 0.90;
                            _applyZoomAndPan(
                              scaleFactor: zoomFactor,
                              panDelta: Offset.zero,
                              focalPoint: signal.position,
                            );
                          }
                        },
                        onPointerPanZoomStart: (event) {
                          _lastTrackpadScale = 1.0;
                        },
                        onPointerPanZoomUpdate: (event) {
                          final scaleDelta = event.scale / _lastTrackpadScale;
                          _lastTrackpadScale = event.scale;
                          _applyZoomAndPan(
                            scaleFactor: scaleDelta,
                            panDelta: event.panDelta,
                            focalPoint: event.position,
                          );
                        },
                        onPointerDown: (event) {
                          _activePointers[event.pointer] = event.position;
                          if (_activePointers.length == 1) {
                            final localPos = event.localPosition;
                            _handlePointerDown(localPos, event.position, rectMap, event.kind);
                            _lastCentroid = event.position;
                            _lastSpan = null;
                          } else if (_activePointers.length >= 2) {
                            final pts = _activePointers.values.toList();
                            _lastCentroid = (pts[0] + pts[1]) / 2.0;
                            _lastSpan = (pts[0] - pts[1]).distance;
                            _draggingItemId = null;
                            _resizingHandle = null;
                          }
                        },
                        onPointerMove: (event) {
                          _activePointers[event.pointer] = event.position;
                          if (_activePointers.length >= 2) {
                            final pts = _activePointers.values.toList();
                            final newCentroid = (pts[0] + pts[1]) / 2.0;
                            final newSpan = (pts[0] - pts[1]).distance;

                            if (_lastCentroid != null && _lastSpan != null && _lastSpan! > 0) {
                              final panDelta = newCentroid - _lastCentroid!;
                              final scaleFactor = (newSpan / _lastSpan!).clamp(0.8, 1.25);
                              _applyZoomAndPan(
                                scaleFactor: scaleFactor,
                                panDelta: panDelta,
                                focalPoint: newCentroid,
                              );
                            }
                            _lastCentroid = newCentroid;
                            _lastSpan = newSpan;
                          } else if (_activePointers.length == 1) {
                            _handlePointerMove(event.localPosition, event.position);
                          }
                        },
                        onPointerUp: (event) {
                          _activePointers.remove(event.pointer);
                          if (_activePointers.length < 2) {
                            _lastCentroid = null;
                            _lastSpan = null;
                          }
                          if (_activePointers.isEmpty) {
                            _handlePanEnd();
                          }
                        },
                        onPointerCancel: (event) {
                          _activePointers.remove(event.pointer);
                          if (_activePointers.isEmpty) {
                            _handlePanEnd();
                          }
                        },
                        child: CustomPaint(
                          size: _canvasBaseSize,
                          painter: WallElevationPainter(
                            dims: widget.dims,
                            wallKey: widget.activeWallKey,
                            items: widget.calculatedItems,
                            placements: widget.placements,
                            selectedItemId: _selectedItemId,
                            scale: _canvasScale,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Top Floating Toolbar when an item is selected
                  if (selectedPlacement != null && wallProps != null && selectedPlacementIndex != -1)
                    _buildSelectedWallItemToolbar(selectedPlacementIndex, selectedPlacement, wallProps),

                  // Elevation Instructions Legend at bottom left
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Color(0xFF38BDF8)),
                          SizedBox(width: 8),
                          Text(
                            '💡 Drag Item to slide along wall  •  Drag Top Handle (↕) or use Stepper to Increase/Decrease Height',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Canvas Zoom Controls (Bottom Right)
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.zoom_out, color: Colors.white70, size: 18),
                            tooltip: 'Zoom Out',
                            onPressed: () {
                              _applyZoomAndPan(
                                scaleFactor: 0.85,
                                panDelta: Offset.zero,
                                focalPoint: Offset(_canvasBaseSize.width / 2, _canvasBaseSize.height / 2),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt, color: Color(0xFF38BDF8), size: 18),
                            tooltip: 'Reset View',
                            onPressed: () {
                              _transController.value = Matrix4.identity();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 18),
                            tooltip: 'Zoom In',
                            onPressed: () {
                              _applyZoomAndPan(
                                scaleFactor: 1.15,
                                panDelta: Offset.zero,
                                focalPoint: Offset(_canvasBaseSize.width / 2, _canvasBaseSize.height / 2),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopWallSelectorRibbon() {
    const walls = [
      'All Walls (4-Wall Panoramic)',
      'West Wall (W)',
      'South Wall (S)',
      'East Wall (E)',
      'North Wall (N)',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.architecture, size: 18, color: Color(0xFF38BDF8)),
            const SizedBox(width: 8),
            const Text(
              'VIEW ELEVATION:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(width: 12),

            // Wall Selector Tabs (All Walls + Individual Walls)
            for (final w in walls)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  avatar: w.contains('All') ? const Icon(Icons.panorama_horizontal, size: 16, color: Colors.black) : null,
                  label: Text(w, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  selected: widget.activeWallKey == w,
                  selectedColor: w.contains('All') ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
                  backgroundColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(color: widget.activeWallKey == w ? Colors.black : Colors.white70),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedItemId = null;
                      });
                      widget.onWallSelected(w);
                    }
                  },
                ),
              ),

            const SizedBox(width: 14),

            // Quick Add Split AC button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _addSplitAcToCurrentWall(),
              icon: const Icon(Icons.ac_unit, size: 15),
              label: const Text('+ Add Split AC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
            const SizedBox(width: 8),

            // Quick Add Wardrobe button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _addWardrobeToCurrentWall(),
              icon: const Icon(Icons.checkroom, size: 15),
              label: const Text('+ Add Wardrobe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _addSplitAcToCurrentWall() {
    final newId = 'ac_${DateTime.now().millisecondsSinceEpoch}';
    final targetWall = widget.activeWallKey.contains('All') ? 'West Wall (W)' : widget.activeWallKey;
    final isEastWest = targetWall.toLowerCase().contains('east') || targetWall.toLowerCase().contains('west');
    final totalSpan = isEastWest ? widget.dims.roomLength : widget.dims.roomWidth;

    final newPlacement = RoomItemPlacement(
      id: newId,
      itemName: 'Split AC Unit (1.5 Ton)',
      targetWall: targetWall,
      facingDirection: 'Auto (Inward)',
      customWidth: isEastWest ? 1.0 : 3.2,
      customLength: isEastWest ? 3.2 : 1.0,
      customHeight: 1.15,
      customElevation: 8.0,
      customPosX: isEastWest ? 0.0 : (totalSpan - 3.2) / 2.0,
      customPosY: isEastWest ? (totalSpan - 3.2) / 2.0 : 0.0,
    );

    final updated = List<RoomItemPlacement>.from(widget.placements)..add(newPlacement);
    setState(() {
      _selectedItemId = newId;
    });
    widget.onPlacementsChanged(updated);
  }

  void _addWardrobeToCurrentWall() {
    final newId = 'wardrobe_${DateTime.now().millisecondsSinceEpoch}';
    final targetWall = widget.activeWallKey.contains('All') ? 'East Wall (E)' : widget.activeWallKey;
    final isEastWest = targetWall.toLowerCase().contains('east') || targetWall.toLowerCase().contains('west');
    final totalSpan = isEastWest ? widget.dims.roomLength : widget.dims.roomWidth;

    final newPlacement = RoomItemPlacement(
      id: newId,
      itemName: 'Floor-to-Ceiling Wardrobe Run',
      targetWall: targetWall,
      facingDirection: 'Auto (Inward)',
      customWidth: isEastWest ? 2.12 : math.min(6.5, totalSpan),
      customLength: isEastWest ? math.min(6.5, totalSpan) : 2.12,
      customHeight: (widget.dims.ceilingHeight * 0.92).clamp(7.5, widget.dims.ceilingHeight),
      customElevation: 0.0,
      customPosX: 0.0,
      customPosY: 0.0,
    );

    final updated = List<RoomItemPlacement>.from(widget.placements)..add(newPlacement);
    setState(() {
      _selectedItemId = newId;
    });
    widget.onPlacementsChanged(updated);
  }

  void _handlePointerDown(Offset localPos, Offset globalPos, Map<String, Rect> rectMap, [PointerDeviceKind? kind]) {
    // 1. Check if clicking TOP HEIGHT HANDLE on already selected item
    if (_selectedItemId != null && rectMap.containsKey(_selectedItemId)) {
      final selectedRect = rectMap[_selectedItemId]!;
      final pIndex = widget.placements.indexWhere((p) => p.id == _selectedItemId);
      if (pIndex != -1) {
        final p = widget.placements[pIndex];
        final calcItem = widget.calculatedItems.firstWhere((it) => it.id == _selectedItemId, orElse: () => widget.calculatedItems.first);
        final wallProps = WallElevationPainter.getWallItemProperties(widget.dims, p.targetWall, p, calcItem);

        // Top Handle (Height Stretch ↕ exclusively)
        if ((localPos - selectedRect.topCenter).distance <= 22.0) {
          setState(() {
            _draggingItemId = _selectedItemId;
            _resizingHandle = 'top';
            _canvasPanStartPos = null;
            _canvasPanStartMatrix = null;
            _dragStartPointerPos = localPos;
            _dragStartHeight = wallProps.height;
            _dragStartElevation = wallProps.elevation;
            _dragStartWallPosX = wallProps.wallPosX;
            _dragStartWidth = wallProps.wallWidth;
          });
          return;
        }
      }
    }

    // 2. Check if clicking any item body to select and start horizontal move drag
    for (final p in widget.placements.reversed) {
      final rect = rectMap[p.id];
      if (rect != null && rect.contains(localPos)) {
        final calcItem = widget.calculatedItems.firstWhere((it) => it.id == p.id, orElse: () => widget.calculatedItems.first);
        final wallProps = WallElevationPainter.getWallItemProperties(widget.dims, p.targetWall, p, calcItem);

        setState(() {
          _selectedItemId = p.id;
          _draggingItemId = p.id;
          _resizingHandle = null;
          _canvasPanStartPos = null;
          _canvasPanStartMatrix = null;
          _dragStartPointerPos = localPos;
          _dragStartWallPosX = wallProps.wallPosX;
          _dragStartElevation = wallProps.elevation;
          _dragStartHeight = wallProps.height;
          _dragStartWidth = wallProps.wallWidth;
        });
        return;
      }
    }

    // Clicked empty space -> deselect
    setState(() {
      _selectedItemId = null;
      _draggingItemId = null;
      _resizingHandle = null;
      if (kind == PointerDeviceKind.mouse) {
        _canvasPanStartPos = globalPos;
        _canvasPanStartMatrix = _transController.value.clone();
      } else {
        _canvasPanStartPos = null;
        _canvasPanStartMatrix = null;
      }
    });
  }

  void _handlePointerMove(Offset localPos, Offset globalPos) {
    if (_draggingItemId != null && _dragStartPointerPos != null) {
      final pIndex = widget.placements.indexWhere((p) => p.id == _draggingItemId);
      if (pIndex == -1) return;
      final p = widget.placements[pIndex];

      final deltaX = (localPos.dx - _dragStartPointerPos!.dx) / _canvasScale;
      final deltaY = (localPos.dy - _dragStartPointerPos!.dy) / _canvasScale; // Screen Y goes down

      final targetWallLower = p.targetWall.toLowerCase();
      final isEastWest = targetWallLower.contains('east') || targetWallLower.contains('west');
      final totalSpan = isEastWest ? widget.dims.roomLength : widget.dims.roomWidth;
      final ceilingH = widget.dims.ceilingHeight;

      if (_resizingHandle == 'top') {
        // Dragging Top Handle: ONLY change Item Height!
        // Dragging upwards (deltaY < 0) increases height, dragging downwards decreases height
        final baseH = _dragStartHeight ?? 7.0;
        final elev = _dragStartElevation ?? 0.0;
        final maxAvailableH = ceilingH - elev;
        final newH = (baseH - deltaY).clamp(0.5, maxAvailableH);

        setState(() {
          p.customHeight = double.parse(newH.toStringAsFixed(2));
        });
        widget.onPlacementsChanged(widget.placements);
      } else {
        // Moving Item Body: slides horizontally along the wall line & adjusts elevation
        final basePosX = _dragStartWallPosX ?? 0.0;
        final baseElev = _dragStartElevation ?? 0.0;
        final itemW = _dragStartWidth ?? 3.0;
        final itemH = p.customHeight ?? (_dragStartHeight ?? 3.0);

        double newPosX = (basePosX + deltaX).clamp(0.0, math.max(0.0, totalSpan - itemW));
        double newElev = (baseElev - deltaY).clamp(0.0, math.max(0.0, ceilingH - itemH));

        // Snap flush to Left corner if close (< 0.35 ft)
        if (newPosX < 0.35) {
          newPosX = 0.0;
        } else if ((totalSpan - (newPosX + itemW)).abs() < 0.35) {
          newPosX = totalSpan - itemW;
        }

        // Snap flush to Finished Floor Level (0.00' AFF) if close (< 0.35 ft)
        if (newElev < 0.35) {
          newElev = 0.0;
        } else if ((ceilingH - (newElev + itemH)).abs() < 0.35) {
          newElev = ceilingH - itemH;
        }

        setState(() {
          p.customElevation = double.parse(newElev.toStringAsFixed(2));
          if (isEastWest) {
            p.customPosY = double.parse(newPosX.toStringAsFixed(2));
          } else {
            p.customPosX = double.parse(newPosX.toStringAsFixed(2));
          }
        });
        widget.onPlacementsChanged(widget.placements);
      }
    } else if (_canvasPanStartPos != null && _canvasPanStartMatrix != null) {
      final delta = globalPos - _canvasPanStartPos!;
      final curScale = _transController.value.getMaxScaleOnAxis();
      final m = _canvasPanStartMatrix!.clone();
      m.translate(delta.dx / curScale, delta.dy / curScale);
      _transController.value = m;
    }
  }

  void _handlePanEnd() {
    setState(() {
      _draggingItemId = null;
      _resizingHandle = null;
      _dragStartPointerPos = null;
      _canvasPanStartPos = null;
      _canvasPanStartMatrix = null;
    });
  }

  Widget _buildSelectedWallItemToolbar(
    int pIndex,
    RoomItemPlacement placement,
    WallElevationItem wallProps,
  ) {
    final curHeight = wallProps.height;
    final curElev = wallProps.elevation;
    final ceilingH = widget.dims.ceilingHeight;

    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF38BDF8), width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Item Name Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app, size: 14, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 5),
                    Text(
                      '${placement.itemName} • ${placement.targetWall}',
                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ↕ Increase / Decrease Height Stepper
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Text('↕ Height: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () {
                        setState(() {
                          final step = DynamicFloorDimensions.getStepperStep(widget.dims.unit, isLength: true);
                          final minH = DynamicFloorDimensions.convertValue(0.5, DimensionUnit.feet, widget.dims.unit);
                          placement.customHeight = double.parse((curHeight - step).clamp(minH, ceilingH - curElev).toStringAsFixed(2));
                        });
                        widget.onPlacementsChanged(widget.placements);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFF10B981)),
                      ),
                    ),
                    Text(
                      widget.dims.format(curHeight),
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          final step = DynamicFloorDimensions.getStepperStep(widget.dims.unit, isLength: true);
                          placement.customHeight = double.parse((curHeight + step).clamp(0.5, ceilingH - curElev).toStringAsFixed(2));
                        });
                        widget.onPlacementsChanged(widget.placements);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // ⬆ Elevation (AFF) Stepper
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Text('⬆ Elevation: ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                    InkWell(
                      onTap: () {
                        setState(() {
                          final step = DynamicFloorDimensions.getStepperStep(widget.dims.unit, isLength: true);
                          placement.customElevation = double.parse((curElev - step).clamp(0.0, ceilingH - curHeight).toStringAsFixed(2));
                        });
                        widget.onPlacementsChanged(widget.placements);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(Icons.remove_circle_outline, size: 16, color: Color(0xFFF59E0B)),
                      ),
                    ),
                    Text(
                      widget.dims.format(curElev),
                      style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          final step = DynamicFloorDimensions.getStepperStep(widget.dims.unit, isLength: true);
                          placement.customElevation = double.parse((curElev + step).clamp(0.0, ceilingH - curHeight).toStringAsFixed(2));
                        });
                        widget.onPlacementsChanged(widget.placements);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Icon(Icons.add_circle_outline, size: 16, color: Color(0xFFF59E0B)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Quick Snap Flush Alignment Chips
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Text(' Snap: ', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                    Tooltip(
                      message: 'Snap Flush to Floor Level (0.00\' AFF)',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            placement.customElevation = 0.0;
                          });
                          widget.onPlacementsChanged(widget.placements);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Floor', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Snap Flush to Ceiling Top',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            placement.customElevation = double.parse((ceilingH - curHeight).clamp(0.0, ceilingH).toStringAsFixed(2));
                          });
                          widget.onPlacementsChanged(widget.placements);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Ceiling', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Close / Deselect Button
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.white60),
                tooltip: 'Deselect',
                onPressed: () => setState(() => _selectedItemId = null),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
