import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/card_entity.dart';
import '../../data/repository/card_repository.dart';
import '../../utils/url_utils.dart';

class CardDetailScreen extends StatefulWidget {
  final int cardId;

  const CardDetailScreen({super.key, required this.cardId});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen>
    with SingleTickerProviderStateMixin {
  late Future<CardEntity?> _cardFuture;
  VideoPlayerController? _videoController;
  final CardRepository _repository = CardRepository();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _cardFuture = _loadCard();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  Future<CardEntity?> _loadCard() async {
    try {
      final cards = await _repository.getAllCards();
      return cards.firstWhere((card) => card.id == widget.cardId);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Video player initialization was moved to a different location

  void _showDeleteConfirmation(CardEntity card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Card', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this card?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete the card
              _repository.deleteCard(card.id!).then((_) {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(
                  context,
                ).pop(true); // Pop detail screen with reload flag
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CardEntity?>(
      future: _cardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: const Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          final card = snapshot.data!;

          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              backgroundColor: const Color(0xFF121212),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              actions: [
                if (card.type == 'link')
                  IconButton(
                    icon: const Icon(Icons.open_in_browser),
                    onPressed: () => _launchUrl(card.url!),
                    tooltip: 'Open URL',
                  ),
                if (card.type == 'image')
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () async {
                      try {
                        await Share.shareXFiles([
                          XFile(card.imagePath!),
                        ], text: card.content);
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error sharing: $e')),
                          );
                        }
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _showDeleteConfirmation(card),
                ),
              ],
            ),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title section for all card types
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            card.content,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(
                          width: 8,
                        ), // Add some padding to the right
                        Icon(
                          _getCardTypeIcon(card.type),
                          color: _getCardTypeColor(card.type),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date information
                    Text(
                      'Created: ${_formatDate(card.createdAt)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (card.updatedAt != card.createdAt)
                      Text(
                        'Updated: ${_formatDate(card.updatedAt)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),

                    const SizedBox(height: 16),

                    // Card type specific content
                    if (card.type == 'text' && card.body != null) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        child: Text(
                          card.body!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ] else if (card.type == 'image' &&
                        card.imagePath != null) ...[
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => Scaffold(
                                    backgroundColor: Colors.black,
                                    appBar: AppBar(
                                      backgroundColor: Colors.black,
                                      iconTheme: const IconThemeData(
                                        color: Colors.white,
                                      ),
                                    ),
                                    body: PhotoView(
                                      imageProvider: FileImage(
                                        File(card.imagePath!),
                                      ),
                                      minScale:
                                          PhotoViewComputedScale.contained,
                                      maxScale:
                                          PhotoViewComputedScale.covered * 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: Hero(
                              tag: 'image_${card.id}',
                              child: Image.file(
                                File(card.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[800],
                                    child: const Center(
                                      child: Icon(
                                        Icons.broken_image,
                                        color: Colors.white,
                                        size: 64,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else if (card.type == 'link' && card.url != null) ...[
                      GestureDetector(
                        onTap: () => _launchUrl(card.url!),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.link,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          card.url!,
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          card.content,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // YouTube transcript section (if available)
                      if (card.transcript != null &&
                          card.transcript!.isNotEmpty) ...[
                        const SizedBox(height: 24),

                        const Divider(color: Color(0xFF303030)),

                        const Text(
                          'Video Transcript',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          decoration: BoxDecoration(
                            color: const Color(0xFF212121),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              card.transcript!,
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Add a more obvious open URL button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final String url = card.url!;
                            print('Opening URL from button: $url');
                            _launchUrl(url);
                          },
                          icon: const Icon(Icons.open_in_browser),
                          label: const Text('Open Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            textStyle: const TextStyle(fontSize: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        } else {
          // Card not found or error
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: AppBar(
              backgroundColor: const Color(0xFF121212),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body: Center(
              child: Text(
                snapshot.error != null
                    ? 'Error: ${snapshot.error}'
                    : 'Card not found',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      print('Attempting to launch URL: $urlString');

      // Use the URL utils class for consistent URL handling
      if (mounted) {
        final result = await UrlUtils.launchUrl(
          urlString,
          context: context,
          showError: true,
        );

        print('URL launch result: $result');
      }
    } catch (e) {
      print('Error in _launchUrl: $e');
      // Error handling is done inside UrlUtils.launchUrl
    }
  }

  String _formatDate(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Today
      return 'Today at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Within a week
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return '${weekdays[dateTime.weekday - 1]} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // More than a week
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  IconData _getCardTypeIcon(String type) {
    switch (type) {
      case 'text':
        return Icons.note;
      case 'image':
        return Icons.image;
      case 'link':
        return Icons.link;
      default:
        return Icons.help_outline;
    }
  }

  Color _getCardTypeColor(String type) {
    switch (type) {
      case 'text':
        return Colors.green;
      case 'image':
        return Colors.purple;
      case 'link':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
