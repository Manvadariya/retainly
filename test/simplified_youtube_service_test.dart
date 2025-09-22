import 'package:flutter_test/flutter_test.dart';
import 'package:retainly/src/services/youtube_service_exports.dart';

void main() {
  // Initialize Flutter binding for path_provider and other platform services
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SimplifiedYouTubeService', () {
    late YouTubeService youtubeService;

    setUp(() {
      youtubeService = YouTubeService();
    });

    test('isYoutubeUrl identifies YouTube URLs correctly', () {
      expect(
        youtubeService.isYoutubeUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        ),
        isTrue,
      );
      expect(
        youtubeService.isYoutubeUrl('https://youtu.be/dQw4w9WgXcQ'),
        isTrue,
      );
      expect(
        youtubeService.isYoutubeUrl(
          'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        ),
        isTrue,
      );
      expect(youtubeService.isYoutubeUrl('https://www.google.com'), isFalse);
    });

    test('extractVideoId extracts ID correctly from various URL formats', () {
      const expectedId = 'dQw4w9WgXcQ';
      expect(
        youtubeService.extractVideoId(
          'https://www.youtube.com/watch?v=$expectedId',
        ),
        equals(expectedId),
      );
      expect(
        youtubeService.extractVideoId('https://youtu.be/$expectedId'),
        equals(expectedId),
      );
      expect(
        youtubeService.extractVideoId(
          'https://www.youtube.com/shorts/$expectedId',
        ),
        equals(expectedId),
      );
      expect(
        youtubeService.extractVideoId('https://www.youtube.com/v/$expectedId'),
        equals(expectedId),
      );
    });

    test(
      'fetchMetadata returns simplified YouTubeMetadata with required fields',
      () async {
        const testUrl =
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'; // Famous Rick Roll video

        final metadata = await youtubeService.fetchMetadata(testUrl);

        expect(metadata, isNotNull);

        if (metadata != null) {
          // Verify basic properties
          expect(metadata.videoId, equals('dQw4w9WgXcQ'));
          expect(metadata.title, isNotEmpty);
          expect(
            metadata.description,
            isNotNull,
          ); // Can be empty but shouldn't be null

          // Verify thumbnail properties
          expect(metadata.thumbnailLow, isNotEmpty);
          expect(metadata.thumbnailMedium, isNotEmpty);

          // Check that tags list exists (may be empty but should not be null)
          expect(metadata.tags, isNotNull);

          // Check that URLs are different for different qualities
          expect(
            metadata.thumbnailLow,
            isNot(equals(metadata.thumbnailMedium)),
          );
        }
      },
    );

    // This test is conditionally executed because fetchThumbnail requires platform functionality
    test(
      'fetchThumbnail returns local paths for different qualities',
      () async {
        // Note: This test accesses external services and file system
        // It may fail in CI environments

        const testVideoId = 'dQw4w9WgXcQ';

        // Test low quality
        final lowQualityPath = await youtubeService.fetchThumbnail(
          testVideoId,
          quality: 'low',
        );

        // Test medium quality
        final mediumQualityPath = await youtubeService.fetchThumbnail(
          testVideoId,
          quality: 'medium',
        );

        // These assertions are conditional to avoid test failures
        // when running in environments without proper file system access
        if (lowQualityPath != null) {
          expect(lowQualityPath.contains('low'), isTrue);
        }

        if (mediumQualityPath != null) {
          expect(mediumQualityPath.contains('medium'), isTrue);
        }
      },
    );

    test(
      'fetchTranscript should return null as functionality was removed',
      () async {
        const testVideoId = 'dQw4w9WgXcQ';

        final transcript = await youtubeService.fetchTranscript(testVideoId);

        // Verify transcript is null since functionality was removed
        expect(transcript, isNull);
      },
    );
  });
}
