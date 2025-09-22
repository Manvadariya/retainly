import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/youtube_metadata.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.metadata.title.length > 30
              ? '${widget.metadata.title.substring(0, 30)}...'
              : widget.metadata.title,
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

            // Tags section - only show if we have tags
            if (widget.metadata.tags.isNotEmpty)
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

            // Statistics section
            Card(
              color: theme.colorScheme.surfaceVariant,
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildStatisticsSection(),
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
    final thumbnailUrl =
        widget.metadata.thumbnailHigh ?? widget.metadata.thumbnailMedium;

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
          widget.metadata.title,
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
                widget.metadata.author ?? 'Unknown Creator',
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

        if (widget.metadata.category != null &&
            widget.metadata.category!.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.category, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.metadata.category!,
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
        if (widget.metadata.publishDate.isNotEmpty) ...[
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(
                _formatPublishDate(widget.metadata.publishDate),
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
    final desc = widget.metadata.description;
    final theme = Theme.of(context);

    print(
      'Building description section with description length: ${desc.length}',
    );

    // Get creator/channel name for display
    final String creatorName = widget.metadata.author ?? 'Unknown Creator';
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
          Text(
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
    final List<String> allTags = List.from(
      widget.metadata.tags,
    ); // Create a mutable copy

    // Extract hashtags from description if we have fewer than 3 tags from the API
    if ((allTags.isEmpty || allTags.length < 3) &&
        widget.metadata.description.isNotEmpty) {
      // Extract hashtags from the description as a fallback or supplement
      final regex = RegExp(
        r'(?<=\s|^)#([\p{L}\p{N}_]+)(?=\s|$|[\.,;:!?\)])',
        unicode: true,
        multiLine: true,
      );

      final matches = regex.allMatches(widget.metadata.description);
      final extractedTags = matches
          .map((match) => '#${match.group(1)}')
          .where((tag) => tag != null)
          .toSet()
          .toList();

      // Add extracted tags if any found
      if (extractedTags.isNotEmpty) {
        print('Extracted ${extractedTags.length} hashtags from description');
        allTags.addAll(extractedTags);
      }

      // Additionally try to extract common keywords from the title
      if (allTags.isEmpty) {
        final titleWords = widget.metadata.title
            .split(' ')
            .where((word) => word.length > 3)
            .toList();
        if (titleWords.isNotEmpty) {
          print('Using ${titleWords.length} keywords from title as tags');
          allTags.addAll(titleWords.take(5));
        }
      }
    }

    if (allTags.isEmpty) {
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
          Text(
            'No tags found for this video',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

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

  /// Build statistics section with view count, likes, and comments
  Widget _buildStatisticsSection() {
    final theme = Theme.of(context);

    // Check if we have any actual statistics from the API
    var hasRealStats = false;
    var hasAnyInfo = false;

    // Check for view stats
    if (widget.metadata.viewCount != null) {
      hasRealStats = true;
      hasAnyInfo = true;
      print('Has view count: ${widget.metadata.viewCount}');
    }

    // Check for engagement stats
    if (widget.metadata.likeCount != null) {
      hasRealStats = true;
      hasAnyInfo = true;
      print('Has like count: ${widget.metadata.likeCount}');
    }

    if (widget.metadata.commentCount != null) {
      hasRealStats = true;
      hasAnyInfo = true;
      print('Has comment count: ${widget.metadata.commentCount}');
    }

    // Check for video metadata
    if (widget.metadata.duration != null &&
        widget.metadata.duration!.isNotEmpty) {
      hasAnyInfo = true;
      print('Has duration: ${widget.metadata.duration}');
    }

    // Check publish date info
    var hasPublishDate = false;
    String publishDateFormatted = '';
    if (widget.metadata.publishedAt != null) {
      hasAnyInfo = true;
      hasPublishDate = true;
      final date = widget.metadata.publishedAt!;
      publishDateFormatted =
          '${_getMonthName(date.month)} ${date.day}, ${date.year}';
      print(
        'Has publishedAt: ${widget.metadata.publishedAt} -> $publishDateFormatted',
      );
    } else if (widget.metadata.publishDate.isNotEmpty) {
      hasAnyInfo = true;
      hasPublishDate = true;
      publishDateFormatted = _formatPublishDate(widget.metadata.publishDate);
      print(
        'Has publishDate: ${widget.metadata.publishDate} -> $publishDateFormatted',
      );
    }

    print(
      'Building statistics section, hasRealStats: $hasRealStats, hasAnyInfo: $hasAnyInfo',
    );

    // If we have no statistics at all
    if (!hasAnyInfo) {
      // Create a generic section with video type information at minimum
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video Information',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildStatItem(
            Icons.video_library,
            'YouTube Video',
            'Type',
            Colors.red,
          ),
          const SizedBox(height: 8),
          _buildStatItem(
            Icons.event,
            DateTime.now().year
                .toString(), // Just show the current year as fallback
            'Year',
            Colors.blue,
          ),
        ],
      );
    }

    // For videos with actual information
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // Use a grid layout for the statistics
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            if (widget.metadata.viewCount != null)
              _buildStatItem(
                Icons.visibility,
                _formatNumber(widget.metadata.viewCount!),
                'Views',
                theme.colorScheme.primary,
              ),

            if (widget.metadata.likeCount != null)
              _buildStatItem(
                Icons.thumb_up,
                _formatNumber(widget.metadata.likeCount!),
                'Likes',
                Colors.red,
              ),

            if (widget.metadata.commentCount != null)
              _buildStatItem(
                Icons.comment,
                _formatNumber(widget.metadata.commentCount!),
                'Comments',
                Colors.blue,
              ),

            if (widget.metadata.duration != null)
              _buildStatItem(
                Icons.timer,
                widget.metadata.duration!,
                'Duration',
                Colors.amber,
              ),

            if (hasPublishDate)
              _buildStatItem(
                Icons.event,
                publishDateFormatted,
                'Published',
                Colors.green,
              ),
          ],
        ),
      ],
    );
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
                widget.metadata.videoId,
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
            Clipboard.setData(ClipboardData(text: widget.metadata.videoId));
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
    final youtubeUrl =
        'https://www.youtube.com/watch?v=${widget.metadata.videoId}';
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
    final youtubeUrl =
        'https://www.youtube.com/watch?v=${widget.metadata.videoId}';
    try {
      await Share.share(
        'Check out this YouTube video: ${widget.metadata.title}\n$youtubeUrl',
        subject: widget.metadata.title,
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
