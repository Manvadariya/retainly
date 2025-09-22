import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/youtube_metadata.dart';

/// A service for fetching and processing YouTube video metadata.
/// Simplified to focus only on essential metadata for better performance.
class YouTubeService {
  /// Creates a new YouTubeService instance
  YouTubeService({String? apiKey});

  /// Checks if a given URL is a YouTube URL.
  bool isYoutubeUrl(String url) {
    final normalizedUrl = url.toLowerCase();

    // Check for common YouTube URL patterns
    return normalizedUrl.contains('youtube.com/watch') ||
        normalizedUrl.contains('youtu.be/') ||
        normalizedUrl.contains('youtube.com/shorts/') ||
        normalizedUrl.contains('youtube.com/v/');
  }

  /// Extracts the video ID from a YouTube URL.
  /// Returns null if the video ID cannot be extracted.
  String? extractVideoId(String url) {
    // Handle youtu.be short links
    RegExp youtubeBe = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})');
    Match? youtubeBeMatch = youtubeBe.firstMatch(url);
    if (youtubeBeMatch != null && youtubeBeMatch.groupCount >= 1) {
      return youtubeBeMatch.group(1);
    }

    // Handle youtube.com/shorts/ links
    RegExp youtubeShorts = RegExp(r'youtube\.com/shorts/([a-zA-Z0-9_-]{11})');
    Match? youtubeShortsMatch = youtubeShorts.firstMatch(url);
    if (youtubeShortsMatch != null && youtubeShortsMatch.groupCount >= 1) {
      return youtubeShortsMatch.group(1);
    }

    // Handle youtube.com/v/ links
    RegExp youtubeV = RegExp(r'youtube\.com/v/([a-zA-Z0-9_-]{11})');
    Match? youtubeVMatch = youtubeV.firstMatch(url);
    if (youtubeVMatch != null && youtubeVMatch.groupCount >= 1) {
      return youtubeVMatch.group(1);
    }

    // Handle youtube.com/watch?v= links
    try {
      Uri uri = Uri.parse(url);
      if (uri.host.contains('youtube.com') && uri.path.contains('watch')) {
        return uri.queryParameters['v'];
      }
    } catch (e) {
      print('Error parsing YouTube URL: $e');
    }

    // Try a generic regex as fallback for any URL containing an 11-character ID
    RegExp genericIdPattern = RegExp(
      r'(?:^|[^a-zA-Z0-9_-])([a-zA-Z0-9_-]{11})(?:$|[^a-zA-Z0-9_-])',
    );
    Match? genericMatch = genericIdPattern.firstMatch(url);
    if (genericMatch != null && genericMatch.groupCount >= 1) {
      return genericMatch.group(1);
    }

    return null;
  }

  /// Fetches a YouTube video thumbnail and saves it locally.
  /// Quality can be: 'low', 'medium'
  /// Returns the local path to the saved thumbnail.
  Future<String?> fetchThumbnail(
    String videoId, {
    String quality = 'medium',
  }) async {
    try {
      String thumbnailUrl;

      // Select URL based on requested quality
      switch (quality) {
        case 'low':
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/default.jpg'; // 120x90
          break;
        case 'medium':
        default:
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/mqdefault.jpg'; // 320x180
          break;
      }

      // Fetch the thumbnail
      final response = await http.get(Uri.parse(thumbnailUrl));
      if (response.statusCode != 200) {
        print('Failed to fetch $quality thumbnail for video ID: $videoId');
        return null;
      }

      return await _saveThumbnailToFile(
        videoId,
        response.bodyBytes,
        quality: quality,
      );
    } catch (e) {
      print('Error fetching YouTube thumbnail: $e');
      return null;
    }
  }

  /// Save the thumbnail bytes to a local file and return the file path
  Future<String?> _saveThumbnailToFile(
    String videoId,
    List<int> imageBytes, {
    String quality = 'medium',
  }) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/${const Uuid().v4()}_${videoId}_$quality.jpg';

      final File file = File(filePath);
      await file.writeAsBytes(imageBytes);

      print('Thumbnail saved to: $filePath');
      return filePath;
    } catch (e) {
      print('Error saving thumbnail to file: $e');
      return null;
    }
  }

  /// Fetches essential metadata for a YouTube video by its URL.
  /// Optimized for quick extraction of only required metadata.
  /// Returns a YouTubeMetadata object containing essential metadata.
  Future<YouTubeMetadata?> fetchMetadata(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      print('Could not extract video ID from URL: $url');
      return null;
    }

    try {
      // Quick and reliable HTML page fetch to extract ytInitialPlayerResponse JSON
      final response = await http.get(
        Uri.parse('https://www.youtube.com/watch?v=$videoId'),
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        print('Failed to fetch YouTube page: ${response.statusCode}');
        return _createFallbackMetadata(videoId);
      }

      final htmlContent = response.body;

      // Extract ytInitialPlayerResponse JSON using regex for speed
      final regex = RegExp(r'ytInitialPlayerResponse\s*=\s*(\{.+?\})\s*;');
      final match = regex.firstMatch(htmlContent);

      if (match != null && match.groupCount >= 1) {
        try {
          final jsonStr = match.group(1)!;
          final data = json.decode(jsonStr);

          // Access videoDetails section
          if (data['videoDetails'] != null) {
            final videoDetails = data['videoDetails'];
            List<String> tags = [];

            // Extract tags from videoDetails and meta tags
            if (videoDetails['keywords'] is List) {
              tags = List<String>.from(videoDetails['keywords']);
            }

            // Extract additional tags from meta tags
            final document = html_parser.parse(htmlContent);
            final metaTags = document.getElementsByTagName('meta');

            for (final tag in metaTags) {
              // Get og:video:tag tags
              if (tag.attributes['property'] == 'og:video:tag' &&
                  tag.attributes['content'] != null) {
                final tagContent = tag.attributes['content']!;
                if (!tags.contains(tagContent)) {
                  tags.add(tagContent);
                }
              }

              // Get keywords meta tag
              if (tag.attributes['name'] == 'keywords' &&
                  tag.attributes['content'] != null) {
                final keywordsStr = tag.attributes['content']!;
                final keywordsList = keywordsStr
                    .split(',')
                    .map((k) => k.trim())
                    .toList();

                // Add unique keywords to tags
                for (final keyword in keywordsList) {
                  if (keyword.isNotEmpty && !tags.contains(keyword)) {
                    tags.add(keyword);
                  }
                }
              }
            }

            // Get thumbnail URLs
            String thumbnailLow =
                'https://img.youtube.com/vi/$videoId/default.jpg';
            String thumbnailMedium =
                'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

            if (videoDetails['thumbnail'] != null &&
                videoDetails['thumbnail']['thumbnails'] is List) {
              final thumbnails =
                  videoDetails['thumbnail']['thumbnails'] as List;

              for (final thumbnail in thumbnails) {
                final width = thumbnail['width'] ?? 0;
                final url = thumbnail['url'];

                if (url != null && url is String) {
                  if (width <= 120) {
                    thumbnailLow = url;
                  } else if (width <= 480) {
                    thumbnailMedium = url;
                  }
                }
              }
            }

            // Extract publish date if available
            String publishDate = '';
            if (data['microformat'] != null &&
                data['microformat']['playerMicroformatRenderer'] != null) {
              publishDate =
                  data['microformat']['playerMicroformatRenderer']['publishDate'] ??
                  '';
            }

            return YouTubeMetadata(
              videoId: videoId,
              title: videoDetails['title'] ?? 'YouTube Video',
              description: videoDetails['shortDescription'] ?? '',
              thumbnailLow: thumbnailLow,
              thumbnailMedium: thumbnailMedium,
              publishDate: publishDate,
              tags: tags,
            );
          }
        } catch (e) {
          print('Error parsing YouTube JSON data: $e');
        }
      }

      // If JSON extraction failed, try meta tags as fallback
      return _extractMetadataFromHtml(videoId, htmlContent);
    } catch (e) {
      print('Error fetching YouTube metadata: $e');
      return _createFallbackMetadata(videoId);
    }
  }

  /// Create minimal metadata with standard YouTube thumbnail URLs
  YouTubeMetadata _createFallbackMetadata(String videoId) {
    return YouTubeMetadata(
      videoId: videoId,
      title: 'YouTube Video',
      description: '',
      thumbnailLow: 'https://img.youtube.com/vi/$videoId/default.jpg', // 120x90
      thumbnailMedium:
          'https://img.youtube.com/vi/$videoId/mqdefault.jpg', // 320x180
      publishDate: '',
      tags: [],
    );
  }

  /// Extract metadata from HTML content when JSON extraction fails
  YouTubeMetadata? _extractMetadataFromHtml(
    String videoId,
    String htmlContent,
  ) {
    try {
      final document = html_parser.parse(htmlContent);

      // Extract title
      final title =
          _extractFromMeta(document, 'og:title') ??
          _extractFromMeta(document, 'title') ??
          'YouTube Video';

      // Extract description
      final description =
          _extractFromMeta(document, 'og:description') ??
          _extractFromMeta(document, 'description') ??
          '';

      // Extract tags
      List<String> tags = [];
      final metaTags = document.getElementsByTagName('meta');

      for (final tag in metaTags) {
        if (tag.attributes['property'] == 'og:video:tag' &&
            tag.attributes['content'] != null) {
          tags.add(tag.attributes['content']!);
        }
      }

      // Get keywords meta tag
      final keywords = _extractFromMeta(document, 'keywords');
      if (keywords != null) {
        final keywordsList = keywords.split(',').map((k) => k.trim()).toList();
        for (final keyword in keywordsList) {
          if (keyword.isNotEmpty && !tags.contains(keyword)) {
            tags.add(keyword);
          }
        }
      }

      return YouTubeMetadata(
        videoId: videoId,
        title: title,
        description: description,
        thumbnailLow: 'https://img.youtube.com/vi/$videoId/default.jpg',
        thumbnailMedium: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
        publishDate: '',
        tags: tags,
      );
    } catch (e) {
      print('Error extracting metadata from HTML: $e');
      return _createFallbackMetadata(videoId);
    }
  }

  /// REMOVED: Fetch transcript functionality
  /// Keeping method signature for backward compatibility but returns null
  Future<String?> fetchTranscript(String videoId) async {
    // Transcript functionality removed for performance
    print('Transcript functionality has been disabled for performance reasons');
    return null;
  }

  /// Extract content from meta tags in HTML
  String? _extractFromMeta(var document, String property) {
    final metaTags = document.getElementsByTagName('meta');
    for (var tag in metaTags) {
      if (tag.attributes['property'] == property ||
          tag.attributes['name'] == property) {
        return tag.attributes['content'];
      }
    }
    return null;
  }
}
