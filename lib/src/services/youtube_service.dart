import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class YouTubeService {
  final String? apiKey;

  YouTubeService({this.apiKey});

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
  /// Returns the local path to the saved thumbnail.
  Future<String?> fetchThumbnail(String videoId) async {
    try {
      // Try the maxresdefault quality first (highest quality)
      String thumbnailUrl =
          'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

      final response = await http.get(Uri.parse(thumbnailUrl));

      // If maxres not available, try hqdefault
      if (response.statusCode != 200) {
        thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
        final fallbackResponse = await http.get(Uri.parse(thumbnailUrl));

        if (fallbackResponse.statusCode != 200) {
          print('Failed to fetch YouTube thumbnail for video ID: $videoId');
          return null;
        }

        return await _saveThumbnailToFile(videoId, fallbackResponse.bodyBytes);
      }

      return await _saveThumbnailToFile(videoId, response.bodyBytes);
    } catch (e) {
      print('Error fetching YouTube thumbnail: $e');
      return null;
    }
  }

  /// Save the thumbnail bytes to a local file and return the file path
  Future<String?> _saveThumbnailToFile(
    String videoId,
    List<int> imageBytes,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/${const Uuid().v4()}_$videoId.jpg';

      final File file = File(filePath);
      await file.writeAsBytes(imageBytes);

      print('Thumbnail saved to: $filePath');
      return filePath;
    } catch (e) {
      print('Error saving thumbnail to file: $e');
      return null;
    }
  }

  /// Attempts to fetch the transcript for a YouTube video.
  /// This tries multiple methods to maximize success, including auto-generated captions.
  Future<String?> fetchTranscript(String videoId) async {
    print('======= STARTING TRANSCRIPT FETCH FOR VIDEO ID: $videoId =======');

    // Try each method in order, with detailed logging

    // METHOD 1: Official API (if key available)
    if (apiKey != null) {
      try {
        print('Method 1: Trying YouTube Data API with key');
        final apiTranscript = await _fetchTranscriptWithAPI(videoId);
        if (apiTranscript != null && apiTranscript.isNotEmpty) {
          print(
            'SUCCESS: Got transcript via YouTube Data API (${apiTranscript.length} chars)',
          );
          return apiTranscript;
        } else {
          print('FAIL: YouTube Data API returned no transcript');
        }
      } catch (e) {
        print('ERROR: YouTube Data API fetch failed: $e');
      }
    } else {
      print('SKIP: No YouTube API key provided, skipping API method');
    }

    // METHOD 2: Timedtext API (most reliable for auto-generated captions)
    try {
      print('Method 2: Trying YouTube timedtext API (best for auto-generated)');
      final timedTextTranscript = await _fetchTranscriptFromTimedText(videoId);
      if (timedTextTranscript != null && timedTextTranscript.isNotEmpty) {
        print(
          'SUCCESS: Got transcript via timedtext API (${timedTextTranscript.length} chars)',
        );
        return timedTextTranscript;
      } else {
        print('FAIL: Timedtext API returned no transcript');
      }
    } catch (e) {
      print('ERROR: Timedtext API fetch failed: $e');
    }

    // METHOD 3: HTML parsing (direct page extraction)
    try {
      print('Method 3: Trying direct HTML page parsing');
      final htmlTranscript = await _fetchTranscriptWithoutAPI(videoId);
      if (htmlTranscript != null && htmlTranscript.isNotEmpty) {
        print(
          'SUCCESS: Got transcript via HTML parsing (${htmlTranscript.length} chars)',
        );
        return htmlTranscript;
      } else {
        print('FAIL: HTML parsing returned no transcript');
      }
    } catch (e) {
      print('ERROR: HTML parsing fetch failed: $e');
    }

    print(
      '======= ALL TRANSCRIPT FETCH METHODS FAILED FOR VIDEO ID: $videoId =======',
    );
    return null; // No transcript available
  }

  /// Attempts to fetch the transcript for a YouTube video using the YouTube Data API.
  /// This requires an API key to access the Captions API.
  Future<String?> _fetchTranscriptWithAPI(String videoId) async {
    if (apiKey == null) {
      print('YouTube API key not provided, cannot fetch transcript via API');
      return null;
    }

    try {
      // Step 1: Get caption tracks for the video
      final captionsUrl =
          'https://www.googleapis.com/youtube/v3/captions?videoId=$videoId&part=snippet&key=$apiKey';

      final response = await http.get(Uri.parse(captionsUrl));

      if (response.statusCode != 200) {
        print('Failed to fetch captions list: ${response.statusCode}');
        return null;
      }

      final captionsData = json.decode(response.body);

      if (captionsData['items'] == null || captionsData['items'].isEmpty) {
        print('No caption tracks found for video ID: $videoId');
        return null;
      }

      // Try to find English captions first
      var captionId = '';
      for (var item in captionsData['items']) {
        final language = item['snippet']['language'];
        if (language == 'en') {
          captionId = item['id'];
          break;
        }
      }
      // If no English captions, use the first one available
      if (captionId.isEmpty && captionsData['items'].isNotEmpty) {
        captionId = captionsData['items'][0]['id'];
      }

      if (captionId.isEmpty) {
        print('No usable caption track found for video ID: $videoId');
        return null;
      }

      // Step 2: Fetch the actual caption track content
      final captionDownloadUrl =
          'https://www.googleapis.com/youtube/v3/captions/$captionId?key=$apiKey';

      final captionResponse = await http.get(
        Uri.parse(captionDownloadUrl),
        headers: {'Accept': 'text/plain'},
      );

      if (captionResponse.statusCode != 200) {
        print('Failed to fetch caption track: ${captionResponse.statusCode}');
        return null;
      }

      // Parse the caption data
      String rawTranscript = utf8.decode(captionResponse.bodyBytes);

      // Basic processing to clean up the transcript
      String processedTranscript = _processRawTranscript(rawTranscript);

      return processedTranscript;
    } catch (e) {
      print('Error fetching YouTube transcript via API: $e');
      return null;
    }
  }

  /// Method to fetch transcript from YouTube's timedtext API
  /// This method specifically targets auto-generated captions as well
  Future<String?> _fetchTranscriptFromTimedText(String videoId) async {
    try {
      // First, try the direct auto-generated captions URL format
      final directResult = await _tryDirectAutoCaptionsUrl(videoId);
      if (directResult != null && directResult.isNotEmpty) {
        print('Successfully fetched transcript via direct auto-captions URL');
        return directResult;
      }

      // If direct method fails, fall back to page parsing
      // First, fetch the video page to get the captions track URL
      final videoUrl =
          'https://www.youtube.com/watch?v=$videoId&cc_load_policy=1';
      final videoResponse = await http.get(Uri.parse(videoUrl));

      if (videoResponse.statusCode != 200) {
        return null;
      }

      // Try to find the timedtext URL
      final videoPageContent = videoResponse.body;

      // Extract the captionTracks section
      // This regex pattern gets all caption tracks, including auto-generated ones
      final regex = RegExp(r'"captionTracks":(\[.*?\])');
      final match = regex.firstMatch(videoPageContent);

      if (match == null || match.groupCount < 1) {
        print('Could not find captionTracks in the YouTube page');
        return null;
      }

      // Extract the JSON string and parse it
      final captionsJson = match.group(1)!;

      // First try to find auto-generated captions specifically (they're often more available)
      String captionUrl = '';

      // Try auto-generated English captions first (most common)
      captionUrl = _findCaptionUrl(captionsJson, true, 'en');

      // If not found, try regular English captions
      if (captionUrl.isEmpty) {
        captionUrl = _findCaptionUrl(captionsJson, false, 'en');
      }

      // If still not found, try any auto-generated captions
      if (captionUrl.isEmpty) {
        captionUrl = _findCaptionUrl(captionsJson, true);
      }

      // Last resort, try any captions
      if (captionUrl.isEmpty) {
        captionUrl = _findCaptionUrl(captionsJson, false);
      }

      // If still no captions found, return null
      if (captionUrl.isEmpty) {
        print(
          'No caption URLs found in: ${captionsJson.substring(0, min(100, captionsJson.length))}...',
        );
        return null;
      }

      // Clean up the URL (unescape characters)
      captionUrl = captionUrl.replaceAll('\\u0026', '&');

      print(
        'Found caption URL: ${captionUrl.substring(0, min(100, captionUrl.length))}...',
      );

      // Fetch the captions XML
      final captionsResponse = await http.get(Uri.parse(captionUrl));

      if (captionsResponse.statusCode != 200) {
        print('Failed to fetch captions XML: ${captionsResponse.statusCode}');
        return null;
      }

      // Parse the XML to extract text
      final captionsXml = captionsResponse.body;
      final document = html_parser.parse(captionsXml);
      final textElements = document.getElementsByTagName('text');

      StringBuffer transcript = StringBuffer();

      for (var element in textElements) {
        if (element.text.isNotEmpty) {
          transcript.writeln(element.text);
        }
      }

      return transcript.toString();
    } catch (e) {
      print('Error fetching transcript from timedtext: $e');
      return null;
    }
  }

  /// Fallback method to try to extract transcript from the video page directly
  /// This version specifically looks for auto-generated captions as well
  Future<String?> _fetchTranscriptWithoutAPI(String videoId) async {
    try {
      final url =
          'https://www.youtube.com/watch?v=$videoId&cc_lang_pref=en&cc_load_policy=1';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Failed to fetch YouTube page: ${response.statusCode}');
        return null;
      }

      // Parse HTML content
      final document = html_parser.parse(response.body);

      // Try to find transcript in page data
      // This is a fragile approach as YouTube might change their page structure
      final scriptTags = document.getElementsByTagName('script');

      for (var script in scriptTags) {
        final content = script.text;

        if (content.contains('"captionTracks"') ||
            content.contains('"playerCaptionsTracklistRenderer"')) {
          // Try both captions patterns - auto-generated is our primary target

          // First, look specifically for auto-generated captions
          RegExp autoRegex = RegExp(r'"kind":"asr".*?"baseUrl":"(.*?)"');
          Match? autoMatch = autoRegex.firstMatch(content);

          if (autoMatch != null) {
            String captionUrl = autoMatch.group(1) ?? '';
            captionUrl = captionUrl.replaceAll('\\u0026', '&');
            print(
              'Found auto-generated caption URL: ${captionUrl.substring(0, min(100, captionUrl.length))}...',
            );

            // Fetch the caption file
            final captionResult = await _fetchCaptionFile(captionUrl);
            if (captionResult != null) {
              return captionResult;
            }
          }

          // If auto-generated captions aren't found, try regular captions
          RegExp regex = RegExp(r'"captionTracks":\[(.*?)\]');
          Match? match = regex.firstMatch(content);

          if (match != null) {
            String captionData = match.group(1) ?? '';

            // Look for baseUrl to caption track
            RegExp baseUrlRegex = RegExp(r'"baseUrl":"(.*?)"');
            Match? baseUrlMatch = baseUrlRegex.firstMatch(captionData);

            if (baseUrlMatch != null) {
              String captionUrl = baseUrlMatch.group(1) ?? '';
              captionUrl = captionUrl.replaceAll('\\u0026', '&');
              print(
                'Found regular caption URL: ${captionUrl.substring(0, min(100, captionUrl.length))}...',
              );

              // Fetch the caption file
              return await _fetchCaptionFile(captionUrl);
            }
          }
        }
      }

      // Try another approach - check for the playerCaptionsTracklistRenderer
      for (var script in scriptTags) {
        final content = script.text;
        if (content.contains('"playerCaptionsTracklistRenderer"')) {
          RegExp tracksRegex = RegExp(
            r'"playerCaptionsTracklistRenderer".*?"captionTracks":\s*(\[.*?\])',
          );
          Match? tracksMatch = tracksRegex.firstMatch(content);

          if (tracksMatch != null) {
            final tracksJson = tracksMatch.group(1)!;

            // Use our helper method to find caption URLs
            String captionUrl = _findCaptionUrl(
              tracksJson,
              true,
              'en',
            ); // Auto-generated English
            if (captionUrl.isEmpty) {
              captionUrl = _findCaptionUrl(
                tracksJson,
                false,
                'en',
              ); // Regular English
            }
            if (captionUrl.isEmpty) {
              captionUrl = _findCaptionUrl(
                tracksJson,
                true,
              ); // Any auto-generated
            }
            if (captionUrl.isEmpty) {
              captionUrl = _findCaptionUrl(tracksJson, false); // Any captions
            }

            if (captionUrl.isNotEmpty) {
              return await _fetchCaptionFile(captionUrl);
            }
          }
        }
      }
      print('Could not extract transcript from YouTube page');
      return null;
    } catch (e) {
      print('Error fetching transcript without API: $e');
      return null;
    }
  }

  /// Helper method to fetch and parse a caption file from a given URL
  Future<String?> _fetchCaptionFile(String captionUrl) async {
    try {
      // Fetch the actual caption file
      final captionResponse = await http.get(Uri.parse(captionUrl));

      if (captionResponse.statusCode == 200) {
        // Parse XML caption data
        final captionDoc = html_parser.parse(captionResponse.body);
        final textElements = captionDoc.getElementsByTagName('text');

        StringBuffer transcript = StringBuffer();

        for (var element in textElements) {
          final text = element.text;
          // element.text is not nullable in the html library
          if (text.isNotEmpty) {
            transcript.writeln(text);
          }
        }

        final result = transcript.toString();
        if (result.isNotEmpty) {
          return result;
        }
      }
      return null;
    } catch (e) {
      print('Error fetching caption file: $e');
      return null;
    }
  }

  /// Process raw transcript data into clean text
  String _processRawTranscript(String rawTranscript) {
    // This is a placeholder for transcript processing logic
    // Depending on the format of the raw transcript, you might need to:
    // - Remove timestamps
    // - Join caption segments into sentences
    // - Fix formatting

    // For now, just return the raw text with basic cleanup
    return rawTranscript
        .replaceAll(RegExp(r'\d+:\d+:\d+\.\d+'), '') // Remove timestamps
        .replaceAll(RegExp(r'[\r\n]+'), '\n') // Normalize newlines
        .trim();
  }

  /// Fetches the title of a YouTube video
  Future<String?> fetchYouTubeTitle(String videoId) async {
    try {
      if (apiKey == null) {
        return await _fetchYouTubeTitleWithoutAPI(videoId);
      }

      // Use YouTube Data API to fetch video details
      final url =
          'https://www.googleapis.com/youtube/v3/videos?part=snippet&id=$videoId&key=$apiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Failed to fetch video details: ${response.statusCode}');
        return await _fetchYouTubeTitleWithoutAPI(videoId);
      }

      final data = json.decode(response.body);

      if (data['items'] == null || data['items'].isEmpty) {
        print('No video details found for video ID: $videoId');
        return await _fetchYouTubeTitleWithoutAPI(videoId);
      }

      final title = data['items'][0]['snippet']['title'];
      return title;
    } catch (e) {
      print('Error fetching YouTube title via API: $e');
      return await _fetchYouTubeTitleWithoutAPI(videoId);
    }
  }

  /// Fallback method to extract title from YouTube page
  Future<String?> _fetchYouTubeTitleWithoutAPI(String videoId) async {
    try {
      final url = 'https://www.youtube.com/watch?v=$videoId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Failed to fetch YouTube page: ${response.statusCode}');
        return null;
      }

      // Parse HTML content
      final document = html_parser.parse(response.body);

      // Try to find the title
      final titleTags = document.getElementsByTagName('title');
      if (titleTags.isNotEmpty) {
        String title = titleTags.first.text;
        // Clean up the title (remove " - YouTube" suffix if present)
        if (title.endsWith(' - YouTube')) {
          title = title.substring(0, title.length - 10);
        }
        return title;
      }

      return null;
    } catch (e) {
      print('Error fetching YouTube title without API: $e');
      return null;
    }
  }

  /// Fetches the title of any web page
  Future<String?> fetchWebPageTitle(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        print('Failed to fetch web page: ${response.statusCode}');
        return null;
      }

      // Parse HTML content
      final document = html_parser.parse(response.body);

      // Try to find the title
      final titleTags = document.getElementsByTagName('title');
      if (titleTags.isNotEmpty) {
        return titleTags.first.text;
      }

      // Try meta tags if title tag is not available
      final metaTags = document.getElementsByTagName('meta');
      for (var tag in metaTags) {
        if (tag.attributes['property'] == 'og:title' ||
            tag.attributes['name'] == 'title') {
          return tag.attributes['content'];
        }
      }

      return null;
    } catch (e) {
      print('Error fetching web page title: $e');
      return null;
    }
  }

  /// Try to fetch auto-generated captions directly using a known URL format
  Future<String?> _tryDirectAutoCaptionsUrl(String videoId) async {
    try {
      // This URL format directly requests auto-generated captions from YouTube
      final autoUrl =
          'https://www.youtube.com/api/timedtext?lang=en&v=$videoId&kind=asr';
      print('Trying direct auto-caption URL: $autoUrl');

      final response = await http.get(Uri.parse(autoUrl));

      if (response.statusCode != 200 || response.body.isEmpty) {
        return null;
      }

      // Parse XML caption data
      final captionsXml = response.body;
      if (!captionsXml.contains('<text ')) {
        return null; // No captions in the response
      }

      final document = html_parser.parse(captionsXml);
      final textElements = document.getElementsByTagName('text');

      StringBuffer transcript = StringBuffer();

      for (var element in textElements) {
        if (element.text.isNotEmpty) {
          transcript.writeln(element.text);
        }
      }

      final result = transcript.toString();
      if (result.isNotEmpty) {
        print('Successfully extracted auto captions from direct URL!');
        return result;
      }

      return null;
    } catch (e) {
      print('Error fetching direct auto-captions: $e');
      return null;
    }
  }

  /// Helper method to find caption URL in YouTube's captionTracks data
  /// If isAutoGenerated is true, it specifically looks for auto-generated captions
  /// If languageCode is provided, it looks for captions in that language
  String _findCaptionUrl(
    String captionsJson,
    bool isAutoGenerated, [
    String? languageCode,
  ]) {
    try {
      // Parse the JSON string
      // Need to handle possible JSON parsing issues
      if (!captionsJson.startsWith('[') || !captionsJson.endsWith(']')) {
        return '';
      }

      // Extract individual caption track entries
      RegExp trackRegex = RegExp(
        r'\{"baseUrl":"(.*?)","name":\{"simpleText":"(.*?)"\},"vssId":"(.*?)","languageCode":"(.*?)","kind":"(.*?)"',
      );
      Iterable<Match> matches = trackRegex.allMatches(captionsJson);

      for (var match in matches) {
        if (match.groupCount >= 5) {
          final url = match.group(1) ?? '';
          final name = match.group(2) ?? '';
          final vssId = match.group(3) ?? '';
          final trackLangCode = match.group(4) ?? '';
          final kind = match.group(5) ?? '';

          // Check if this is what we're looking for
          bool isAuto =
              name.toLowerCase().contains('auto') ||
              vssId.toLowerCase().contains('a.') ||
              kind.toLowerCase().contains('asr');

          // If we're looking for auto-generated and this is auto-generated,
          // or if we're NOT looking for auto-generated and this is NOT auto-generated
          if (isAutoGenerated == isAuto) {
            // If language code is specified and matches, return immediately
            if (languageCode != null && trackLangCode == languageCode) {
              return url;
            }
            // If no language specified, store the first matching URL
            else if (languageCode == null) {
              return url;
            }
          }
        }
      }

      return '';
    } catch (e) {
      print('Error parsing caption JSON: $e');
      return '';
    }
  }
}
