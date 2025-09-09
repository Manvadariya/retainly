import 'dart:io';

import '../../data/card_entity.dart';
import '../../data/database.dart';
import '../../utils/image_storage.dart';
import 'package:drift/drift.dart';

/// Repository to abstract database access for cards
class CardRepository {
  final AppDatabase _database;
  final ImageStorage _imageStorage;

  CardRepository({AppDatabase? database, ImageStorage? imageStorage})
    : _database = database ?? AppDatabase(),
      _imageStorage = imageStorage ?? ImageStorage();

  Future<int> addCard(CardEntity card) async {
    print('Repository: Adding card of type: ${card.type}');

    // Extra validation for image cards
    if (card.type == 'image') {
      print('Repository: Image path: ${card.imagePath}');
      if (card.imagePath != null) {
        try {
          final file = File(card.imagePath!);
          final exists = await file.exists();
          final fileSize = exists ? await file.length() : 0;

          print(
            'Repository: Image file exists? $exists, size: $fileSize bytes',
          );

          if (!exists) {
            print('Repository: WARNING - Image file does not exist!');
            throw Exception(
              'Image file does not exist at path: ${card.imagePath}',
            );
          }

          if (fileSize <= 0) {
            print('Repository: WARNING - Image file is empty!');
            throw Exception('Image file is empty at path: ${card.imagePath}');
          }
        } catch (e) {
          print('Repository: Error checking image file: $e');
          throw Exception('Error accessing image file: ${e.toString()}');
        }
      } else {
        print('Repository: WARNING - Image path is null!');
        throw Exception('Cannot add image card with null image path');
      }
    }

    try {
      final id = await _database.cardDao.insertCard(card);
      print('Repository: Card added with ID: $id');

      // Verify the card was actually added
      final verifyQuery = 'SELECT * FROM cards WHERE id = $id';
      final result = await _database.customSelect(verifyQuery).get();
      if (result.isEmpty) {
        print('Repository: ERROR - Card not found after insertion!');
        throw Exception('Card was not saved correctly');
      }

      print('Repository: Card verified in database with ID: $id');
      return id;
    } catch (e) {
      print('Repository: ERROR adding card - $e');
      rethrow;
    }
  }

  Future<List<CardEntity>> getAllCards({int offset = 0, int limit = 40}) {
    return _database.cardDao.getAllCards(offset: offset, limit: limit);
  }

  Future<List<CardEntity>> getGlobalCards({
    int offset = 0,
    int limit = 40,
  }) async {
    final query = '''
      SELECT * FROM cards 
      WHERE space_id IS NULL
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    ''';

    final result = await _database
        .customSelect(
          query,
          variables: [Variable<int>(limit), Variable<int>(offset)],
        )
        .get();

    return result
        .map(
          (row) => CardEntity(
            id: row.read<int>('id'),
            type: row.read<String>('type'),
            content: row.read<String>('content'),
            body: row.readNullable<String>('body'),
            imagePath: row.readNullable<String>('image_path'),
            url: row.readNullable<String>('url'),
            spaceId: row.readNullable<int>('space_id'),
            createdAt: row.read<int>('created_at'),
            updatedAt: row.read<int>('updated_at'),
          ),
        )
        .toList();
  }

  Future<List<CardEntity>> searchCards(String query) {
    return _database.cardDao.searchCards(query);
  }

  Future<List<CardEntity>> getCardsBySpaceId(
    int spaceId, {
    int offset = 0,
    int limit = 40,
  }) async {
    print('Repository: Fetching cards for space ID: $spaceId');

    final directQuery =
        'SELECT * FROM cards WHERE space_id = $spaceId ORDER BY created_at DESC LIMIT $limit OFFSET $offset';

    final result = await _database.customSelect(directQuery).get();

    final cards = result.map((row) => mapRowToCardEntity(row.data)).toList();
    print('Repository: Found ${cards.length} cards in space ID: $spaceId');

    // Debug image cards
    final imageCards = cards.where((card) => card.type == 'image').toList();
    print('Repository: Found ${imageCards.length} image cards');

    // Verify all image cards have valid paths
    for (final card in imageCards) {
      print('Repository: Image card ID: ${card.id}, path: ${card.imagePath}');

      // Skip remote images (start with http)
      if (card.imagePath != null && !card.imagePath!.startsWith('http')) {
        try {
          // Check if the image file exists
          final file = File(card.imagePath!);
          final exists = await file.exists();
          print('Repository: Image file exists? $exists');

          if (!exists) {
            print(
              'Repository: WARNING - Image file not found: ${card.imagePath}',
            );
          } else {
            final size = await file.length();
            print('Repository: Image file size: ${size / 1024}KB');
          }
        } catch (e) {
          print('Repository: Error checking image file: $e');
        }
      }
    }

    return cards;
  }

  Future<int> addCardToSpace(CardEntity card, int spaceId) {
    final cardWithSpace = card.copyWith(spaceId: spaceId);
    return addCard(cardWithSpace);
  }

  Future<void> moveCardToSpace(int cardId, int? spaceId) async {
    // We'll use a custom SQL update with direct interpolation
    final query = spaceId != null
        ? 'UPDATE cards SET space_id = $spaceId WHERE id = $cardId'
        : 'UPDATE cards SET space_id = NULL WHERE id = $cardId';

    await _database.customStatement(query, []);
  }

  Future<void> deleteCard(int id) async {
    // First, get the card to check for associated files
    final cards = await _database.cardDao.getAllCards();
    final card = cards.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Card not found'),
    );

    // Delete any associated files
    if (card.imagePath != null && !card.imagePath!.startsWith('http')) {
      await _imageStorage.deleteImagePair(card.imagePath!);
    }

    // Delete the database record
    return _database.cardDao.deleteCard(id);
  }

  /// Create a sample card for testing
  Future<int> createSampleCard() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final card = CardEntity(
      type: 'text',
      content: 'Sample Note',
      body: 'This is a sample note created for testing the database.',
      createdAt: now,
      updatedAt: now,
    );
    return addCard(card);
  }
}
