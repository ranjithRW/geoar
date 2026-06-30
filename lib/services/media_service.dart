import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

class MediaService {
  static MediaService? _instance;
  static MediaService get instance => _instance ??= MediaService._();
  MediaService._();

  final _picker = ImagePicker();
  // FIX: 'const Uuid _uuid = const Uuid()' is invalid — cannot use 'const' as
  // both the field type keyword and the value initialiser keyword.
  final _uuid = const Uuid();

  // ─── Image ────────────────────────────────────────────────────────────────

  Future<String?> pickImageFromGallery() async {
    final xFile = await _picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return null;
    return _compressAndSave(xFile.path);
  }

  Future<String?> pickImageFromCamera() async {
    final xFile = await _picker.pickImage(source: ImageSource.camera);
    if (xFile == null) return null;
    return _compressAndSave(xFile.path);
  }

  Future<String?> _compressAndSave(String sourcePath) async {
    final dir = await _getMediaDir('images');
    final ext = p.extension(sourcePath).toLowerCase();
    final allowedExts = ['.jpg', '.jpeg', '.png', '.webp'];
    if (!allowedExts.contains(ext)) return null;

    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // FIX: img.copyResize — only supply ONE dimension to preserve aspect ratio.
    // Supplying both width AND height simultaneously forces an exact resize and
    // ignores the aspect ratio contract; passing the smaller dimension as -1 or
    // omitting it (null) is the correct approach in image ^4.x.
    img.Image resized = decoded;
    if (decoded.width > 1920 || decoded.height > 1920) {
      if (decoded.width >= decoded.height) {
        // Landscape: constrain width, let height scale automatically.
        resized = img.copyResize(decoded, width: 1920);
      } else {
        // Portrait: constrain height, let width scale automatically.
        resized = img.copyResize(decoded, height: 1920);
      }
    }

    final outPath = p.join(dir.path, '${_uuid.v4()}.jpg');
    final compressed = img.encodeJpg(resized, quality: 80);
    await File(outPath).writeAsBytes(compressed);
    return outPath;
  }

  // ─── Video ────────────────────────────────────────────────────────────────

  Future<String?> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'avi'],
    );
    if (result == null || result.files.single.path == null) return null;
    return _copyVideoToLocal(result.files.single.path!);
  }

  Future<String?> pickVideoFromCamera() async {
    final xFile = await _picker.pickVideo(source: ImageSource.camera);
    if (xFile == null) return null;
    return _copyVideoToLocal(xFile.path);
  }

  Future<String?> _copyVideoToLocal(String sourcePath) async {
    final dir = await _getMediaDir('videos');
    final ext = p.extension(sourcePath).toLowerCase();
    final allowed = ['.mp4', '.mov', '.avi'];
    if (!allowed.contains(ext)) return null;
    final outPath = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(sourcePath).copy(outPath);
    return outPath;
  }

  // ─── 3D Model ─────────────────────────────────────────────────────────────

  Future<String?> pick3DModel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'gltf'],
    );
    if (result == null || result.files.single.path == null) return null;
    final dir = await _getMediaDir('models');
    final src = result.files.single.path!;
    final ext = p.extension(src).toLowerCase();
    final outPath = p.join(dir.path, '${_uuid.v4()}$ext');
    await File(src).copy(outPath);
    return outPath;
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  Future<void> deleteMedia(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearCache() async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'geoar_media'));
    if (await mediaDir.exists()) {
      await mediaDir.delete(recursive: true);
    }
  }

  Future<Directory> _getMediaDir(String sub) async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'geoar_media', sub));
    if (!await mediaDir.exists()) await mediaDir.create(recursive: true);
    return mediaDir;
  }
}
