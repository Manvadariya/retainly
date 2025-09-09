import 'dart:io';
import 'dart:typed_data';
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
    print('saveImageWithThumbnail: Processing image from ${input.path}');

    final images = await _imagesDir();
    final id = const Uuid().v4();

    try {
      // First check if the file exists
      if (!await input.exists()) {
        throw Exception('Input file does not exist: ${input.path}');
      }

      // Try to read the file multiple ways in case one fails
      Uint8List? bytes;

      try {
        bytes = await input.readAsBytes();
        print('saveImageWithThumbnail: Read ${bytes.length} bytes from input');
      } catch (e) {
        print(
          'saveImageWithThumbnail: Error reading file with readAsBytes: $e',
        );
        // Try an alternate method (reading through a stream)
        try {
          final byteData = await input.readAsBytes();
          bytes = byteData;
          print(
            'saveImageWithThumbnail: Read ${bytes.length} bytes with alternate method',
          );
        } catch (e2) {
          print('saveImageWithThumbnail: All file reading methods failed: $e2');
          rethrow;
        }
      }

      if (bytes.isEmpty) {
        throw Exception('Image file is empty');
      }

      // Try to decode the image, with fallback options
      img.Image? decoded;
      try {
        decoded = img.decodeImage(bytes);
      } catch (e) {
        print('saveImageWithThumbnail: Standard decode failed: $e');
        // Try alternative decoders if the main one fails
        try {
          if (bytes.length > 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
            // JPEG magic bytes
            decoded = img.decodeJpg(bytes);
          } else if (bytes.length > 8 &&
              bytes[0] == 0x89 &&
              bytes[1] == 0x50 &&
              bytes[2] == 0x4E &&
              bytes[3] == 0x47) {
            // PNG magic bytes
            decoded = img.decodePng(bytes);
          } else {
            // Try all formats as a last resort
            decoded = img.decodeImage(bytes);
          }
        } catch (e2) {
          print('saveImageWithThumbnail: All decode attempts failed: $e2');
        }
      }

      if (decoded == null) {
        throw Exception('Unsupported image format or corrupt image data');
      }

      print(
        'saveImageWithThumbnail: Successfully decoded image: ${decoded.width}x${decoded.height}',
      );

      // Save original as JPEG
      final originalPath = '${images.path}/$id.jpg';
      final originalBytes = img.encodeJpg(decoded, quality: 90);

      if (originalBytes.isEmpty) {
        throw Exception('Failed to encode image as JPEG');
      }

      print(
        'saveImageWithThumbnail: Encoded original image: ${originalBytes.length} bytes',
      );

      final originalFile = await File(
        originalPath,
      ).writeAsBytes(originalBytes, flush: true);

      print(
        'saveImageWithThumbnail: Saved original file to ${originalFile.path}',
      );

      // Thumbnail max width 400
      final resized = decoded.width > 400
          ? img.copyResize(decoded, width: 400)
          : decoded;
      final thumbPath = '${images.path}/${id}_thumb.jpg';
      final thumbBytes = img.encodeJpg(resized, quality: 80);
      final thumbFile = await File(
        thumbPath,
      ).writeAsBytes(thumbBytes, flush: true);

      print('saveImageWithThumbnail: Saved thumbnail to ${thumbFile.path}');

      // Verify files were created successfully
      if (!await originalFile.exists() || !await thumbFile.exists()) {
        throw Exception('Failed to save image files');
      }

      return (originalFile, thumbFile);
    } catch (e) {
      print('saveImageWithThumbnail ERROR: $e');

      // Clean up any partial files
      final originalPath = '${images.path}/$id.jpg';
      final thumbPath = '${images.path}/${id}_thumb.jpg';

      try {
        final originalFile = File(originalPath);
        if (await originalFile.exists()) {
          await originalFile.delete();
        }

        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      } catch (cleanupError) {
        print('Error during cleanup: $cleanupError');
      }

      rethrow;
    }
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

  // New method to save an image from a file and return the path
  Future<String> saveImageFromFile(File input) async {
    try {
      print('ImageStorage: Saving image from file ${input.path}');

      // First verify the input file exists and has data
      if (!await input.exists()) {
        throw Exception('Input image file does not exist: ${input.path}');
      }

      final fileSize = await input.length();
      if (fileSize == 0) {
        throw Exception('Input image file is empty: ${input.path}');
      }

      print('ImageStorage: File exists with size: $fileSize bytes');

      final (originalFile, thumbFile) = await saveImageWithThumbnail(input);

      // Verify output file was created
      if (!await originalFile.exists()) {
        throw Exception('Failed to create image file at: ${originalFile.path}');
      }

      print('ImageStorage: Image saved successfully');
      print('ImageStorage: Original image path: ${originalFile.path}');
      print('ImageStorage: Thumbnail path: ${thumbFile.path}');
      print(
        'ImageStorage: Original file size: ${await originalFile.length()} bytes',
      );

      // Double-check the saved image is readable by reading a few bytes
      try {
        await originalFile.openRead(0, 10).first;
        print('ImageStorage: Verified file is readable');
      } catch (e) {
        print('ImageStorage: WARNING - File may be corrupted: $e');
      }

      return originalFile.path;
    } catch (e) {
      print('ImageStorage: ERROR saving image - $e');
      rethrow;
    }
  }
}
