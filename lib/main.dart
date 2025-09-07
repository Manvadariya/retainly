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
  if (nav == null) return;

  // Handle text content (plain text or URL)
  if (media.content != null && media.content!.isNotEmpty) {
    final text = media.content!.trim();
    final lower = text.toLowerCase();
    final isLikelyUrl =
        lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        (Uri.tryParse(text)?.hasScheme ?? false);

    if (isLikelyUrl) {
      // URL content - open Link Card Modal
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              AddLinkCardModal(initialUrl: text, autofocusSave: true),
        ),
      );
    } else {
      // Plain text content - open Text Card Modal
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              AddTextCardModal(initialText: text, autofocusSave: true),
        ),
      );
    }
  }
  // Handle image attachments
  else if (media.attachments != null && media.attachments!.isNotEmpty) {
    // Try to find an image attachment
    final firstImage = media.attachments!.firstWhere(
      (a) => a?.type == SharedAttachmentType.image && a?.path != null,
      orElse: () => null,
    );

    final path = firstImage?.path;
    if (path != null && File(path).existsSync()) {
      // Image found - open Image Card Modal
      nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              AddImageCardModal(imagePath: path, autofocusSave: true),
        ),
      );
    } else {
      // Image attachment declared but file not accessible
      _showUnsupportedTypeMessage(nav.context, "Image file not accessible");
    }
  }
  // No supported content found
  else {
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
