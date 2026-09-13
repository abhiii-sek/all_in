enum OpeningType {
  door,
  window,
  ventilator,
}

enum DoorSwing {
  inwardLeft,
  inwardRight,
  outwardLeft,
  outwardRight,
  sliding,
}

class WallOpening {
  final String id;
  final OpeningType type;
  final int wallIndex; // 0: Top/North, 1: Right/East, 2: Bottom/South, 3: Left/West
  final double offsetFromCorner; // meters from wall start
  final double width; // meters
  final double height; // meters
  final double sillHeight; // meters from floor (0 for doors)
  final DoorSwing doorSwing;

  const WallOpening({
    required this.id,
    required this.type,
    required this.wallIndex,
    required this.offsetFromCorner,
    required this.width,
    this.height = 2.1,
    this.sillHeight = 0.0,
    this.doorSwing = DoorSwing.inwardLeft,
  });

  WallOpening copyWith({
    String? id,
    OpeningType? type,
    int? wallIndex,
    double? offsetFromCorner,
    double? width,
    double? height,
    double? sillHeight,
    DoorSwing? doorSwing,
  }) {
    return WallOpening(
      id: id ?? this.id,
      type: type ?? this.type,
      wallIndex: wallIndex ?? this.wallIndex,
      offsetFromCorner: offsetFromCorner ?? this.offsetFromCorner,
      width: width ?? this.width,
      height: height ?? this.height,
      sillHeight: sillHeight ?? this.sillHeight,
      doorSwing: doorSwing ?? this.doorSwing,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'wallIndex': wallIndex,
        'offsetFromCorner': offsetFromCorner,
        'width': width,
        'height': height,
        'sillHeight': sillHeight,
        'doorSwing': doorSwing.name,
      };

  factory WallOpening.fromJson(Map<String, dynamic> json) => WallOpening(
        id: json['id'] as String,
        type: OpeningType.values.byName(json['type'] as String),
        wallIndex: json['wallIndex'] as int,
        offsetFromCorner: (json['offsetFromCorner'] as num).toDouble(),
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
        sillHeight: (json['sillHeight'] as num).toDouble(),
        doorSwing: DoorSwing.values.byName(json['doorSwing'] as String),
      );
}
