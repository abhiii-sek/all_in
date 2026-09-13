import 'package:flutter/material.dart';
import '../models/floor_model.dart';
import '../models/room_model.dart';
import '../models/wall_opening.dart';
import '../models/room_item.dart';
import 'spatial_optimizer_service.dart';

class ProjectState extends ChangeNotifier {
  final List<FloorModel> _floors = [];
  String? _selectedFloorId;
  String? _selectedRoomId;

  List<FloorModel> get floors => List.unmodifiable(_floors);
  String? get selectedFloorId => _selectedFloorId;
  String? get selectedRoomId => _selectedRoomId;

  FloorModel? get selectedFloor {
    if (_selectedFloorId == null) {
      return _floors.isNotEmpty ? _floors.first : null;
    }
    return _floors.firstWhere(
      (f) => f.id == _selectedFloorId,
      orElse: () => _floors.first,
    );
  }

  RoomModel? get selectedRoom {
    final floor = selectedFloor;
    if (floor == null || floor.rooms.isEmpty) return null;
    if (_selectedRoomId == null) return floor.rooms.first;
    return floor.rooms.firstWhere(
      (r) => r.id == _selectedRoomId,
      orElse: () => floor.rooms.first,
    );
  }

  ProjectState() {
    _initSampleData();
  }

  void _initSampleData() {
    final firstFloor = FloorModel(
      id: 'floor_1',
      name: 'First Floor',
      rooms: [],
    );

    // 1. Master Bedroom
    final masterBedRoom = RoomModel(
      id: 'room_bed_1',
      name: 'Master Bedroom',
      roomType: RoomType.bedroom,
      wallTop: 4.2, // 4.2m
      wallRight: 3.6, // 3.6m
      wallBottom: 4.2,
      wallLeft: 3.6,
      ceilingHeight: 2.9,
      openings: [
        const WallOpening(
          id: 'door_1',
          type: OpeningType.door,
          wallIndex: 2, // Bottom Wall
          offsetFromCorner: 0.3,
          width: 0.9,
          doorSwing: DoorSwing.inwardLeft,
        ),
        const WallOpening(
          id: 'win_1',
          type: OpeningType.window,
          wallIndex: 0, // Top Wall
          offsetFromCorner: 0.8,
          width: 1.8,
          height: 1.5,
          sillHeight: 0.9,
        ),
      ],
      requestedItems: [
        RoomItem.createDefault(ItemCategory.bed, customName: 'King Bed (1.8m x 2.0m)'),
        RoomItem.createDefault(ItemCategory.wardrobe, customName: 'Sliding 3-Door Wardrobe'),
        RoomItem.createDefault(ItemCategory.studyDesk, customName: 'Ergonomic Study / Work Desk'),
        RoomItem.createDefault(ItemCategory.tvUnit, customName: '55" Wall TV Console'),
        RoomItem.createDefault(ItemCategory.acUnit, customName: '1.5 Ton Split AC'),
      ],
    );
    masterBedRoom.generatedLayouts = SpatialOptimizerService.generateLayouts(masterBedRoom);

    // 2. Master Bathroom
    final masterBath = RoomModel(
      id: 'room_bath_1',
      name: 'Master Attached Bathroom',
      roomType: RoomType.bathroom,
      wallTop: 2.4,
      wallRight: 1.8,
      wallBottom: 2.4,
      wallLeft: 1.8,
      ceilingHeight: 2.7,
      openings: [
        const WallOpening(
          id: 'bath_door',
          type: OpeningType.door,
          wallIndex: 2,
          offsetFromCorner: 0.2,
          width: 0.75,
        ),
        const WallOpening(
          id: 'bath_vent',
          type: OpeningType.ventilator,
          wallIndex: 0,
          offsetFromCorner: 0.6,
          width: 0.6,
          height: 0.6,
          sillHeight: 2.0,
        ),
      ],
      requestedItems: [
        RoomItem.createDefault(ItemCategory.showerArea),
        RoomItem.createDefault(ItemCategory.commode),
        RoomItem.createDefault(ItemCategory.washBasin),
        RoomItem.createDefault(ItemCategory.geyser),
      ],
    );
    masterBath.generatedLayouts = SpatialOptimizerService.generateLayouts(masterBath);

    // 3. Modular Kitchen
    final kitchen = RoomModel(
      id: 'room_kitch_1',
      name: 'Modern Modular Kitchen',
      roomType: RoomType.kitchen,
      wallTop: 3.6,
      wallRight: 2.8,
      wallBottom: 3.6,
      wallLeft: 2.8,
      ceilingHeight: 2.9,
      openings: [
        const WallOpening(
          id: 'kitch_door',
          type: OpeningType.door,
          wallIndex: 2,
          offsetFromCorner: 0.2,
          width: 0.9,
        ),
        const WallOpening(
          id: 'kitch_win',
          type: OpeningType.window,
          wallIndex: 0,
          offsetFromCorner: 1.0,
          width: 1.4,
          height: 1.2,
          sillHeight: 1.0,
        ),
      ],
      requestedItems: [
        RoomItem.createDefault(ItemCategory.refrigerator),
        RoomItem.createDefault(ItemCategory.gasHob),
        RoomItem.createDefault(ItemCategory.chimney),
        RoomItem.createDefault(ItemCategory.kitchenSink),
        RoomItem.createDefault(ItemCategory.ovenTower),
      ],
    );
    kitchen.generatedLayouts = SpatialOptimizerService.generateLayouts(kitchen);

    firstFloor.rooms.addAll([masterBedRoom, masterBath, kitchen]);
    _floors.add(firstFloor);

    // Ground floor
    final groundFloor = FloorModel(
      id: 'floor_0',
      name: 'Ground Floor',
      rooms: [],
    );
    _floors.add(groundFloor);

    _selectedFloorId = firstFloor.id;
    _selectedRoomId = masterBedRoom.id;
  }

  void selectFloor(String floorId) {
    _selectedFloorId = floorId;
    final floor = selectedFloor;
    if (floor != null && floor.rooms.isNotEmpty) {
      _selectedRoomId = floor.rooms.first.id;
    } else {
      _selectedRoomId = null;
    }
    notifyListeners();
  }

  void selectRoom(String roomId) {
    _selectedRoomId = roomId;
    notifyListeners();
  }

  void addFloor(String name) {
    final newFloor = FloorModel(
      id: 'floor_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      rooms: [],
    );
    _floors.add(newFloor);
    _selectedFloorId = newFloor.id;
    _selectedRoomId = null;
    notifyListeners();
  }

  void addRoomToSelectedFloor(RoomModel room) {
    final floor = selectedFloor;
    if (floor == null) return;
    
    // Generate layout optimizations automatically
    room.generatedLayouts = SpatialOptimizerService.generateLayouts(room);
    room.selectedLayoutIndex = 0;

    floor.rooms.add(room);
    _selectedRoomId = room.id;
    notifyListeners();
  }

  void updateRoom(RoomModel updatedRoom) {
    final floor = selectedFloor;
    if (floor == null) return;
    final idx = floor.rooms.indexWhere((r) => r.id == updatedRoom.id);
    if (idx != -1) {
      updatedRoom.generatedLayouts = SpatialOptimizerService.generateLayouts(updatedRoom);
      floor.rooms[idx] = updatedRoom;
      notifyListeners();
    }
  }

  void deleteRoom(String roomId) {
    final floor = selectedFloor;
    if (floor == null) return;
    floor.rooms.removeWhere((r) => r.id == roomId);
    if (_selectedRoomId == roomId) {
      _selectedRoomId = floor.rooms.isNotEmpty ? floor.rooms.first.id : null;
    }
    notifyListeners();
  }

  void selectLayoutForRoom(String roomId, int layoutIndex) {
    final floor = selectedFloor;
    if (floor == null) return;
    final room = floor.rooms.firstWhere((r) => r.id == roomId);
    room.selectedLayoutIndex = layoutIndex;
    notifyListeners();
  }
}
