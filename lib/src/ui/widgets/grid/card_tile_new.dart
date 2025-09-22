import 'dart:io';
import 'dart:ui';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../data/card_entity.dart';
import '../../../utils/youtube_card_helper.dart';
import '../../../ui/screens/card_detail_screen.dart';
import '../../../ui/theme/app_theme.dart';

class CardTile extends StatefulWidget {
  final CardEntity card;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const CardTile({super.key, required this.card, this.onTap, this.onDelete});

  @override
  State<CardTile> createState() => _CardTileState();
}

class _CardTileState extends State<CardTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Create a stateless wrapper around OpenContainer to avoid setState during build
    return _StatelessCardWrapper(
      scaleAnimation: _scaleAnimation,
      scaleController: _scaleController,
      card: widget.card,
      onTap: widget.onTap,
      onDelete: widget.onDelete,
    );
  }
}

// Stateless wrapper to avoid setState during build issues
class _StatelessCardWrapper extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final AnimationController scaleController;
  final CardEntity card;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _StatelessCardWrapper({
    required this.scaleAnimation,
    required this.scaleController,
    required this.card,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: scaleAnimation.value, child: child);
      },
      child: _buildOpenContainer(context),
    );
  }

  Widget _buildOpenContainer(BuildContext context) {
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 300),
      closedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      closedColor: AppTheme.surfaceVariantColor,
      closedElevation: 2,
      openElevation: 0,
      openBuilder: (context, _) {
        if (card.id != null) {
          return CardDetailScreen(cardId: card.id!);
        }
        return const SizedBox();
      },
      closedBuilder: (context, openContainer) {
        return GestureDetector(
          onTapDown: (_) => scaleController.forward(),
          onTapUp: (_) => scaleController.reverse(),
          onTapCancel: () => scaleController.reverse(),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap ?? openContainer,
              borderRadius: BorderRadius.circular(16),
              splashColor: Colors.white10,
              highlightColor: Colors.white10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail area with better aspect ratio
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        color: Colors.black,
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Thumbnail or placeholder
                            _buildThumbnail(),

                            // Gradient overlay for better readability
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.6),
                                    ],
                                    stops: const [0.7, 1.0],
                                  ),
                                ),
                              ),
                            ),

                            // Card type indicator (top-left corner)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: _buildTypeIndicator(),
                            ),

                            // Play icon overlay for videos
                            if (card.type == 'video')
                              const Center(
                                child: CircleAvatar(
                                  backgroundColor: Colors.black45,
                                  radius: 24,
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),

                            // Delete button (positioned in top-right corner)
                            if (onDelete != null)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: onDelete,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content info area with better styling
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Card title with ellipsis
                        Text(
                          card.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 15,
                          ),
                        ),

                        // Optional subtext (date)
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildTypeIcon(),
                            const SizedBox(width: 6),
                            Text(
                              _getFormattedDate(),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildThumbnail() {
    // For images
    if (card.type == 'image' && card.imagePath != null) {
      return _buildImageWidget(card.imagePath!);
    }

    // For videos (just showing thumbnail)
    if (card.type == 'video' && card.imagePath != null) {
      return _buildImageWidget(card.imagePath!);
    }

    // For links with preview image
    if (card.type == 'link' && card.url != null) {
      // Prefer saved imagePath if present
      if (card.imagePath != null) {
        return _buildImageWidget(card.imagePath!);
      }

      // If it's a YouTube card, use low-res thumbnail from metadata or derived URL
      if (YouTubeCardHelper.isYouTubeCard(card)) {
        final meta = YouTubeCardHelper.extractMetadata(card);
        if (meta != null) {
          final low = meta.thumbnailLow;
          if (low.isNotEmpty) {
            return _buildImageWidget(low);
          }
        }
      }

      // Non-YouTube link or no thumbnail available
      return _buildPlaceholderWithIcon(Icons.link);
    }

    // For text cards - show text snippet on gradient background
    if (card.type == 'text') {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.7),
              AppTheme.primaryColor,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              card.body?.substring(
                    0,
                    card.body!.length > 50 ? 50 : card.body!.length,
                  ) ??
                  card.content,
              maxLines: 4,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    // Default placeholder
    return _buildPlaceholderWithIcon(Icons.note);
  }

  Widget _buildImageWidget(String path) {
    // Remote image (URL starts with http)
    if (path.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: path,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildShimmerEffect(),
        errorWidget: (context, url, error) =>
            _buildPlaceholderWithIcon(Icons.broken_image),
        fadeInDuration: const Duration(milliseconds: 300),
      );
    }

    // Local file
    try {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderWithIcon(Icons.broken_image);
        },
      );
    } catch (e) {
      return _buildPlaceholderWithIcon(Icons.broken_image);
    }
  }

  Widget _buildShimmerEffect() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Container(color: Colors.grey[800]),
    );
  }

  Widget _buildPlaceholderWithIcon(IconData icon) {
    return Container(
      color: AppTheme.surfaceVariantColor,
      child: Center(child: Icon(icon, size: 42, color: Colors.grey[400])),
    );
  }

  String _getFormattedDate() {
    final date = DateTime.fromMillisecondsSinceEpoch(card.createdAt);
    final now = DateTime.now();

    // Today
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today ${_formatTime(date)}';
    }

    // Yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday ${_formatTime(date)}';
    }

    // Within a week
    if (now.difference(date).inDays < 7) {
      return '${_getDayName(date)} ${_formatTime(date)}';
    }

    // Older
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getDayName(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }

  Widget _buildTypeIndicator() {
    Color backgroundColor;
    String label;

    switch (card.type) {
      case 'image':
        backgroundColor = Colors.blue.withOpacity(0.8);
        label = 'IMAGE';
        break;
      case 'video':
        backgroundColor = Colors.red.withOpacity(0.8);
        label = 'VIDEO';
        break;
      case 'link':
        backgroundColor = Colors.purple.withOpacity(0.8);
        label = 'LINK';
        break;
      case 'text':
        backgroundColor = AppTheme.primaryColor.withOpacity(0.8);
        label = 'TEXT';
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.8);
        label = 'NOTE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 3),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (card.type) {
      case 'image':
        iconData = Icons.image_outlined;
        iconColor = Colors.blue;
        break;
      case 'video':
        iconData = Icons.videocam_outlined;
        iconColor = Colors.red;
        break;
      case 'link':
        iconData = Icons.link;
        iconColor = Colors.purple;
        break;
      case 'text':
        iconData = Icons.text_snippet_outlined;
        iconColor = AppTheme.primaryColor;
        break;
      default:
        iconData = Icons.note_outlined;
        iconColor = Colors.grey;
    }

    return Icon(iconData, size: 12, color: iconColor);
  }
}
