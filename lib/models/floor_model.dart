import 'room_model.dart';

class FloorModel {
  final String id;
  String name; // e.g. "Ground Floor", "First Floor", "Second Floor"
  List<RoomModel> rooms;

  FloorModel({
    required this.id,
    required this.name,
    List<RoomModel>? rooms,
  }) : rooms = rooms ?? [];

  double get totalFloorAreaSqFt {
    double total = 0;
    for (final room in rooms) {
      total += room.floorAreaSqFt;
    }
    return total;
  }

  FloorModel copyWith({
    String? id,
    String? name,
    List<RoomModel>? rooms,
  }) {
    return FloorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rooms: rooms ?? List.from(this.rooms),
    );
  }
}
