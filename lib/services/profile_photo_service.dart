import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ProfilePhotoService {
  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndSave({required ImageSource source}) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final ext = _extOf(picked.path);
    final dest = File(
      '${docs.path}/profile_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(dest.path);
    return dest.path;
  }

  Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }

  String _extOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return '.jpg';
    return path.substring(dot);
  }
}
