class DimensionSuggestion {
  final String itemName;
  final double recommendedWidthFt;
  final double recommendedLengthFt;
  final double recommendedHeightFt;
  final String optimalLocation;
  final String architecturalReasoning;
  final double clearanceRemainingFt;

  const DimensionSuggestion({
    required this.itemName,
    required this.recommendedWidthFt,
    required this.recommendedLengthFt,
    required this.recommendedHeightFt,
    required this.optimalLocation,
    required this.architecturalReasoning,
    required this.clearanceRemainingFt,
  });
}

class FurnitureDimensionAdvisor {
  static DimensionSuggestion suggestBedDimension(String bedType) {
    switch (bedType.toLowerCase()) {
      case 'queen':
        return const DimensionSuggestion(
          itemName: 'Queen Bed',
          recommendedWidthFt: 5.0,
          recommendedLengthFt: 6.25,
          recommendedHeightFt: 3.0,
          optimalLocation: 'Top-Left Solid Feature Wall (X: 0.6\', Y: 0.6\')',
          architecturalReasoning:
              'Provides a generous 3.3\' walkway to the wardrobe and avoids direct doorway traffic while maintaining clear sightlines to the room entry.',
          clearanceRemainingFt: 3.28,
        );
      case 'single':
        return const DimensionSuggestion(
          itemName: 'Single Bed',
          recommendedWidthFt: 3.5,
          recommendedLengthFt: 6.25,
          recommendedHeightFt: 2.8,
          optimalLocation: 'Top-Left Corner (X: 0.6\', Y: 0.6\')',
          architecturalReasoning:
              'Maximizes floor area, freeing up over 4.8\' for a dedicated study desk and lounge seating.',
          clearanceRemainingFt: 4.78,
        );
      case 'king':
      default:
        return const DimensionSuggestion(
          itemName: 'King Bed (Recommended)',
          recommendedWidthFt: 5.52,
          recommendedLengthFt: 6.25,
          recommendedHeightFt: 3.2,
          optimalLocation: 'Top-Left Solid Feature Wall (X: 0.6\', Y: 0.6\')',
          architecturalReasoning:
              'Perfect fit for the 10.4\' room width. Leaves exactly 2.76\' central circulation space to the 2.12\' wardrobe on the opposite dividing wall.',
          clearanceRemainingFt: 2.76,
        );
    }
  }

  static DimensionSuggestion suggestStudyDesk() {
    return const DimensionSuggestion(
      itemName: 'Ergonomic Workstation / Study Desk',
      recommendedWidthFt: 4.5,
      recommendedLengthFt: 2.0,
      recommendedHeightFt: 2.5,
      optimalLocation: 'Left Wall between Bed and Sofa (X: 0.6\', Y: 11.2\')',
      architecturalReasoning:
          'Positioned perpendicular to window for natural side-lighting. Reserves 3.0\' chair pull-out clearance without blocking the TV viewing corridor.',
      clearanceRemainingFt: 3.84,
    );
  }

  static DimensionSuggestion suggestWardrobe() {
    return const DimensionSuggestion(
      itemName: 'Sliding Wardrobe',
      recommendedWidthFt: 2.12,
      recommendedLengthFt: 6.18,
      recommendedHeightFt: 8.0,
      optimalLocation: 'Top-Right Dividing Wall (X: 7.8\', Y: 0.6\')',
      architecturalReasoning:
          'Utilizes the full upper section of the dividing wall. Sliding shutters eliminate door swing clearance issues with the bed.',
      clearanceRemainingFt: 2.76,
    );
  }

  static DimensionSuggestion suggestSofa() {
    return const DimensionSuggestion(
      itemName: '3-Seater Living Sofa',
      recommendedWidthFt: 5.52,
      recommendedLengthFt: 5.42,
      recommendedHeightFt: 2.7,
      optimalLocation: 'Bottom-Left Zone of Master Room (X: 0.6\', Y: 12.0\')',
      architecturalReasoning:
          'Directly faces the 5.26\' TV media unit on the dividing wall with an ideal 7.5\' 4K viewing distance.',
      clearanceRemainingFt: 2.76,
    );
  }

  static DimensionSuggestion suggestTvUnit() {
    return const DimensionSuggestion(
      itemName: '55" Smart TV & Media Console',
      recommendedWidthFt: 1.67,
      recommendedLengthFt: 5.26,
      recommendedHeightFt: 1.6,
      optimalLocation: 'Lower Dividing Wall (X: 8.2\', Y: 10.0\')',
      architecturalReasoning:
          'Mounted at 3.5\' center height for seated sofa viewing and angled for comfortable viewing from the bed.',
      clearanceRemainingFt: 6.53,
    );
  }

  static DimensionSuggestion suggestKitchenHob() {
    return const DimensionSuggestion(
      itemName: '4-Burner Gas Hob & Chimney',
      recommendedWidthFt: 3.61,
      recommendedLengthFt: 2.38,
      recommendedHeightFt: 2.9,
      optimalLocation: 'Top-Left Kitchen Counter (X: 10.8\', Y: 0.6\')',
      architecturalReasoning:
          'Direct exterior wall access for chimney exhaust ducting, with 1.5\' landing space on both sides for hot pans.',
      clearanceRemainingFt: 3.2,
    );
  }

  static DimensionSuggestion suggestBreakfastCounter() {
    return const DimensionSuggestion(
      itemName: 'Quartz Breakfast Counter',
      recommendedWidthFt: 2.03,
      recommendedLengthFt: 4.2,
      recommendedHeightFt: 3.2,
      optimalLocation: 'Left Kitchen Partition (X: 10.8\', Y: 3.4\')',
      architecturalReasoning:
          'Creates a social transition between kitchen and staircase corridor without closing off natural light.',
      clearanceRemainingFt: 3.4,
    );
  }
}
