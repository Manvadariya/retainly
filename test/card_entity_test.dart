import 'package:flutter_test/flutter_test.dart';
import 'package:retainly/src/data/card_entity.dart';

void main() {
  group('CardEntity', () {
    test('CardEntity creation and properties', () {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;

      // Act
      final card = CardEntity(
        id: 1,
        type: 'text',
        content: 'Test Content',
        body: 'Test Body',
        createdAt: now,
        updatedAt: now,
      );

      // Assert
      expect(card.id, 1);
      expect(card.type, 'text');
      expect(card.content, 'Test Content');
      expect(card.body, 'Test Body');
      expect(card.createdAt, now);
      expect(card.updatedAt, now);
    });

    test('CardEntity copyWith', () {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;
      final card = CardEntity(
        id: 1,
        type: 'text',
        content: 'Test Content',
        createdAt: now,
        updatedAt: now,
      );

      // Act
      final updatedCard = card.copyWith(
        content: 'Updated Content',
        body: 'New Body',
      );

      // Assert
      expect(updatedCard.id, 1); // Unchanged
      expect(updatedCard.type, 'text'); // Unchanged
      expect(updatedCard.content, 'Updated Content'); // Changed
      expect(updatedCard.body, 'New Body'); // Changed
      expect(updatedCard.createdAt, now); // Unchanged
      expect(updatedCard.updatedAt, now); // Unchanged
    });
  });
}
