import 'dart:typed_data';

import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    if (dart.library.io) 'file_download_helper_io.dart';

class FileDownloadHelper {
  /// Saves the bytes as a file to the user's Downloads folder on PC / triggers browser download on web
  static Future<String?> downloadFile(Uint8List bytes, String filename) {
    return saveAndDownloadFile(bytes, filename);
  }

  /// Opens the file or parent folder in Finder (macOS) / File Explorer (Windows) / Files (Linux)
  static Future<void> openFileOrFolder(String filePath) {
    return revealInFolder(filePath);
  }
}
