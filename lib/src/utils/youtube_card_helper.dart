import 'package:retainly/src/data/card_entity.dart';
import 'package:retainly/src/models/youtube_metadata.dart';
import 'package:retainly/src/services/youtube_service_exports.dart';

/// Helper class to handle YouTube-related functionality across the app
class YouTubeCardHelper {
  /// Checks if a card is a YouTube card
  static bool isYouTubeCard(CardEntity card) {
    // A card is a YouTube card if:
    // 1. It's a link type
    // 2. It has a YouTube URL
    // 3. OR it has metadata with videoId
    if (card.type != 'link' || card.url == null) {
      return false;
    }

    final youtubeService = YouTubeService();

    // Check if the URL is a YouTube URL
    if (youtubeService.isYoutubeUrl(card.url!)) {
      return true;
    }

    // Check if metadata contains videoId
    return card.metadata != null && card.metadata!.containsKey('videoId');
  }

  /// Extracts YouTubeMetadata from a card
  /// Returns null if the card is not a YouTube card
  static YouTubeMetadata? extractMetadata(CardEntity card) {
    if (!isYouTubeCard(card)) {
      return null;
    }

    // Create YouTube service with API key (exports maps to new service)
    final youtubeService = YouTubeService();

    // Extract video ID from the URL
    String? videoId;
    if (card.url != null) {
      videoId = youtubeService.extractVideoId(card.url!);
    }

    // Try to get video ID from metadata if not in URL
    if ((videoId == null || videoId.isEmpty) &&
        card.metadata != null &&
        card.metadata!.containsKey('videoId')) {
      final storedId = card.metadata!['videoId'] as String? ?? '';
      if (storedId.isNotEmpty) {
        videoId = storedId;
      }
    }

    // If we don't have a valid video ID, we can't create metadata
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    // If the card has metadata, use it to create rich YouTubeMetadata
    if (card.metadata != null) {
      try {
        return YouTubeMetadata.fromJson(card.metadata!);
      } catch (_) {
        // Fallback to minimal metadata if stored JSON isn't in expected shape
        final description = card.metadata!['description'] as String? ?? '';
        final publishDate = card.metadata!['publishDate'] as String? ?? '';
        final tags = (card.metadata!['tags'] is List)
            ? List<String>.from(card.metadata!['tags'])
            : <String>[];
        final thumbMid =
            card.metadata!['thumbnailMedium'] as String? ??
            'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
        final thumbLow =
            card.metadata!['thumbnailLow'] as String? ??
            'https://img.youtube.com/vi/$videoId/default.jpg';
        final thumbHigh =
            card.metadata!['thumbnailHigh'] as String? ??
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
        final author = card.metadata!['author'] as String?;
        final category = card.metadata!['category'] as String?;

        return YouTubeMetadata(
          videoId: videoId,
          title: card.content,
          description: description,
          thumbnailLow: thumbLow,
          thumbnailMedium: thumbMid,
          thumbnailHigh: thumbHigh,
          publishDate: publishDate,
          tags: tags,
          author: author,
          category: category,
        );
      }
    }

    // If we don't have metadata but have a valid video ID, create minimal metadata
    return YouTubeMetadata(
      videoId: videoId,
      title: card.content,
      description: card.body ?? '',
      thumbnailLow: 'https://img.youtube.com/vi/$videoId/default.jpg',
      thumbnailMedium: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
      thumbnailHigh: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      publishDate: '',
      tags: [],
    );
  }
}
