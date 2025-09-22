import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/youtube_metadata.dart';

/// A service for fetching and processing YouTube video metadata.
class YouTubeService {
  /// YouTube API key for using YouTube Data API v3
  final String? apiKey;

  /// Creates a new YouTubeService instance
  /// If no API key is provided, a default one will be used for testing purposes
  YouTubeService({String? apiKey})
    : apiKey = apiKey ?? const String.fromEnvironment('YT_API_KEY');

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
  /// Quality can be: 'low', 'medium', or 'high'
  /// Returns the local path to the saved thumbnail.
  Future<String?> fetchThumbnail(
    String videoId, {
    String quality = 'high',
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
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/mqdefault.jpg'; // 320x180
          break;
        case 'high':
        default:
          // Try maxresdefault first (1280x720 or higher)
          thumbnailUrl =
              'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
          final highResResponse = await http.get(Uri.parse(thumbnailUrl));

          // If maxres not available, fall back to hqdefault (480x360)
          if (highResResponse.statusCode != 200) {
            thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
            final fallbackResponse = await http.get(Uri.parse(thumbnailUrl));

            if (fallbackResponse.statusCode != 200) {
              print(
                'Failed to fetch high-quality thumbnail for video ID: $videoId',
              );
              // Last resort: try medium quality
              thumbnailUrl =
                  'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
              final lastResortResponse = await http.get(
                Uri.parse(thumbnailUrl),
              );

              if (lastResortResponse.statusCode != 200) {
                print('Failed to fetch any thumbnail for video ID: $videoId');
                return null;
              }

              return await _saveThumbnailToFile(
                videoId,
                lastResortResponse.bodyBytes,
                quality: quality,
              );
            }

            return await _saveThumbnailToFile(
              videoId,
              fallbackResponse.bodyBytes,
              quality: quality,
            );
          }

          return await _saveThumbnailToFile(
            videoId,
            highResResponse.bodyBytes,
            quality: quality,
          );
      }

      // For low and medium qualities, which don't need fallbacks
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
    String quality = 'high',
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

  /// Fetches complete metadata for a YouTube video by its URL using the YouTube Data API v3.
  /// Returns a YouTubeMetadata object containing all available metadata or null if unavailable.
  Future<YouTubeMetadata?> fetchMetadata(String url) async {
    final videoId = extractVideoId(url);
    if (videoId == null) {
      print('Could not extract video ID from URL: $url');
      return null;
    }

    // Use YouTube Data API v3 to fetch metadata
    try {
      // Log that we're about to fetch from the API
      print('Fetching YouTube metadata from API for video ID: $videoId');
      if (apiKey != null) {
        print(
          'Using API key: ${apiKey!.substring(0, 4)}...${apiKey!.substring(apiKey!.length - 4)}',
        );
      } else {
        print('Warning: No API key provided!');
      }

      final apiMetadata = await _fetchMetadataWithAPI(videoId);
      if (apiMetadata != null) {
        print('Successfully fetched YouTube metadata with API');
        print(
          'API returned: title="${apiMetadata.title}", author="${apiMetadata.author}"',
        );
        print(
          'Statistics: views=${apiMetadata.viewCount}, likes=${apiMetadata.likeCount}, comments=${apiMetadata.commentCount}',
        );
        return apiMetadata;
      }

      print('API returned null metadata for video ID: $videoId');
    } catch (e) {
      print('Error fetching YouTube metadata via API: $e');
    }

    // If API fails, log the error and return null (no more test data fallback)
    print('Failed to fetch metadata from API for video ID: $videoId');
    return null; // Don't use test data as fallback - better to fail clearly
  }

  // Methods for extracting metadata from HTML have been removed in favor of the API approach

  // Transcript functionality has been completely removed

  // Method for fetching basic title has been removed in favor of the API approach

  /// Fetch metadata with YouTube Data API v3
  /// https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id={videoId}&key={API_KEY}
  Future<YouTubeMetadata?> _fetchMetadataWithAPI(String videoId) async {
    if (apiKey == null || apiKey!.isEmpty) {
      print('YouTube API key not provided');
      return null;
    }

    try {
      final apiUrl =
          'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=$videoId&key=$apiKey';
      print(
        'Making API request to: ${apiUrl.replaceAll(apiKey!, 'API_KEY_HIDDEN')}',
      );

      final url = Uri.parse(apiUrl);
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Retainly App/1.0',
        },
      );

      print('API response received, status code: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('YouTube API error: ${response.statusCode}');
        print(
          'Error response: ${response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body}',
        );
        return null;
      }

      print(
        'API response received, content length: ${response.body.length} bytes',
      );
      final data = json.decode(response.body);

      if (data['items'] == null) {
        print('API response missing items field');
        return null;
      }

      final items = data['items'] as List;
      if (items.isEmpty) {
        print('No video data found for ID: $videoId');
        return null;
      }

      print('API returned ${items.length} items');
      final item = items[0];
      final snippet = item['snippet'];
      final contentDetails = item['contentDetails'];
      final statistics = item['statistics'];

      if (snippet == null) {
        print('No snippet data found for video ID: $videoId');
        return null;
      }

      print('Successfully parsed API response with snippet data');
      if (contentDetails == null) print('Warning: contentDetails is null');
      if (statistics == null) print('Warning: statistics is null');

      // Extract required fields
      final String title =
          snippet['localized']?['title'] ?? snippet['title'] ?? 'Unknown Title';
      final String description =
          snippet['localized']?['description'] ?? snippet['description'] ?? '';
      final String channelTitle = snippet['channelTitle'] ?? 'Unknown Channel';

      // Extract thumbnail URLs
      final thumbnails = snippet['thumbnails'] ?? {};
      final String thumbnailLow =
          thumbnails['default']?['url'] ??
          'https://img.youtube.com/vi/$videoId/default.jpg';
      final String thumbnailMedium =
          thumbnails['medium']?['url'] ??
          'https://img.youtube.com/vi/$videoId/mqdefault.jpg';

      // Try to get the highest quality thumbnail available (maxres > standard > high)
      String thumbnailHigh =
          thumbnails['maxres']?['url'] ??
          thumbnails['medium']?['url'] ??
          thumbnails['high']?['url'] ??
          'https://img.youtube.com/vi/$videoId/hqdefault.jpg';

      // Extract only actual tags provided by the API. Do not synthesize.
      List<String> tags = [];
      if (snippet['tags'] != null) {
        tags = List<String>.from(snippet['tags']);
      }

      // Parse publish date
      String publishDate = '';
      DateTime? publishedAt;
      if (snippet['publishedAt'] != null) {
        try {
          publishedAt = DateTime.parse(snippet['publishedAt']);
          publishDate =
              '${publishedAt.year}-${publishedAt.month.toString().padLeft(2, '0')}-${publishedAt.day.toString().padLeft(2, '0')}';
        } catch (e) {
          print('Error parsing publishedAt: $e');
        }
      }

      // Parse duration (ISO 8601 format: PT#M#S)
      String? duration;
      if (contentDetails != null && contentDetails['duration'] != null) {
        duration = _parseIsoDuration(contentDetails['duration']);
      }

      // Extract statistics
      int? viewCount, likeCount, commentCount, favoriteCount;
      if (statistics != null) {
        viewCount = int.tryParse(statistics['viewCount'] ?? '');
        likeCount = int.tryParse(statistics['likeCount'] ?? '');
        commentCount = int.tryParse(statistics['commentCount'] ?? '');
        favoriteCount = int.tryParse(statistics['favoriteCount'] ?? '');
      }

      return YouTubeMetadata(
        videoId: videoId,
        title: title,
        author: channelTitle,
        description: description,
        thumbnailLow: thumbnailLow,
        thumbnailMedium: thumbnailMedium,
        thumbnailHigh: thumbnailHigh,
        publishDate: publishDate,
        publishedAt: publishedAt,
        duration: duration,
        tags: tags,
        category: snippet['categoryId'],
        viewCount: viewCount,
        likeCount: likeCount,
        commentCount: commentCount,
        favoriteCount: favoriteCount,
        liveBroadcastContent: snippet['liveBroadcastContent'],
        channelId: snippet['channelId'],
        defaultLanguage: snippet['defaultLanguage'],
        defaultAudioLanguage: snippet['defaultAudioLanguage'],
        definition: contentDetails != null
            ? contentDetails['definition']
            : null,
        dimension: contentDetails != null ? contentDetails['dimension'] : null,
        projection: contentDetails != null
            ? contentDetails['projection']
            : null,
        caption: contentDetails != null
            ? (contentDetails['caption'] is bool
                  ? contentDetails['caption']
                  : contentDetails['caption']?.toString().toLowerCase() ==
                        'true')
            : null,
        licensedContent: contentDetails != null
            ? (contentDetails['licensedContent'] is bool
                  ? contentDetails['licensedContent']
                  : contentDetails['licensedContent']
                            ?.toString()
                            .toLowerCase() ==
                        'true')
            : null,
      );
    } catch (e) {
      print('Error fetching YouTube metadata via API: $e');
      return null;
    }
  }

  /// Parse ISO 8601 duration format (PT#M#S) into "minutes:seconds" format
  String _parseIsoDuration(String isoDuration) {
    // Handle simple case like "PT4M13S" (4 minutes and 13 seconds)
    RegExp regex = RegExp(r'PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?');
    Match? match = regex.firstMatch(isoDuration);

    if (match != null) {
      int hours = int.tryParse(match.group(1) ?? '0') ?? 0;
      int minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
      int seconds = int.tryParse(match.group(3) ?? '0') ?? 0;

      // Add hours to minutes if present
      minutes += hours * 60;

      // Format as "minutes:seconds"
      return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
    }

    return '0:00'; // Default if parsing fails
  }

  // Method for scraping YouTube page has been removed in favor of the API approach

  // Method for extracting from meta tags has been removed in favor of the API approach

  /// Extract hashtags from a description text
  /// Returns a list of tags without the # symbol
  List<String> _extractHashtagsFromDescription(String description) {
    if (description.isEmpty) return [];

    // Regular expression to find hashtags
    // Matches words that start with # and contain letters, numbers, or underscores
    // Also supports multi-language hashtags with Unicode characters
    // This handles hashtags at word boundaries and with various punctuation
    final hashtagRegex = RegExp(
      r'(?<=\s|^)#([\p{L}\p{N}_]+)(?=\s|$|[\.,;:!?\)])',
      unicode: true,
      multiLine: true,
    );
    final matches = hashtagRegex.allMatches(description);

    // Extract the tags without the # symbol
    final hashtags = matches
        .map((match) => match.group(1))
        .where((tag) => tag != null && tag.isNotEmpty)
        .map(
          (tag) => tag!.toLowerCase(),
        ) // Convert to lowercase for consistency
        .where(
          (tag) => tag.length >= 2 && !_isCommonStopWord(tag),
        ) // Only include tags with at least 2 characters and not stop words
        .toList();

    // Return unique tags only (no duplicates)
    return hashtags.toSet().toList();
  }

  /// Checks if a word is a common stop word that shouldn't be a hashtag
  bool _isCommonStopWord(String word) {
    const stopWords = {
      'the',
      'and',
      'for',
      'with',
      'this',
      'that',
      'from',
      'are',
      'was',
      'not',
      'but',
      'what',
      'all',
      'when',
      'can',
      'just',
      'like',
      'how',
    };
    return stopWords.contains(word.toLowerCase());
  }

  // Raw metadata method is kept for debugging purposes

  /// Generate test data for a video ID
  /// Use this method to test the UI when actual data retrieval fails
  YouTubeMetadata generateTestMetadata(String videoId) {
    // Example descriptions for different popular videos
    final Map<String, String> sampleDescriptions = {
      'dQw4w9WgXcQ':
          'Rick Astley - Never Gonna Give You Up (Official Music Video)\n\nListen On Spotify: http://smarturl.it/AstleySpotify\nLearn more about the brand new album \'Beautiful Life\': https://RickAstley.lnk.to/BeautifulLi...\n\nBuy On iTunes: http://smarturl.it/AstleyGHiTunes\nAmazon: http://smarturl.it/AstleyGHAmazon\n\nFollow Rick Astley\nWebsite: http://www.rickastley.co.uk/\nTwitter: https://twitter.com/rickastley\nFacebook: https://www.facebook.com/RickAstley/\nInstagram: https://www.instagram.com/officialric...',
      'jNQXAC9IVRw':
          'Me at the zoo\n\nThe first video on YouTube. Maybe it\'s time to go back to the zoo?\n\nNOTE FROM JAWED: I can\'t reply to all comments, but I do watch them! Let me know what you think about this video or YouTube. Thank you for watching!',
      'Jn09UdSb3aA':
          'BTS (방탄소년단) \'Dynamite\' Official MV\n\nCredits:\nDirector: Yong Seok Choi (Lumpens)\nAssistant Director: Jihye Yoon (Lumpens)\nDirector of Photography: Hyunwoo Nam (GDW)\nB Camera Operator: Eumko\nFocus Puller: Sangwoo Yoon, Youngwoo Lee\n2nd AC: Eunki Kim\n3rd AC: Kyuwon Seo\nDIT: Eunil Lee\nLighting Director: Samgyu Choi, Youngsuk Song\nGaffer: Choi Doo Soo\n',
      'AX6QTtG-Hq8':
          "Tame Impala - Borderline (Official Audio)\n\nTame Impala's 4th studio album 'The Slow Rush' is out now.\nListen to / order 'The Slow Rush' : https://TameImpala.lnk.to/TheSlowRush\n\nCome see Tame Impala on tour in 2022:\nEurope: https://tameimpa.la/tour\nNorth America: https://tameimpala.com/tour/\n\nVisit Tame Impala: https://tameimpala.com\nFollow Tame Impala:\nFacebook: https://tameimpala.lnk.to/Facebook\nInstagram: https://tameimpala.lnk.to/Instagram\nTwitter: https://tameimpala.lnk.to/Twitter\nSpotify: https://tameimpala.lnk.to/Spotify\nApple Music: https://tameimpala.lnk.to/AppleMusic\nYouTube: https://tameimpala.lnk.to/YouTube\n",
    };

    // Example tags for different popular videos
    final Map<String, List<String>> sampleTags = {
      'dQw4w9WgXcQ': [
        'Rick Astley',
        'Never Gonna Give You Up',
        'Pop',
        '80s',
        'Rickroll',
        'Music Video',
        'Classic',
      ],
      'jNQXAC9IVRw': [
        'First YouTube video',
        'zoo',
        'Jawed Karim',
        'elephants',
        'YouTube history',
        'San Diego Zoo',
      ],
      'Jn09UdSb3aA': [
        'BTS',
        'Dynamite',
        'K-pop',
        'Korean',
        'Music Video',
        'Dance',
        'Pop',
      ],
      'AX6QTtG-Hq8': [
        'Tame Impala',
        'Borderline',
        'Psychedelic',
        'Alternative',
        'Kevin Parker',
        'The Slow Rush',
      ],
    };

    // Default test data
    String description =
        'This is a sample description for testing the YouTube details screen. It is a longer text that should trigger the collapsible description feature when shown in the UI. The description includes details about the video content, links to related resources, and additional information provided by the video creator.';
    List<String> tags = [
      'Sample',
      'Test',
      'YouTube',
      'Video',
      'Metadata',
      'Flutter',
      'App Development',
      'Mobile',
    ];
    String title = 'Sample YouTube Video - For Testing Purposes';
    String author = 'Test Channel';

    // Use specific data if we have it for this video ID
    if (sampleDescriptions.containsKey(videoId)) {
      description = sampleDescriptions[videoId]!;
    }

    if (sampleTags.containsKey(videoId)) {
      tags = sampleTags[videoId]!;
    }

    // For specific popular videos, use more accurate info
    switch (videoId) {
      case 'dQw4w9WgXcQ': // Rick Astley - Never Gonna Give You Up
        title = 'Rick Astley - Never Gonna Give You Up (Official Music Video)';
        author = 'Rick Astley';
        break;
      case 'jNQXAC9IVRw': // First YouTube video
        title = 'Me at the zoo';
        author = 'jawed';
        break;
      case 'Jn09UdSb3aA': // BTS Dynamite
        title = 'BTS (방탄소년단) \'Dynamite\' Official MV';
        author = 'HYBE LABELS';
        break;
      case 'AX6QTtG-Hq8': // Tame Impala - Borderline
        title = 'Tame Impala - Borderline (Official Audio)';
        author = 'Tame Impala';
        break;
      case 'fK-yKM-RlSs': // Turkish song
        title = 'Ali Kınık - Gözlerin Duman Duman (Official Video)';
        author = 'Ali Kınık';
        break;
    }

    // Extract hashtags from description and add to tags
    final hashtagsFromDescription = _extractHashtagsFromDescription(
      description,
    );
    if (hashtagsFromDescription.isNotEmpty) {
      tags.addAll(hashtagsFromDescription);
    }

    // Add author as a tag
    if (author != 'Test Channel') {
      tags.add(author);
    }

    return YouTubeMetadata(
      videoId: videoId,
      title: title,
      author: author,
      description: description,
      thumbnailLow: 'https://img.youtube.com/vi/$videoId/default.jpg',
      thumbnailMedium: 'https://img.youtube.com/vi/$videoId/mqdefault.jpg',
      thumbnailHigh: 'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
      publishDate: '2023-09-21',
      category: 'Entertainment',
      tags: tags.toSet().toList(), // Remove any duplicates
    );
  }

  // All transcript-related methods have been removed for performance optimization

  /// Debug method to get raw metadata from YouTube API
  /// This is used by the YouTube Data Viewer for debugging purposes
  /// Accepts either a videoId or a full YouTube URL
  Future<Map<String, dynamic>> getRawMetadata(String input) async {
    // Determine if input is a videoId or a URL
    String videoId = input;
    if (input.contains('youtube.com') || input.contains('youtu.be')) {
      final extractedId = extractVideoId(input);
      if (extractedId == null) {
        print('Could not extract video ID from URL: $input');
        return {
          'error': 'Could not extract video ID from URL: $input',
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
      videoId = extractedId;
    }

    try {
      final effectiveApiKey = apiKey ?? '';
      if (effectiveApiKey.isEmpty) {
        print('Error: No YouTube API key provided');
        return {
          'error': 'No YouTube API key provided',
          'videoId': videoId,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }

      print('Fetching raw metadata for video ID: $videoId');
      if (effectiveApiKey.length > 8) {
        print(
          'Using API key: ${effectiveApiKey.substring(0, 4)}...${effectiveApiKey.substring(effectiveApiKey.length - 4)}',
        );
      }

      final apiUrl =
          'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails,statistics&id=$videoId&key=$effectiveApiKey';
      print(
        'Making API request to: ${apiUrl.replaceAll(effectiveApiKey, 'API_KEY_HIDDEN')}',
      );

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'Retainly App/1.0',
        },
      );

      print('API response received with status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('API request successful, parsing JSON response');
        final jsonResponse = jsonDecode(response.body);

        // Check if we have items in the response
        if (jsonResponse['items'] == null) {
          print('API response missing items field');
          return {
            'error': 'API response missing items field',
            'videoId': videoId,
            'timestamp': DateTime.now().toIso8601String(),
            'statusCode': response.statusCode,
            'responseLength': response.body.length,
          };
        }

        final items = jsonResponse['items'] as List;
        if (items.isEmpty) {
          print('No video data found for ID: $videoId');
          return {
            'error': 'No video data found for this ID',
            'videoId': videoId,
            'timestamp': DateTime.now().toIso8601String(),
            'itemsCount': 0,
          };
        }

        print('API returned ${items.length} items for video ID: $videoId');

        // Extract hashtags from description if available
        final snippet = jsonResponse['items'][0]['snippet'];
        if (snippet != null && snippet['description'] != null) {
          final description = snippet['description'];
          final hashtags = _extractHashtagsFromDescription(description);

          // Add extracted hashtags to the response for debugging
          jsonResponse['_extractedHashtags'] = hashtags;
          print('Extracted ${hashtags.length} hashtags from description');
        } else {
          print('No snippet or description found in API response');
        }

        // Add our own timestamp and metadata for tracking
        jsonResponse['_processedAt'] = DateTime.now().toIso8601String();
        jsonResponse['_videoId'] = videoId;
        jsonResponse['_source'] = 'YouTube API v3';

        return jsonResponse;
      } else {
        print('Failed to fetch data from YouTube API: ${response.statusCode}');
        print(
          'Error response: ${response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body}',
        );

        // Return an error response
        return {
          'error': 'Failed to fetch from API: ${response.statusCode}',
          'videoId': videoId,
          'timestamp': DateTime.now().toIso8601String(),
          'statusCode': response.statusCode,
          'errorResponse': response.body.length > 500
              ? "${response.body.substring(0, 500)}..."
              : response.body,
        };
      }
    } catch (e) {
      print('Exception in getRawMetadata: $e');
      return {
        'testMetadata': true,
        'videoId': videoId,
        'error': 'Exception fetching data: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}
