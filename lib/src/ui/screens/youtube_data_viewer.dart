import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../models/youtube_metadata.dart';
import '../../services/new_youtube_service.dart';

/// A screen to view raw YouTube data in JSON format
class YouTubeDataViewer extends StatefulWidget {
  const YouTubeDataViewer({super.key});

  @override
  State<YouTubeDataViewer> createState() => _YouTubeDataViewerState();
}

class _YouTubeDataViewerState extends State<YouTubeDataViewer> {
  final TextEditingController _urlController = TextEditingController();
  final YouTubeService _youtubeService =
      YouTubeService(); // Using the default API key from the service

  bool _isLoading = false;
  String? _errorMessage;

  // Raw data storage
  String? _rawApiJson;
  String? _rawScrapedJson;
  YouTubeMetadata? _resultMetadata;

  // Sample URLs for quick testing
  final List<String> _sampleUrls = [
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ', // Rick Astley
    'https://www.youtube.com/watch?v=jNQXAC9IVRw', // First YouTube video
    'https://youtu.be/AX6QTtG-Hq8', // Tame Impala
    'https://www.youtube.com/watch?v=fK-yKM-RlSs', // Popular Turkish video
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Fetch both API and processed data for the YouTube video
  Future<void> _fetchAllData(String url) async {
    if (url.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a YouTube URL';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _rawApiJson = null;
      _rawScrapedJson = null;
      _resultMetadata = null;
    });

    // Extract the video ID from the URL
    final videoId = _youtubeService.extractVideoId(url);
    print('Extracted video ID: $videoId from URL: $url');

    if (videoId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not extract a valid YouTube video ID from the URL';
      });
      return;
    }

    try {
      // Use service to fetch parsed metadata (single source of truth)
      final metadata = await _youtubeService.fetchMetadata(
        'https://www.youtube.com/watch?v=$videoId',
      );
      if (metadata == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No video data found for this ID';
        });
        return;
      }

      // Also fetch raw API JSON for the viewer tab
      final apiJson = await _fetchRawApiData(videoId);
      final processedJson = await _fetchRawScrapedData(videoId);

      // Update UI
      setState(() {
        _isLoading = false;
        _rawApiJson = apiJson;
        _rawScrapedJson = processedJson;
        _resultMetadata = metadata;
      });
    } catch (e) {
      print('Error in _fetchAllData: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching data: $e';
      });
    }
  }

  // Remove custom API item processing; rely on service only

  /// Fetch raw API data using the YouTubeService
  Future<String?> _fetchRawApiData(String videoId) async {
    try {
      // Use the debug method to get raw data from YouTube API v3
      final rawData = await _youtubeService.getRawMetadata(videoId);

      // For debugging
      print('Raw API response received: ${rawData.length} bytes');
      print('API response contains items: ${rawData.containsKey("items")}');
      if (rawData.containsKey("items")) {
        final items = rawData["items"] as List;
        print('Number of items: ${items.length}');
      }

      // Convert to pretty JSON
      return _prettyJson(rawData);
    } catch (e) {
      print('Error in _fetchRawApiData: $e');
      return '{"error": "Failed to fetch API data: $e"}';
    }
  }

  /// Extract hashtags from a description text
  /// Returns a list of tags without the # symbol
  List<String> _extractHashtagsFromDescription(String description) {
    if (description.isEmpty) return [];

    // Regular expression to find hashtags
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
        .map((tag) => tag!.toLowerCase())
        .where((tag) => tag.length >= 2 && !_isCommonStopWord(tag))
        .toList();

    return hashtags.toSet().toList(); // Return unique tags only
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

  /// Fetch processed metadata as JSON
  Future<String?> _fetchRawScrapedData(String videoId) async {
    try {
      // Note: We no longer use scraping, everything comes from the API
      // This method is kept for backward compatibility in the viewer

      // Get the processed metadata
      final response = await _youtubeService.fetchMetadata(
        'https://www.youtube.com/watch?v=$videoId',
      );

      if (response != null) {
        // Add diagnostic information
        final Map<String, dynamic> processedData = response.toJson();
        processedData['_diagnostic'] = {
          'videoId': videoId,
          'descriptionLength': response.description.length,
          'tagsCount': response.tags.length,
          'thumbnailAvailable': response.thumbnailMedium.isNotEmpty,
          'source': 'YouTube API (Processed)',
          'timestamp': DateTime.now().toIso8601String(),
          'note': 'Scraping has been replaced with YouTube API v3',
        };

        if (response.publishedAt != null) {
          processedData['_diagnostic']['publishedAt'] = response.publishedAt!
              .toIso8601String();
        }

        return _prettyJson(processedData);
      }

      return '{"error": "Failed to fetch processed metadata", "note": "Scraping has been replaced with YouTube API v3"}';
    } catch (e) {
      return '{"error": "Failed to fetch processed data: $e", "note": "Scraping has been replaced with YouTube API v3"}';
    }
  }

  /// Format JSON with indentation for readability
  String _prettyJson(Map<String, dynamic> json) {
    var encoder = const JsonEncoder.withIndent('  ');
    return encoder.convert(json);
  }

  /// Handle selecting a sample URL
  void _selectSampleUrl(String url) {
    _urlController.text = url;
    _fetchAllData(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Raw Data Viewer')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter a YouTube URL:', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'https://www.youtube.com/watch?v=...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () => _fetchAllData(_urlController.text),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Fetch Data'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sample URLs:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Add a direct test button for API
                ActionChip(
                  label: const Text('Test API'),
                  avatar: const Icon(Icons.api, size: 16),
                  onPressed: () {
                    _urlController.text =
                        'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
                    _fetchAllData(_urlController.text);
                  },
                ),
                // Sample URLs
                ..._sampleUrls.map((url) {
                  final videoId =
                      _youtubeService.extractVideoId(url) ?? 'unknown';
                  return ActionChip(
                    label: Text(videoId),
                    onPressed: () => _selectSampleUrl(url),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 16),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              )
            else if (_resultMetadata != null)
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TabBar(
                          tabs: const [
                            Tab(text: 'API Metadata'),
                            Tab(text: 'Raw JSON'),
                          ],
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: Processed metadata overview
                            _buildMetadataOverviewTab(context),

                            // Tab 2: Raw JSON data
                            _buildRawJsonTab(context),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Build the metadata overview tab
  Widget _buildMetadataOverviewTab(BuildContext context) {
    final theme = Theme.of(context);

    if (_resultMetadata == null) {
      return const Center(child: Text('No data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: ListTile(
              title: const Text('Video ID'),
              subtitle: Text(_resultMetadata!.videoId),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyToClipboard(_resultMetadata!.videoId),
                tooltip: 'Copy to clipboard',
              ),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Title'),
              subtitle: Text(_resultMetadata!.title),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Channel / Author'),
              subtitle: Text(_resultMetadata!.author ?? 'Not available'),
              trailing:
                  _resultMetadata!.author != null &&
                      _resultMetadata!.author != 'Unknown Channel'
                  ? Icon(Icons.check_circle, color: Colors.green)
                  : Icon(Icons.error_outline, color: Colors.orange),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Description'),
              subtitle: Text(
                _resultMetadata!.description.isEmpty
                    ? 'No description available'
                    : '${_resultMetadata!.description.substring(0, _resultMetadata!.description.length > 100 ? 100 : _resultMetadata!.description.length)}${_resultMetadata!.description.length > 100 ? '...' : ''}',
              ),
              trailing: Text('${_resultMetadata!.description.length} chars'),
              isThreeLine: true,
            ),
          ),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text('Tags'),
                  subtitle: Text(
                    '${_resultMetadata!.tags.length} tags available',
                  ),
                ),
                if (_resultMetadata!.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _resultMetadata!.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Thumbnail URL'),
              subtitle: Text(_resultMetadata!.thumbnailMedium),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () =>
                    _copyToClipboard(_resultMetadata!.thumbnailMedium),
                tooltip: 'Copy to clipboard',
              ),
            ),
          ),

          // Display statistics from YouTube API
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Text('Statistics'),
                  subtitle: const Text('YouTube API metrics'),
                  leading: const Icon(Icons.analytics),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: [
                      if (_resultMetadata!.viewCount != null)
                        _buildStatRow(
                          'Views',
                          _resultMetadata!.viewCount.toString(),
                          Icons.visibility,
                        ),
                      if (_resultMetadata!.likeCount != null)
                        _buildStatRow(
                          'Likes',
                          _resultMetadata!.likeCount.toString(),
                          Icons.thumb_up,
                        ),
                      if (_resultMetadata!.commentCount != null)
                        _buildStatRow(
                          'Comments',
                          _resultMetadata!.commentCount.toString(),
                          Icons.comment,
                        ),
                      if (_resultMetadata!.duration != null)
                        _buildStatRow(
                          'Duration',
                          _resultMetadata!.duration!,
                          Icons.timer,
                        ),
                      if (_resultMetadata!.publishedAt != null)
                        _buildStatRow(
                          'Published Date',
                          '${_resultMetadata!.publishedAt!.year}-${_resultMetadata!.publishedAt!.month.toString().padLeft(2, '0')}-${_resultMetadata!.publishedAt!.day.toString().padLeft(2, '0')}',
                          Icons.calendar_today,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the raw JSON data tab
  Widget _buildRawJsonTab(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            child: TabBar(
              tabs: const [
                Tab(text: 'YouTube API Data'),
                Tab(text: 'Processed Metadata'),
              ],
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              children: [
                // API JSON Data
                Card(
                  margin: EdgeInsets.zero,
                  child: _buildJsonView(
                    _rawApiJson ?? '{"error": "No API data available"}',
                    'Raw YouTube API v3 response data',
                  ),
                ),

                // Scraped JSON Data
                Card(
                  margin: EdgeInsets.zero,
                  child: _buildJsonView(
                    _rawScrapedJson ?? '{"error": "No scraped data available"}',
                    'Processed metadata from YouTube API',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a JSON viewer with copy button
  Widget _buildJsonView(String jsonText, String description) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header with copy button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  description,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _copyToClipboard(jsonText),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  foregroundColor: theme.colorScheme.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.format_align_left),
                tooltip: 'Format JSON',
                onPressed: () {},
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),

        // JSON content
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                jsonText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ),

        // Footer with info
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            'JSON length: ${jsonText.length} characters',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Copy text to clipboard with feedback
  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// Build a statistic row with label, value and icon
  Widget _buildStatRow(String label, String value, IconData icon) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
