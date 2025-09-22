import 'package:flutter_test/flutter_test.dart';
import 'package:retainly/src/services/new_youtube_service.dart';

void main() {
  group('YouTubeService', () {
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
      'fetchMetadata returns YouTubeMetadata with multiple thumbnail qualities',
      () async {
        const testUrl =
            'https://www.youtube.com/watch?v=dQw4w9WgXcQ'; // Famous Rick Roll video

        final metadata = await youtubeService.fetchMetadata(testUrl);

        expect(metadata, isNotNull);

        if (metadata != null) {
          // Verify basic properties
          expect(metadata.videoId, equals('dQw4w9WgXcQ'));
          expect(metadata.title, isNotEmpty);
          expect(metadata.author, isNotEmpty);

          // Verify thumbnail properties
          expect(metadata.thumbnailLow, isNotEmpty);
          expect(metadata.thumbnailMedium, isNotEmpty);
          expect(metadata.thumbnailHigh, isNotEmpty);

          // Check that URLs are different for different qualities
          expect(metadata.thumbnailLow, isNot(equals(metadata.thumbnailHigh)));
        }
      },
    );

    test(
      'fetchThumbnail returns local paths for different qualities',
      () async {
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

        // Test high quality
        final highQualityPath = await youtubeService.fetchThumbnail(
          testVideoId,
          quality: 'high',
        );

        expect(lowQualityPath, isNotNull);
        expect(mediumQualityPath, isNotNull);
        expect(highQualityPath, isNotNull);

        // Check that the paths include quality indicators
        if (lowQualityPath != null) {
          expect(lowQualityPath.contains('low'), isTrue);
        }

        if (mediumQualityPath != null) {
          expect(mediumQualityPath.contains('medium'), isTrue);
        }

        if (highQualityPath != null) {
          expect(highQualityPath.contains('high'), isTrue);
        }
      },
    );
  });
}
