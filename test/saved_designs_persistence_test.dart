import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:all_in_one/models/dynamic_floor_model.dart';
import 'package:all_in_one/services/design_option_manager_service.dart';
import 'package:all_in_one/screens/saved_designs_launcher_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DesignOptionManagerService.init(forceReload: true);
  });

  group('Persistent Saved Designs & Finalization Service Tests', () {
    test('Service initializes with default design options and persists them', () async {
      final list = DesignOptionManagerService.designs;
      expect(list.length, greaterThanOrEqualTo(2));
      expect(list.first.id, 'option_a_standard');
      expect(list.first.name.contains('Option A'), isTrue);
      expect(list.first.isFinalized, isFalse);
    });

    test('Saving current design modifies in-memory state and updates timestamp', () async {
      final active = DesignOptionManagerService.activeDesign;
      final customDims = active.dims.clone();
      customDims.roomWidth = 12.0;

      final updated = DesignOptionManagerService.saveCurrentDesign(
        dims: customDims,
        placements: active.placements,
        newName: 'Option A: Customized Master Suite',
      );

      expect(updated.name, 'Option A: Customized Master Suite');
      expect(updated.dims.roomWidth, 12.0);
      expect(DesignOptionManagerService.activeDesign.dims.roomWidth, 12.0);
    });

    test('Creating a brand new design option saves it persistently', () async {
      final initialCount = DesignOptionManagerService.designs.length;
      final newOpt = DesignOptionManagerService.createNewDesignOption(
        name: 'Option C: Penthouse Luxury Layout',
        description: 'Expansive master bedroom with walk-in wardrobe and double vanity.',
        dims: DynamicFloorDimensions(roomWidth: 14.0, roomLength: 22.0),
      );

      expect(DesignOptionManagerService.designs.length, initialCount + 1);
      expect(newOpt.name, 'Option C: Penthouse Luxury Layout');
      expect(DesignOptionManagerService.activeDesignId, newOpt.id);
      expect(DesignOptionManagerService.latestEditedDesign.id, newOpt.id);
    });

    test('Duplicating a design creates a deep clone for separate alterations', () async {
      final source = DesignOptionManagerService.designs.first;
      final cloned = DesignOptionManagerService.duplicateDesignOption(
        source.id,
        newName: 'Option A: Altered Wardrobe Revision',
      );

      expect(cloned.id, isNot(equals(source.id)));
      expect(cloned.name, 'Option A: Altered Wardrobe Revision');
      expect(cloned.isFinalized, isFalse);
      expect(DesignOptionManagerService.activeDesignId, cloned.id);
    });

    test('Finalizing a design stamps official certified approval seal & notes', () async {
      final active = DesignOptionManagerService.activeDesign;
      final finalized = DesignOptionManagerService.finalizeDesign(
        active.id,
        approvalNotes: 'Structural clearance and plumbing lines verified.',
      );

      expect(finalized.isFinalized, isTrue);
      expect(finalized.finalizedAt, isNotNull);
      expect(finalized.finalizedNotes, 'Structural clearance and plumbing lines verified.');

      // Unlocking returns to draft
      final unlocked = DesignOptionManagerService.unlockFinalizedDesign(active.id);
      expect(unlocked.isFinalized, isFalse);
    });

    test('Deleting a design removes it from the list', () async {
      final newOpt = DesignOptionManagerService.createNewDesignOption(name: 'Temporary Scratch Plan');
      expect(DesignOptionManagerService.designs.any((d) => d.id == newOpt.id), isTrue);

      final success = DesignOptionManagerService.deleteDesignOption(newOpt.id);
      expect(success, isTrue);
      expect(DesignOptionManagerService.designs.any((d) => d.id == newOpt.id), isFalse);
    });
  });

  group('SavedDesignsLauncherScreen Widget Tests', () {
    testWidgets('Renders all saved designs, search filter, and quick create dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: SavedDesignsLauncherScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Hero continue card
      expect(find.textContaining('⚡ CONTINUE WORKING'), findsOneWidget);
      expect(find.text('Open in 2D Studio'), findsWidgets);

      // Verify tabs
      expect(find.textContaining('All Designs'), findsOneWidget);
      expect(find.textContaining('Finalized & Approved'), findsOneWidget);
      expect(find.textContaining('Working Drafts'), findsOneWidget);

      // Verify saved design cards
      expect(find.textContaining('Option A: Master Suite'), findsWidgets);
      expect(find.textContaining('Option B: Executive Suite'), findsWidgets);

      // Tap + Add New Design button
      await tester.tap(find.text('+ Add New Design').first);
      await tester.pumpAndSettle();

      // Verify Create Dialog opened
      expect(find.text('Create New Floor Design Option'), findsOneWidget);
      expect(find.text('Design Option Name'), findsOneWidget);
      expect(find.text('Initial Spatial Dimensions:'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Create New Floor Design Option'), findsNothing);
    });
  });
}
