import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../../data/card_entity.dart';
import '../../../data/repository/card_repository.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../utils/url_utils.dart';

/// Shows a fullscreen preview overlay when a card is long-pressed
class CardPreviewOverlay extends StatelessWidget {
  final CardEntity card;
  final VoidCallback onEdit;
  final CardRepository cardRepository;

  const CardPreviewOverlay({
    super.key,
    required this.card,
    required this.onEdit,
    required this.cardRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Blurred background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withOpacity(0.4),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Main content with dismiss behavior
            Center(
              child: GestureDetector(
                onTap: () {},
                child: DismissibleCardPreview(
                  card: card,
                  onDismissed: () => Navigator.of(context).pop(),
                  onEdit: onEdit,
                  cardRepository: cardRepository,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DismissibleCardPreview extends StatelessWidget {
  final CardEntity card;
  final VoidCallback? onDismissed;
  final VoidCallback onEdit;
  final CardRepository cardRepository;

  const DismissibleCardPreview({
    super.key,
    required this.card,
    this.onDismissed,
    required this.onEdit,
    required this.cardRepository,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Avoid triggering tap on the parent overlay
      onTap: () {},
      child: Dismissible(
        key: Key('preview-${card.id}'),
        direction: DismissDirection.down,
        onDismissed: (_) {
          if (onDismissed != null) {
            onDismissed!();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card Preview Content
            Hero(
              tag: 'card-${card.id}',
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariantColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildCardPreview(context),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Actions Row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onEdit();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.onPrimaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Delete button
                OutlinedButton.icon(
                  onPressed: () => _showDeleteConfirmation(context),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade600,
                    side: BorderSide(color: Colors.red.shade600),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Created date
            Text(
              'Created: ${DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(card.createdAt))}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // Build the appropriate preview based on card type
  Widget _buildCardPreview(BuildContext context) {
    switch (card.type) {
      case 'text':
        return _buildTextCardPreview(context);
      case 'image':
        return _buildImageCardPreview(context);
      case 'link':
        return _buildLinkCardPreview(context);
      default:
        return _buildTextCardPreview(context);
    }
  }

  // Text card preview
  Widget _buildTextCardPreview(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Text(
          card.content,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  // Image card preview
  Widget _buildImageCardPreview(BuildContext context) {
    final imagePath = card.imagePath;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (imagePath != null && imagePath.isNotEmpty)
              _buildImageWidget(imagePath)
            else
              const SizedBox(
                height: 240,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              ),

            // Caption if any
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                card.content,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build image widget based on path
  Widget _buildImageWidget(String path) {
    // Remote image (URL starts with http)
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.contain,
        width: double.infinity,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
        ),
      );
    }

    // Local file
    try {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
          );
        },
      );
    } catch (e) {
      return const Center(
        child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
      );
    }
  }

  // Link card preview
  Widget _buildLinkCardPreview(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      width: double.infinity,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Link icon or placeholder
            Container(
              height: 120,
              color: Colors.grey.shade800,
              child: const Center(
                child: Icon(Icons.link, size: 48, color: Colors.white54),
              ),
            ),

            // Content and URL
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content as title
                  Text(
                    card.content,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // URL - clickable
                  if (card.url != null && card.url!.isNotEmpty)
                    GestureDetector(
                      onTap: () => _launchUrlFromPreview(context, card.url!),
                      child: Text(
                        card.url!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade300,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),

                  // Add Open URL button
                  if (card.url != null && card.url!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _launchUrlFromPreview(context, card.url!),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Launch URL with proper error handling
  Future<void> _launchUrlFromPreview(
    BuildContext context,
    String urlString,
  ) async {
    print('Using UrlUtils to launch URL from preview: $urlString');
    await UrlUtils.launchUrl(urlString, context: context, showError: true);
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Material(
        type: MaterialType.transparency,
        child: AlertDialog(
          backgroundColor: AppTheme.surfaceVariantColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Card',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Are you sure you want to delete "${card.content.length > 30 ? card.content.substring(0, 30) + '...' : card.content}"?',
            style: const TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteCard(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('DELETE'),
            ),
          ],
        ),
      ),
    );
  }

  // Delete the card
  void _deleteCard(BuildContext context) async {
    if (card.id == null) return;

    try {
      await cardRepository.deleteCard(card.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // Close the preview overlay
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting card: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Helper function to show the card preview overlay
void showCardPreviewOverlay({
  required BuildContext context,
  required CardEntity card,
  required VoidCallback onEdit,
  required CardRepository cardRepository,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    barrierLabel: 'Dismiss',
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation1, animation2) {
      return CardPreviewOverlay(
        card: card,
        onEdit: onEdit,
        cardRepository: cardRepository,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ).drive(Tween<double>(begin: 0.95, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}
