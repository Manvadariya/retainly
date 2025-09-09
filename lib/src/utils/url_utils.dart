import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class UrlUtils {
  /// Normalizes a URL string and ensures it has a proper scheme
  static String normalizeUrl(String urlString) {
    if (urlString.isEmpty) {
      return urlString;
    }

    String normalizedUrl = urlString.trim();

    // Handle common URL schemes
    if (normalizedUrl.startsWith('www.')) {
      normalizedUrl = 'https://$normalizedUrl';
    } else if (!normalizedUrl.contains('://')) {
      // Check if it might be an email
      if (RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedUrl)) {
        normalizedUrl = 'mailto:$normalizedUrl';
      }
      // Check if it might be a phone number
      else if (RegExp(r'^\+?[\d\s\-()]{5,}$').hasMatch(normalizedUrl)) {
        normalizedUrl =
            'tel:${normalizedUrl.replaceAll(RegExp(r'[\s\-()]'), '')}';
      }
      // Default to https for web URLs
      else {
        normalizedUrl = 'https://$normalizedUrl';
      }
    }

    return normalizedUrl;
  }

  /// Launches a URL with proper error handling and fallbacks
  static Future<bool> launchUrl(
    String urlString, {
    required BuildContext context,
    bool showError = true,
  }) async {
    try {
      if (urlString.isEmpty) {
        throw Exception('URL is empty');
      }

      // Enhanced URL normalization
      String normalizedUrl = normalizeUrl(urlString);
      print('Normalized URL: $normalizedUrl');

      try {
        final Uri url = Uri.parse(normalizedUrl);
        print('Parsed URI: $url');

        // Force launch with external application for web URLs
        final url_launcher.LaunchMode mode =
            (url.scheme == 'mailto' || url.scheme == 'tel')
            ? url_launcher.LaunchMode.platformDefault
            : url_launcher.LaunchMode.externalApplication;

        final bool result = await url_launcher.launchUrl(url, mode: mode);

        if (!result) {
          throw Exception('Could not launch URL: $normalizedUrl');
        }

        print('URL launch successful');
        return true;
      } catch (e) {
        print('Error during URL parsing/launching: $e');

        // Try a more permissive approach
        try {
          // Just try to launch with the original URL as a fallback
          final fallbackUrl = Uri.parse('https://${urlString.trim()}');
          final result = await url_launcher.launchUrl(
            fallbackUrl,
            mode: url_launcher.LaunchMode.externalApplication,
          );

          if (result) {
            print('Fallback URL launch successful');
            return true;
          }
        } catch (fallbackError) {
          print('Fallback launch also failed: $fallbackError');
        }

        throw Exception('Failed to open link');
      }
    } catch (e) {
      print('Error launching URL: $e');

      // Show error if requested
      if (showError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open URL: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      return false;
    }
  }
}
