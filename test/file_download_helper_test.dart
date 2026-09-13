import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_in_one/services/file_download_helper.dart';
import 'package:all_in_one/services/blueprint_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('File Download & Blueprint Export Tests', () {
    test('FileDownloadHelper.downloadFile successfully saves bytes to disk on PC', () async {
      final sampleBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      const filename = 'test_blueprint_4k.png';

      final path = await FileDownloadHelper.downloadFile(sampleBytes, filename);
      expect(path, isNotNull);
      expect(path!.endsWith(filename), isTrue);
    });

    test('BlueprintExportService.saveFileToDisk delegates to universal downloader', () async {
      final sampleBytes = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);
      const filename = 'test_4k_export.png';

      final path = await BlueprintExportService.saveFileToDisk(sampleBytes, filename);
      expect(path, isNotNull);
      expect(path!.endsWith(filename), isTrue);
    });
  });
}
