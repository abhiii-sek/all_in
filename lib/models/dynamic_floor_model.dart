enum DimensionUnit {
  feet,
  inches,
  meters,
  centimeters,
}

extension DimensionUnitExtension on DimensionUnit {
  String get symbol {
    switch (this) {
      case DimensionUnit.feet:
        return "'";
      case DimensionUnit.inches:
        return '"';
      case DimensionUnit.meters:
        return "m";
      case DimensionUnit.centimeters:
        return "cm";
    }
  }

  String get shortName {
    switch (this) {
      case DimensionUnit.feet:
        return "ft";
      case DimensionUnit.inches:
        return "in";
      case DimensionUnit.meters:
        return "m";
      case DimensionUnit.centimeters:
        return "cm";
    }
  }

  String get label {
    switch (this) {
      case DimensionUnit.feet:
        return "Feet (')";
      case DimensionUnit.inches:
        return 'Inches (")';
      case DimensionUnit.meters:
        return "Meters (m)";
      case DimensionUnit.centimeters:
        return "Centimeters (cm)";
    }
  }

  String get areaUnit {
    switch (this) {
      case DimensionUnit.feet:
        return "sq.ft";
      case DimensionUnit.inches:
        return "sq.in";
      case DimensionUnit.meters:
        return "m²";
      case DimensionUnit.centimeters:
        return "cm²";
    }
  }
}

class DynamicFloorDimensions {
  DimensionUnit unit;

  // Master Room (Bedroom + Living combined)
  double roomWidth; // e.g. 10.5 ft
  double roomLength; // e.g. 18.5 ft

  // Ensuite Bathroom
  double bathWidth; // e.g. 5.91 ft
  double bathLength; // e.g. 7.50 ft
  double showerDepth; // e.g. 3.01 ft
  double commodeWidth; // e.g. 2.85 ft
  double basinWidth; // e.g. 2.14 ft

  // Kitchen
  double kitchenWidth; // e.g. 7.60 ft
  double kitchenLength; // e.g. 9.80 ft
  double kitchenCounterDepth; // e.g. 2.17 ft
  double breakfastCounterRun; // e.g. 2.03 ft

  // Circulation & Core
  double staircaseWidth; // e.g. 4.50 ft
  double galleryWidth; // e.g. 2.80 ft
  double ceilingHeight; // e.g. 9.50 ft
  int roomDoorSwingQuadrant; // 0, 1, 2, 3: Cyclic rotation around East wall hinge

  DynamicFloorDimensions({
    this.unit = DimensionUnit.feet,
    this.roomWidth = 10.5,
    this.roomLength = 18.5,
    this.bathWidth = 5.91,
    this.bathLength = 7.5,
    this.showerDepth = 3.01,
    this.commodeWidth = 2.85,
    this.basinWidth = 2.14,
    this.kitchenWidth = 7.6,
    this.kitchenLength = 9.8,
    this.kitchenCounterDepth = 2.17,
    this.breakfastCounterRun = 2.03,
    this.staircaseWidth = 4.5,
    this.galleryWidth = 2.8,
    this.ceilingHeight = 9.5,
    this.roomDoorSwingQuadrant = 0,
  });

  // Total floor bounds: House ends strictly at the bottom of the Ensuite Bathroom
  double get totalWidth => roomWidth + kitchenWidth;
  double get totalLength => roomLength + (bathLength / 2.0);

  // Value converter across all 4 units
  static double convertValue(double val, DimensionUnit from, DimensionUnit to) {
    if (from == to) return val;
    // Step 1: Convert `from` to meters
    double inMeters;
    switch (from) {
      case DimensionUnit.feet:
        inMeters = val * 0.3048;
        break;
      case DimensionUnit.inches:
        inMeters = val * 0.0254;
        break;
      case DimensionUnit.meters:
        inMeters = val;
        break;
      case DimensionUnit.centimeters:
        inMeters = val * 0.01;
        break;
    }

    // Step 2: Convert meters to `to`
    switch (to) {
      case DimensionUnit.feet:
        return inMeters / 0.3048;
      case DimensionUnit.inches:
        return inMeters / 0.0254;
      case DimensionUnit.meters:
        return inMeters;
      case DimensionUnit.centimeters:
        return inMeters * 100.0;
    }
  }

  // Base canvas scale (pixels per current unit)
  static double getBaseScale(DimensionUnit u) {
    switch (u) {
      case DimensionUnit.feet:
        return 28.0;
      case DimensionUnit.inches:
        return 28.0 / 12.0;
      case DimensionUnit.meters:
        return 28.0 / 0.3048;
      case DimensionUnit.centimeters:
        return 28.0 / 30.48;
    }
  }

  // Stepper increment step size for HUD buttons
  static double getStepperStep(DimensionUnit u, {bool isLength = false}) {
    switch (u) {
      case DimensionUnit.feet:
        return isLength ? 0.5 : 0.25;
      case DimensionUnit.inches:
        return isLength ? 6.0 : 3.0;
      case DimensionUnit.meters:
        return isLength ? 0.15 : 0.1;
      case DimensionUnit.centimeters:
        return isLength ? 15.0 : 10.0;
    }
  }

  // Formatting helpers
  String format(double val) {
    switch (unit) {
      case DimensionUnit.feet:
        return "${val.toStringAsFixed(2)}'";
      case DimensionUnit.inches:
        return '${val.toStringAsFixed(1)}"';
      case DimensionUnit.meters:
        return "${val.toStringAsFixed(2)} m";
      case DimensionUnit.centimeters:
        return "${val.toStringAsFixed(1)} cm";
    }
  }

  String formatArea(double area) {
    switch (unit) {
      case DimensionUnit.feet:
        return "${area.toStringAsFixed(1)} sq.ft";
      case DimensionUnit.inches:
        return "${area.toStringAsFixed(0)} sq.in";
      case DimensionUnit.meters:
        return "${area.toStringAsFixed(2)} m²";
      case DimensionUnit.centimeters:
        return "${area.toStringAsFixed(0)} cm²";
    }
  }

  void switchUnit(DimensionUnit newUnit) {
    if (unit == newUnit) return;
    final oldUnit = unit;

    roomWidth = convertValue(roomWidth, oldUnit, newUnit);
    roomLength = convertValue(roomLength, oldUnit, newUnit);
    bathWidth = convertValue(bathWidth, oldUnit, newUnit);
    bathLength = convertValue(bathLength, oldUnit, newUnit);
    showerDepth = convertValue(showerDepth, oldUnit, newUnit);
    commodeWidth = convertValue(commodeWidth, oldUnit, newUnit);
    basinWidth = convertValue(basinWidth, oldUnit, newUnit);
    kitchenWidth = convertValue(kitchenWidth, oldUnit, newUnit);
    kitchenLength = convertValue(kitchenLength, oldUnit, newUnit);
    kitchenCounterDepth = convertValue(kitchenCounterDepth, oldUnit, newUnit);
    breakfastCounterRun = convertValue(breakfastCounterRun, oldUnit, newUnit);
    staircaseWidth = convertValue(staircaseWidth, oldUnit, newUnit);
    galleryWidth = convertValue(galleryWidth, oldUnit, newUnit);
    ceilingHeight = convertValue(ceilingHeight, oldUnit, newUnit);

    unit = newUnit;
  }

  DynamicFloorDimensions clone() {
    return DynamicFloorDimensions(
      unit: unit,
      roomWidth: roomWidth,
      roomLength: roomLength,
      bathWidth: bathWidth,
      bathLength: bathLength,
      showerDepth: showerDepth,
      commodeWidth: commodeWidth,
      basinWidth: basinWidth,
      kitchenWidth: kitchenWidth,
      kitchenLength: kitchenLength,
      kitchenCounterDepth: kitchenCounterDepth,
      breakfastCounterRun: breakfastCounterRun,
      staircaseWidth: staircaseWidth,
      galleryWidth: galleryWidth,
      ceilingHeight: ceilingHeight,
      roomDoorSwingQuadrant: roomDoorSwingQuadrant,
    );
  }
}
