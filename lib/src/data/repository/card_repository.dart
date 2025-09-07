import '../../data/card_entity.dart';
import '../../data/database.dart';
import '../../utils/image_storage.dart';

/// Repository to abstract database access for cards
class CardRepository {
  final AppDatabase _database;
  final ImageStorage _imageStorage;

  CardRepository({AppDatabase? database, ImageStorage? imageStorage})
    : _database = database ?? AppDatabase(),
      _imageStorage = imageStorage ?? ImageStorage();

  Future<int> addCard(CardEntity card) {
    return _database.cardDao.insertCard(card);
  }

  Future<List<CardEntity>> getAllCards({int offset = 0, int limit = 40}) {
    return _database.cardDao.getAllCards(offset: offset, limit: limit);
  }

  Future<List<CardEntity>> searchCards(String query) {
    return _database.cardDao.searchCards(query);
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
