/// Model class for storing YouTube video metadata.
/// Contains essential metadata from YouTube Data API v3.
class YouTubeMetadata {
  /// The YouTube video ID.
  final String videoId;

  /// The title of the video.
  final String title;

  /// The description of the video.
  final String description;

  /// The URL of the lowest resolution thumbnail (120x90) for card/grid view.
  final String thumbnailLow;

  /// The URL of the medium resolution thumbnail (320x180) for details screen.
  final String thumbnailMedium;

  /// The URL of the high resolution thumbnail (480x360 or higher).
  final String? thumbnailHigh;

  /// The publish date of the video as a string.
  /// Use publishedAt for DateTime object.
  final String publishDate;

  /// The publish date of the video as DateTime.
  final DateTime? publishedAt;

  /// Duration of the video in "minutes:seconds" format
  final String? duration;

  /// Tags associated with the video.
  final List<String> tags;

  /// Author or channel name (referred to as channelTitle in YouTube API).
  final String? author;

  /// Video category.
  final String? category;

  /// View count from YouTube statistics
  final int? viewCount;

  /// Like count from YouTube statistics
  final int? likeCount;

  /// Comment count from YouTube statistics
  final int? commentCount;

  /// Favorite count from YouTube statistics (may be deprecated)
  final int? favoriteCount;

  /// Live broadcast content status (e.g., none, upcoming, live)
  final String? liveBroadcastContent;

  /// Channel ID that owns the video
  final String? channelId;

  /// Default language for the metadata
  final String? defaultLanguage;

  /// Default audio language
  final String? defaultAudioLanguage;

  /// Video definition (e.g., sd, hd)
  final String? definition;

  /// Video dimension (e.g., 2d, 3d)
  final String? dimension;

  /// Projection type (e.g., rectangular)
  final String? projection;

  /// Whether captions are available
  final bool? caption;

  /// Whether the content is licensed
  final bool? licensedContent;

  /// Constructs a YouTubeMetadata instance with required fields.
  YouTubeMetadata({
    required this.videoId,
    required this.title,
    required this.description,
    required this.thumbnailLow,
    required this.thumbnailMedium,
    this.thumbnailHigh,
    required this.publishDate,
    required this.tags,
    this.author,
    this.category,
    this.publishedAt,
    this.duration,
    this.viewCount,
    this.likeCount,
    this.commentCount,
    this.favoriteCount,
    this.liveBroadcastContent,
    this.channelId,
    this.defaultLanguage,
    this.defaultAudioLanguage,
    this.definition,
    this.dimension,
    this.projection,
    this.caption,
    this.licensedContent,
  });

  /// Creates an instance from a JSON map with backward compatibility.
  factory YouTubeMetadata.fromJson(Map<String, dynamic> json) {
    DateTime? publishedAt;
    if (json['publishedAt'] != null) {
      try {
        publishedAt = DateTime.parse(json['publishedAt']);
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return YouTubeMetadata(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      thumbnailLow:
          json['thumbnailLow'] ??
          json['thumbnailUrl'] ??
          '', // Backward compatibility
      thumbnailMedium: json['thumbnailMedium'] ?? json['thumbnailUrl'] ?? '',
      thumbnailHigh: json['thumbnailHigh'],
      publishDate: json['publishDate'] ?? '',
      publishedAt: publishedAt,
      duration: json['duration'],
      tags: List<String>.from(json['tags'] ?? []),
      author: json['author'],
      category: json['category'],
      viewCount: json['viewCount'] != null
          ? int.tryParse(json['viewCount'].toString())
          : null,
      likeCount: json['likeCount'] != null
          ? int.tryParse(json['likeCount'].toString())
          : null,
      commentCount: json['commentCount'] != null
          ? int.tryParse(json['commentCount'].toString())
          : null,
      favoriteCount: json['favoriteCount'] != null
          ? int.tryParse(json['favoriteCount'].toString())
          : null,
      liveBroadcastContent: json['liveBroadcastContent'],
      channelId: json['channelId'],
      defaultLanguage: json['defaultLanguage'],
      defaultAudioLanguage: json['defaultAudioLanguage'],
      definition: json['definition'],
      dimension: json['dimension'],
      projection: json['projection'],
      caption: json['caption'] is bool
          ? json['caption']
          : (json['caption']?.toString().toLowerCase() == 'true'
                ? true
                : json['caption']?.toString().toLowerCase() == 'false'
                ? false
                : null),
      licensedContent: json['licensedContent'] is bool
          ? json['licensedContent']
          : (json['licensedContent']?.toString().toLowerCase() == 'true'
                ? true
                : json['licensedContent']?.toString().toLowerCase() == 'false'
                ? false
                : null),
    );
  }

  /// Converts this instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'description': description,
      'thumbnailLow': thumbnailLow,
      'thumbnailMedium': thumbnailMedium,
      'thumbnailHigh': thumbnailHigh,
      'publishDate': publishDate,
      'publishedAt': publishedAt?.toIso8601String(),
      'duration': duration,
      'tags': tags,
      'author': author,
      'category': category,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'liveBroadcastContent': liveBroadcastContent,
      'channelId': channelId,
      'defaultLanguage': defaultLanguage,
      'defaultAudioLanguage': defaultAudioLanguage,
      'definition': definition,
      'dimension': dimension,
      'projection': projection,
      'caption': caption,
      'licensedContent': licensedContent,
    };
  }

  @override
  String toString() {
    return 'YouTubeMetadata(videoId: $videoId, title: $title, '
        'author: $author, duration: $duration, '
        'views: ${viewCount ?? "unknown"}, tags: ${tags.length} tags, '
        'definition: $definition, dimension: $dimension)';
  }
}
