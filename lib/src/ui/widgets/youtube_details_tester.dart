import 'package:flutter/material.dart';
import '../../services/new_youtube_service.dart';
import '../../models/youtube_metadata.dart';
import '../screens/youtube_details_screen.dart';

/// A widget for testing the YouTube details screen with different URLs
class YouTubeDetailsTester extends StatefulWidget {
  const YouTubeDetailsTester({super.key});

  @override
  State<YouTubeDetailsTester> createState() => _YouTubeDetailsTesterState();
}

class _YouTubeDetailsTesterState extends State<YouTubeDetailsTester> {
  final TextEditingController _urlController = TextEditingController();
  // Using the default API key from the service constructor
  final YouTubeService _youtubeService = YouTubeService();

  bool _isLoading = false;
  String? _errorMessage;
  YouTubeMetadata? _metadata;

  // Some sample YouTube URLs for testing
  final List<String> _sampleUrls = [
    'https://www.youtube.com/watch?v=dQw4w9WgXcQ', // Rick Astley - Never Gonna Give You Up
    'https://www.youtube.com/watch?v=jNQXAC9IVRw', // First YouTube video
    'https://www.youtube.com/watch?v=Jn09UdSb3aA', // BTS Dynamite
    'https://youtu.be/AX6QTtG-Hq8', // Tame Impala - Borderline
    'https://www.youtube.com/watch?v=fK-yKM-RlSs', // Popular Turkish video
  ];

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchMetadata(String url) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _metadata = null;
    });

    try {
      final metadata = await _youtubeService.fetchMetadata(url);

      // Debug the metadata for testing
      if (metadata != null) {
        print('Successfully fetched metadata for: $url');
        print('Title: ${metadata.title}');
        print('Description length: ${metadata.description.length}');
        print('Tags count: ${metadata.tags.length}');
        print('Has view count: ${metadata.viewCount != null}');
        print('Has like count: ${metadata.likeCount != null}');
        print('Has comment count: ${metadata.commentCount != null}');
        print('Has publish date: ${metadata.publishDate.isNotEmpty}');
      } else {
        print('Failed to fetch metadata for: $url');
      }

      setState(() {
        _isLoading = false;
        _metadata = metadata;

        if (metadata == null) {
          _errorMessage = 'Failed to fetch metadata for this URL';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _viewDetails() {
    if (_metadata != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => YouTubeDetailsScreen(metadata: _metadata!),
        ),
      );
    }
  }

  void _selectSampleUrl(String url) {
    _urlController.text = url;
    _fetchMetadata(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube Details Tester')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a YouTube URL to test:',
              style: theme.textTheme.titleMedium,
            ),
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
                      : () => _fetchMetadata(_urlController.text),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Fetch'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sample URLs:', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sampleUrls.map((url) {
                final videoId =
                    _youtubeService.extractVideoId(url) ?? 'unknown';
                return ActionChip(
                  label: Text('Sample: $videoId'),
                  onPressed: () => _selectSampleUrl(url),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              const Center(child: CircularProgressIndicator()),
            ] else if (_errorMessage != null) ...[
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ),
              ),
            ] else if (_metadata != null) ...[
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Metadata Found!',
                          style: theme.textTheme.titleLarge,
                        ),
                        const Divider(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  title: const Text('Title'),
                                  subtitle: Text(_metadata!.title),
                                ),
                                ListTile(
                                  title: const Text('Video ID'),
                                  subtitle: Text(_metadata!.videoId),
                                ),
                                ListTile(
                                  title: const Text('Author'),
                                  subtitle: Text(
                                    _metadata!.author ?? 'Not available',
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Description'),
                                  subtitle: Text(
                                    _metadata!.description.isEmpty
                                        ? 'No description'
                                        : '${_metadata!.description.length} chars available',
                                  ),
                                ),
                                ListTile(
                                  title: const Text('Tags'),
                                  subtitle: Text(
                                    '${_metadata!.tags.length} tags available',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Center(
                                  child: ElevatedButton.icon(
                                    onPressed: _viewDetails,
                                    icon: const Icon(Icons.visibility),
                                    label: const Text('View Details Screen'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Center(child: Text('Enter a YouTube URL and press Fetch')),
            ],
          ],
        ),
      ),
    );
  }
}
