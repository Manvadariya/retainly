import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../data/card_entity.dart';
import '../../ui/theme/app_theme.dart';

class CardGrid extends StatelessWidget {
  final List<CardEntity> cards;
  final ScrollController? scrollController;
  final Function(CardEntity) onCardSelected;
  final Function(CardEntity)? onCardLongPress;
  final bool isLoading;
  final bool hasMore;

  const CardGrid({
    super.key,
    required this.cards,
    this.scrollController,
    required this.onCardSelected,
    this.onCardLongPress,
    this.isLoading = false,
    this.hasMore = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty && !isLoading) {
      return const Center(
        child: Text('No cards found', style: TextStyle(color: Colors.white70)),
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.75,
      ),
      itemCount: cards.length + (hasMore || isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= cards.length) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildCardItem(context, cards[index]);
      },
    );
  }

  Widget _buildCardItem(BuildContext context, CardEntity card) {
    // Choose image or text card appearance

    // Choose image or text card appearance
    final isImage = card.type == 'image' && card.imagePath != null;
    final isLink = card.type == 'link' && card.url != null;

    return InkWell(
      onTap: () => onCardSelected(card),
      onLongPress: onCardLongPress != null
          ? () => onCardLongPress!(card)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: AppTheme.surfaceColor,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.dividerColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isImage) _buildImageContent(card),
              if (isLink) _buildLinkContent(card),
              if (!isImage && !isLink) _buildTextContent(card),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(CardEntity card) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: card.imagePath!.startsWith('http')
                  ? Image.network(
                      card.imagePath!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Image.file(
                      File(card.imagePath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.content,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(card.createdAt),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkContent(CardEntity card) {
    final uri = Uri.tryParse(card.url!);
    final host = uri?.host ?? 'link';

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 16, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    host,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.content,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (card.body != null)
                    Expanded(
                      child: Text(
                        card.body!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(card.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(CardEntity card) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.content,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (card.body != null)
              Expanded(
                child: Text(
                  card.body!,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              _formatDate(card.createdAt),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes} min ago';
      }
      return '${diff.inHours} hr ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat.MMMd().format(date);
    }
  }
}
