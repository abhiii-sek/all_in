import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveAndDownloadFile(Uint8List bytes, String filename) async {
  try {
    Directory? targetDir;

    // 1. Prioritize standard user Downloads directory on PC/Mac
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      final userDownloads = Directory(Platform.isWindows ? '$home\\Downloads' : '$home/Downloads');
      if (await userDownloads.exists()) {
        targetDir = userDownloads;
      }
    }

    // 2. Fallback to path_provider getDownloadsDirectory
    if (targetDir == null) {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
    }

    // 3. Fallback to Desktop if available
    if (targetDir == null && home != null) {
      final userDesktop = Directory(Platform.isWindows ? '$home\\Desktop' : '$home/Desktop');
      if (await userDesktop.exists()) {
        targetDir = userDesktop;
      }
    }

    // 4. Fallback to Documents
    targetDir ??= await getApplicationDocumentsDirectory();

    final sep = Platform.isWindows ? '\\' : '/';
    final filePath = '${targetDir.path}$sep$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  } catch (e) {
    return null;
  }
}

Future<void> revealInFolder(String filePath) async {
  try {
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', filePath]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', filePath]);
    } else if (Platform.isLinux) {
      final file = File(filePath);
      await Process.run('xdg-open', [file.parent.path]);
    }
  } catch (_) {}
}
