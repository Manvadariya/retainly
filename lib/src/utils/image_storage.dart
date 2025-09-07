import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;

class ImageStorage {
  ImageStorage();

  Future<Directory> _imagesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final images = Directory('${dir.path}/images');
    if (!await images.exists()) {
      await images.create(recursive: true);
    }
    return images;
  }

  Future<(File original, File thumbnail)> saveImageWithThumbnail(
    File input,
  ) async {
    final images = await _imagesDir();
    final id = const Uuid().v4();

    final bytes = await input.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unsupported image format');
    }

    // Save original as JPEG
    final originalPath = '${images.path}/$id.jpg';
    final originalBytes = img.encodeJpg(decoded, quality: 90);
    final originalFile = await File(
      originalPath,
    ).writeAsBytes(originalBytes, flush: true);

    // Thumbnail max width 400
    final resized = decoded.width > 400
        ? img.copyResize(decoded, width: 400)
        : decoded;
    final thumbPath = '${images.path}/${id}_thumb.jpg';
    final thumbBytes = img.encodeJpg(resized, quality: 80);
    final thumbFile = await File(
      thumbPath,
    ).writeAsBytes(thumbBytes, flush: true);

    return (originalFile, thumbFile);
  }

  Future<void> deleteImagePair(String originalPath) async {
    try {
      final file = File(originalPath);
      if (await file.exists()) {
        await file.delete();
      }
      final thumbPath = originalPath.replaceFirst(
        RegExp(r'(\.jpg|\.jpeg|\.png)\$'),
        '_thumb.jpg',
      );
      final thumb = File(thumbPath);
      if (await thumb.exists()) {
        await thumb.delete();
      }
    } catch (_) {
      // ignore
    }
  }
}
