import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/youtube_metadata.dart';
import '../../services/youtube_service_exports.dart';
import '../../data/repository/card_repository.dart';

/// A screen that displays detailed information about a YouTube video
/// from its metadata.
class YouTubeDetailsScreen extends StatefulWidget {
  /// The YouTube metadata to display
  final YouTubeMetadata metadata;

  const YouTubeDetailsScreen({super.key, required this.metadata});

  @override
  State<YouTubeDetailsScreen> createState() => _YouTubeDetailsScreenState();
}

class _YouTubeDetailsScreenState extends State<YouTubeDetailsScreen> {
  bool _expandedDescription = false;
  late YouTubeMetadata _metadata;
  bool _isAutoFetching = false;

  @override
  void initState() {
    super.initState();
    _metadata = widget.metadata;
    _maybeFetchFreshMetadata();
  }

  bool _needsRefresh(YouTubeMetadata m) {
    return (m.author == null || m.author!.trim().isEmpty) ||
        m.description.trim().isEmpty ||
        m.tags.isEmpty ||
        m.viewCount == null ||
        m.duration == null ||
        m.publishedAt == null;
  }

  Future<void> _maybeFetchFreshMetadata() async {
    if (!_needsRefresh(_metadata)) return;
    setState(() => _isAutoFetching = true);
    try {
      final svc = YouTubeService();
      final url = 'https://www.youtube.com/watch?v=${_metadata.videoId}';
      final fresh = await svc.fetchMetadata(url);
      if (fresh != null) {
        setState(() {
          _metadata = fresh;
          _isAutoFetching = false;
        });

        // Persist refreshed metadata to database for offline availability
        try {
          final repo = CardRepository();
          await repo.updateYouTubeMetadataByVideoId(
            fresh.videoId,
            fresh.toJson(),
          );
        } catch (e) {
          // Non-fatal: UI already updated; DB sync failed silently
          // Keep quiet in UI; log for debug only
          // ignore: avoid_print
          print(
            'YouTubeDetailsScreen: Failed to persist refreshed metadata: $e',
          );
        }
      } else {
        setState(() => _isAutoFetching = false);
      }
    } catch (_) {
      setState(() => _isAutoFetching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _metadata.title.length > 30
              ? '${_metadata.title.substring(0, 30)}...'
              : _metadata.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Icon(Icons.play_circle_filled, color: Colors.red),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareVideo,
            tooltip: 'Share',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Thumbnail section
            _buildThumbnailSection(),

            const SizedBox(height: 16),

            // Title and channel section
            Card(
              color: theme.colorScheme.surfaceVariant,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildTitleSection(),
              ),
            ),

            const Divider(),

            // Tags section - only show actual API tags
            if (_metadata.tags.isNotEmpty)
              Card(
                color: theme.colorScheme.surfaceVariant,
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildTagsSection(),
                ),
              ),

            const Divider(),

            // Description section
            Card(
              color: theme.colorScheme.surfaceVariant,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDescriptionSection(),
              ),
            ),

            const Divider(),

            // View more section for optional details
            Card(
              color: theme.colorScheme.surfaceVariant,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                title: const Text('View more'),
                children: [_buildOptionalDetails()],
              ),
            ),

            const Divider(),

            // Video ID and YouTube button section
            Card(
              color: theme.colorScheme.surfaceVariant,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVideoIdSection(),
                    const SizedBox(height: 16),
                    _buildOpenInYouTubeButton(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24), // Bottom padding
          ],
        ),
      ),
    );
  }

  /// Builds the thumbnail section with a 16:9 aspect ratio
  Widget _buildThumbnailSection() {
    // Use the highest quality thumbnail available
    // The API now provides high resolution thumbnails (maxresdefault.jpg)
    final thumbnailUrl = _metadata.thumbnailHigh ?? _metadata.thumbnailMedium;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: thumbnailUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[300], child: const Icon(Icons.error)),
      ),
    );
  }

  /// Builds the title section with title, author and metadata
  Widget _buildTitleSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          _metadata.title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 16),

        // Additional metadata
        // Always show author with enhanced visibility
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _metadata.author ?? 'Unknown Creator',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        if (_metadata.category != null && _metadata.category!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.category, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _metadata.category!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        if (_metadata.publishDate.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(
                _formatPublishDate(_metadata.publishDate),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the expandable description section
  Widget _buildDescriptionSection() {
    final desc = _metadata.description;
    final theme = Theme.of(context);

    print(
      'Building description section with description length: ${desc.length}',
    );

    // Get creator/channel name for display
    final String creatorName = _metadata.author ?? 'Unknown Creator';
    print('Creator name for display: $creatorName');

    // Always show a header with channel name for better information display
    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Always show the creator name with a special icon
        Row(
          children: [
            Icon(Icons.person, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              creatorName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );

    // If there's no description
    if (desc.isEmpty || desc.trim().isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headerContent,
          _isAutoFetching
              ? Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Fetching details…',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                )
              : Text(
                  'No description provided by creator',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ],
      );
    }

    // If we have a description, show it with the header
    final bool isLong = desc.length > 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerContent,
        if (isLong && !_expandedDescription)
          Text(
            '${desc.substring(0, 200)}...',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          )
        else
          Text(desc, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
        if (isLong)
          TextButton(
            onPressed: () =>
                setState(() => _expandedDescription = !_expandedDescription),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_expandedDescription ? 'Show less' : 'Show more'),
                const SizedBox(width: 4),
                Icon(
                  _expandedDescription
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the tags section as chips
  Widget _buildTagsSection() {
    final theme = Theme.of(context);
    // Use only actual tags returned by YouTube API (snippet.tags)
    final List<String> allTags = List.from(_metadata.tags);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tags',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: allTags.take(10).map((tag) {
            // Strip hashtag if present to avoid double hashtags
            final displayTag = tag.startsWith('#') ? tag : '#$tag';
            return Chip(
              backgroundColor: theme.colorScheme.primaryContainer,
              label: Text(
                displayTag,
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: 12,
                ),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Build the optional details content for the expansion tile
  Widget _buildOptionalDetails() {
    final theme = Theme.of(context);
    final List<Widget> rows = [];

    if (_metadata.viewCount != null) {
      rows.add(
        _buildStatItem(
          Icons.visibility,
          _formatNumber(_metadata.viewCount!),
          'Views',
          theme.colorScheme.primary,
        ),
      );
    }

    if (_metadata.likeCount != null) {
      rows.add(
        _buildStatItem(
          Icons.thumb_up,
          _formatNumber(_metadata.likeCount!),
          'Likes',
          Colors.red,
        ),
      );
    }

    if (_metadata.commentCount != null) {
      rows.add(
        _buildStatItem(
          Icons.comment,
          _formatNumber(_metadata.commentCount!),
          'Comments',
          Colors.blue,
        ),
      );
    }

    if (_metadata.favoriteCount != null) {
      rows.add(
        _buildStatItem(
          Icons.favorite,
          _formatNumber(_metadata.favoriteCount!),
          'Favorites',
          Colors.pink,
        ),
      );
    }

    if (_metadata.duration != null && _metadata.duration!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.timer,
          _metadata.duration!,
          'Duration',
          Colors.amber,
        ),
      );
    }

    if (_metadata.category != null && _metadata.category!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.category,
          _metadata.category!,
          'Category',
          Colors.purple,
        ),
      );
    }

    if (_metadata.publishedAt != null) {
      final date = _metadata.publishedAt!;
      rows.add(
        _buildStatItem(
          Icons.event,
          '${_getMonthName(date.month)} ${date.day}, ${date.year}',
          'Published',
          Colors.green,
        ),
      );
    } else if (_metadata.publishDate.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.event,
          _formatPublishDate(_metadata.publishDate),
          'Published',
          Colors.green,
        ),
      );
    }

    if (_metadata.channelId != null && _metadata.channelId!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.tag,
          _metadata.channelId!,
          'Channel ID',
          theme.colorScheme.tertiary,
        ),
      );
    }

    if (_metadata.defaultLanguage != null &&
        _metadata.defaultLanguage!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.language,
          _metadata.defaultLanguage!,
          'Default Language',
          theme.colorScheme.primary,
        ),
      );
    }

    if (_metadata.defaultAudioLanguage != null &&
        _metadata.defaultAudioLanguage!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.hearing,
          _metadata.defaultAudioLanguage!,
          'Audio Language',
          theme.colorScheme.primary,
        ),
      );
    }

    if (_metadata.definition != null && _metadata.definition!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.high_quality,
          _metadata.definition!,
          'Definition',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (_metadata.dimension != null && _metadata.dimension!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.view_in_ar,
          _metadata.dimension!,
          'Dimension',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (_metadata.projection != null && _metadata.projection!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.panorama_horizontal,
          _metadata.projection!,
          'Projection',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (_metadata.liveBroadcastContent != null &&
        _metadata.liveBroadcastContent!.isNotEmpty) {
      rows.add(
        _buildStatItem(
          Icons.podcasts,
          _metadata.liveBroadcastContent!,
          'Live Status',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (_metadata.caption != null) {
      rows.add(
        _buildStatItem(
          Icons.closed_caption,
          _metadata.caption! ? 'Yes' : 'No',
          'Captions',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (_metadata.licensedContent != null) {
      rows.add(
        _buildStatItem(
          Icons.verified,
          _metadata.licensedContent! ? 'Licensed' : 'Unlicensed',
          'Content License',
          theme.colorScheme.secondary,
        ),
      );
    }

    if (rows.isEmpty) {
      return Text(
        'No additional details',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.7),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Wrap(spacing: 16, runSpacing: 12, children: rows);
  }

  /// Build a statistics item with icon and text
  Widget _buildStatItem(
    IconData icon,
    String value,
    String label, [
    Color? iconColor,
  ]) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the video ID section with copy button
  Widget _buildVideoIdSection() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Video ID',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _metadata.videoId,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: _metadata.videoId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video ID copied to clipboard'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          tooltip: 'Copy Video ID',
        ),
      ],
    );
  }

  /// Build the "Open in YouTube" button
  Widget _buildOpenInYouTubeButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      onPressed: _openInYouTube,
      icon: const Icon(Icons.ondemand_video),
      label: const Text('Open in YouTube'),
    );
  }

  /// Format a large number with K, M, B suffixes
  String _formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return '${(number / 1000).toStringAsFixed(1)}K';
    if (number < 1000000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    return '${(number / 1000000000).toStringAsFixed(1)}B';
  }

  /// Format the publish date in a readable format
  String _formatPublishDate(String publishDate) {
    if (publishDate.isEmpty) return '';

    // First try parsing ISO 8601 format (2023-01-20T15:30:00Z)
    try {
      final date = DateTime.parse(publishDate);
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      // Try other formats if ISO parsing fails

      // Try "Jan 20, 2023" format
      final monthDayYearRegex = RegExp(r'([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})');
      final monthDayYearMatch = monthDayYearRegex.firstMatch(publishDate);
      if (monthDayYearMatch != null) {
        return publishDate; // Already in our desired format
      }

      // Try "2023-01-20" format
      final dateRegex = RegExp(r'(\d{4})-(\d{2})-(\d{2})');
      final dateMatch = dateRegex.firstMatch(publishDate);
      if (dateMatch != null) {
        try {
          final year = int.parse(dateMatch.group(1)!);
          final month = int.parse(dateMatch.group(2)!);
          final day = int.parse(dateMatch.group(3)!);
          final date = DateTime(year, month, day);
          return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
        } catch (_) {
          // Fall back to original
        }
      }
      return publishDate; // Return original if all parsing fails
    }
  }

  /// Convert month number to name
  String _getMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return monthNames[month - 1];
  }

  /// Open the YouTube video in the YouTube app or browser
  Future<void> _openInYouTube() async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=${_metadata.videoId}';
    try {
      await launchUrl(Uri.parse(youtubeUrl));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open YouTube: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Share the YouTube video link
  Future<void> _shareVideo() async {
    final youtubeUrl = 'https://www.youtube.com/watch?v=${_metadata.videoId}';
    try {
      await Share.share(
        'Check out this YouTube video: ${_metadata.title}\n$youtubeUrl',
        subject: _metadata.title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
