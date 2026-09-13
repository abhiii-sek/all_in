import '../models/dynamic_floor_model.dart';

/// Result of parsing an Amazon or e-commerce product dimension description string
class ParsedAmazonDimensions {
  final double? width; // In target room unit
  final double? length; // In target room unit (or depth)
  final double? height; // In target room unit (or thickness)
  final double? rawWidth; // In parsed source unit
  final double? rawLength; // In parsed source unit
  final double? rawHeight; // In parsed source unit
  final DimensionUnit sourceUnit;
  final DimensionUnit targetUnit;
  final String rawInput;
  final bool isValid;
  final String formattedSummary;

  const ParsedAmazonDimensions({
    this.width,
    this.length,
    this.height,
    this.rawWidth,
    this.rawLength,
    this.rawHeight,
    required this.sourceUnit,
    required this.targetUnit,
    required this.rawInput,
    required this.isValid,
    required this.formattedSummary,
  });

  /// Apply parsed dimensions onto a RoomItemPlacement
  void applyToPlacement({
    required dynamic placement,
  }) {
    if (!isValid) return;
    if (width != null) placement.customWidth = width;
    if (length != null) placement.customLength = length;
    if (height != null) placement.customHeight = height;
  }
}

class AmazonDimensionParserService {
  /// Robustly parses any variation of Amazon product dimension description strings
  /// Examples:
  /// - `198.1L x 152.4W x 10.2Th Centimeter`
  /// - `47.6D x 120W x 182.4H Centimeters`
  /// - `10L x 15W Centimeters`
  /// - `50D x 100W x 134H Centimeters`
  /// - `78"L x 60"W x 36"H`
  /// - `1.98L x 1.52W x 0.10H Meters`
  /// - `120 x 50 x 180 cm`
  /// - `Length: 198.1 cm, Width: 152.4 cm, Thickness: 10.2 cm`
  static ParsedAmazonDimensions parse(
    String input, {
    DimensionUnit targetUnit = DimensionUnit.feet,
  }) {
    final clean = input.trim();
    if (clean.isEmpty) {
      return ParsedAmazonDimensions(
        sourceUnit: DimensionUnit.centimeters,
        targetUnit: targetUnit,
        rawInput: input,
        isValid: false,
        formattedSummary: 'Empty dimension string',
      );
    }

    // 1. Detect Source Unit
    final sourceUnit = _detectUnit(clean);

    // Variables for raw parsed values in sourceUnit
    double? rawW;
    double? rawL;
    double? rawH;

    // 2. Extract Tagged Dimensions with Regex (L, W, D, H, Th, Breadth, etc.)
    // Matches: `198.1L`, `198.1 L`, `198.1cm L`, `L: 198.1`, `L - 198.1`, `(L) 198.1`, etc.

    // A. Length / Depth
    final lengthMatch = _extractTaggedValue(clean, ['length', 'long', 'len', 'l']);
    final depthMatch = _extractTaggedValue(clean, ['depth', 'deep', 'd']);

    // B. Width / Breadth
    final widthMatch = _extractTaggedValue(clean, ['width', 'wide', 'w', 'breadth', 'b']);

    // C. Height / Thickness
    final heightMatch = _extractTaggedValue(clean, ['height', 'high', 'ht', 'h']);
    final thickMatch = _extractTaggedValue(clean, ['thickness', 'thick', 'thk', 'th', 't']);

    if (widthMatch != null) rawW = widthMatch;
    if (lengthMatch != null) rawL = lengthMatch;
    if (rawL == null && depthMatch != null) rawL = depthMatch;
    if (heightMatch != null) rawH = heightMatch;
    if (rawH == null && thickMatch != null) rawH = thickMatch;

    // 3. Fallback: Parse sequence of numbers separated by 'x', 'X', '×', '*', 'by', or ','
    if (rawW == null && rawL == null && rawH == null) {
      final numbers = _extractSequenceNumbers(clean);
      if (numbers.isNotEmpty) {
        if (numbers.length >= 3) {
          rawL = numbers[0];
          rawW = numbers[1];
          rawH = numbers[2];
        } else if (numbers.length == 2) {
          rawL = numbers[0];
          rawW = numbers[1];
        } else if (numbers.length == 1) {
          rawW = numbers[0];
        }
      }
    }

    final bool isValid = rawW != null || rawL != null || rawH != null;

    // 4. Convert extracted values from sourceUnit to targetUnit
    double? targetW = rawW != null
        ? double.parse(DynamicFloorDimensions.convertValue(rawW, sourceUnit, targetUnit).toStringAsFixed(2))
        : null;
    double? targetL = rawL != null
        ? double.parse(DynamicFloorDimensions.convertValue(rawL, sourceUnit, targetUnit).toStringAsFixed(2))
        : null;
    double? targetH = rawH != null
        ? double.parse(DynamicFloorDimensions.convertValue(rawH, sourceUnit, targetUnit).toStringAsFixed(2))
        : null;

    final summaryParts = <String>[];
    if (rawW != null) summaryParts.add('W: $rawW ${sourceUnit.symbol} (${targetW ?? 0}${targetUnit.symbol})');
    if (rawL != null) summaryParts.add('L/D: $rawL ${sourceUnit.symbol} (${targetL ?? 0}${targetUnit.symbol})');
    if (rawH != null) summaryParts.add('H/Th: $rawH ${sourceUnit.symbol} (${targetH ?? 0}${targetUnit.symbol})');

    return ParsedAmazonDimensions(
      width: targetW,
      length: targetL,
      height: targetH,
      rawWidth: rawW,
      rawLength: rawL,
      rawHeight: rawH,
      sourceUnit: sourceUnit,
      targetUnit: targetUnit,
      rawInput: input,
      isValid: isValid,
      formattedSummary: summaryParts.isNotEmpty ? summaryParts.join(' × ') : 'Could not parse dimensions',
    );
  }

  static DimensionUnit _detectUnit(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('centimeter') ||
        lower.contains('centimetre') ||
        lower.contains('cms') ||
        lower.contains('cm')) {
      return DimensionUnit.centimeters;
    }
    if (lower.contains('millimeter') || lower.contains('mm')) {
      // Millimeters are treated as cm via 0.1 ratio
      return DimensionUnit.centimeters;
    }
    if (lower.contains('meter') || lower.contains('metre') || RegExp(r'\b\d+(\.\d+)?\s*m\b').hasMatch(lower)) {
      return DimensionUnit.meters;
    }
    if (lower.contains('inch') || lower.contains('in') || lower.contains('"')) {
      return DimensionUnit.inches;
    }
    if (lower.contains('feet') || lower.contains('foot') || lower.contains('ft') || lower.contains("'")) {
      return DimensionUnit.feet;
    }
    // Default to centimeters as standard in global Amazon dimension listings
    return DimensionUnit.centimeters;
  }

  static double? _extractTaggedValue(String text, List<String> tags) {
    for (final tag in tags) {
      // Pattern 1: `198.1L` or `198.1 L` or `198.1cm L` or `198.1" L`
      final p1 = RegExp(
        '(\\d+(?:\\.\\d+)?)\\s*(?:cm|in|m|mm|ft|"|\')?\\s*\\b$tag\\b',
        caseSensitive: false,
      );
      final m1 = p1.firstMatch(text);
      if (m1 != null && m1.group(1) != null) {
        return double.tryParse(m1.group(1)!);
      }

      // Pattern 2: `198.1Th` (where tag is suffix without word boundary like 10.2Th)
      final p2 = RegExp(
        '(\\d+(?:\\.\\d+)?)\\s*$tag(?![a-zA-Z])',
        caseSensitive: false,
      );
      final m2 = p2.firstMatch(text);
      if (m2 != null && m2.group(1) != null) {
        return double.tryParse(m2.group(1)!);
      }

      // Pattern 3: `L: 198.1` or `L - 198.1` or `Length = 198.1` or `(L) 198.1`
      final p3 = RegExp(
        '(?:\\b$tag\\b|\\($tag\\))\\s*[:=-]?\\s*(\\d+(?:\\.\\d+)?)',
        caseSensitive: false,
      );
      final m3 = p3.firstMatch(text);
      if (m3 != null && m3.group(1) != null) {
        return double.tryParse(m3.group(1)!);
      }
    }
    return null;
  }

  static List<double> _extractSequenceNumbers(String text) {
    final List<double> list = [];
    final matches = RegExp(r'(\d+(?:\.\d+)?)').allMatches(text);
    for (final m in matches) {
      final val = double.tryParse(m.group(1)!);
      if (val != null) list.add(val);
    }
    return list;
  }
}
