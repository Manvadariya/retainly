import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'dart:io';
import 'src/app.dart';
import 'src/ui/widgets/card/add_text_card_modal.dart';
import 'src/ui/widgets/card/add_image_card_modal.dart';
import 'src/ui/widgets/card/add_link_card_modal.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start app first so navigator is available, then hook share handling
  // Wrap with RepaintBoundary to isolate rebuild issues
  runApp(RepaintBoundary(child: RetainlyApp(navigatorKey: globalNavigatorKey)));

  // Defer init to next frame to ensure navigator is attached
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final handler = ShareHandlerPlatform.instance;

    // Initial share (cold start)
    final initial = await handler.getInitialSharedMedia();
    if (initial != null) {
      _handleSharedMedia(initial);
    }

    // Stream (warm start)
    handler.sharedMediaStream.listen((SharedMedia media) {
      _handleSharedMedia(media);
    });
  });
}

void _handleSharedMedia(SharedMedia media) async {
  final nav = globalNavigatorKey.currentState;
  if (nav == null) {
    print('Share handler: Navigator not available');
    return;
  }

  print('Share handler: Received shared media');

  // Ensure we're on a stable context before showing any UI
  await Future.delayed(const Duration(milliseconds: 500));

  // Handle text content (plain text or URL)
  if (media.content != null && media.content!.isNotEmpty) {
    final text = media.content!.trim();
    print(
      'Share handler: Received text content: \"${text.length > 50 ? text.substring(0, 50) + '...' : text}\"',
    );

    final lower = text.toLowerCase();
    final isLikelyUrl =
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        (Uri.tryParse(text)?.hasScheme ?? false);

    if (isLikelyUrl) {
      // URL content - open Link Card Modal
      print('Share handler: Opening Link Card Modal with URL: $text');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav
            .push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    AddLinkCardModal(initialUrl: text, autofocusSave: true),
              ),
            )
            .then((value) {
              print('Share handler: Link modal closed with result: $value');
            });
      });
    } else {
      // Plain text content - open Text Card Modal
      print('Share handler: Opening Text Card Modal');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nav
            .push(
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) =>
                    AddTextCardModal(initialText: text, autofocusSave: true),
              ),
            )
            .then((value) {
              print('Share handler: Text modal closed with result: $value');
            });
      });
    }
  }
  // Handle image attachments
  else if (media.attachments != null && media.attachments!.isNotEmpty) {
    print('Share handler: Received ${media.attachments!.length} attachment(s)');

    // Try to find an image attachment
    final firstImage = media.attachments!.firstWhere(
      (a) => a?.type == SharedAttachmentType.image && a?.path != null,
      orElse: () => null,
    );

    if (firstImage == null) {
      print('Share handler: No valid image attachment found');
      _showUnsupportedTypeMessage(
        nav.context,
        "No valid image found in shared content",
      );
      return;
    }

    final path = firstImage.path;
    print('Share handler: Image path from attachment: $path');

    try {
      final file = File(path);
      final exists = await file.exists();

      if (exists) {
        final fileSize = await file.length();
        print('Share handler: File exists at path, size: $fileSize bytes');

        // Image found - open Image Card Modal with slight delay to ensure UI stability
        WidgetsBinding.instance.addPostFrameCallback((_) {
          nav
              .push(
                MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) =>
                      AddImageCardModal(imagePath: path, autofocusSave: true),
                ),
              )
              .then((value) {
                // Log the result of the modal closing
                print('Share handler: Image modal closed with result: $value');
              });
        });
      } else {
        print('Share handler: File does not exist at path: $path');
        _showUnsupportedTypeMessage(
          nav.context,
          "Image file not found at specified location",
        );
      }
    } catch (e) {
      print('Share handler: Error accessing image file: $e');
      _showUnsupportedTypeMessage(
        nav.context,
        "Error accessing image: ${e.toString()}",
      );
    }
  }
  // No supported content found
  else {
    print('Share handler: No supported content found in shared media');
    _showUnsupportedTypeMessage(nav.context, "Unsupported share type");
  }
}

// Helper function to show error messages for unsupported share types
void _showUnsupportedTypeMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}
