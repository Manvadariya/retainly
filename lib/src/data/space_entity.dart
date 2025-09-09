// A simple plain Dart model representing a Space record in the local DB.
// Similar to CardEntity, keeping it independent of Drift types

class SpaceEntity {
  final int? id;
  final String name;
  final int createdAt; // epoch millis
  final int? cardCount; // Optional count for UI display

  const SpaceEntity({
    this.id,
    required this.name,
    required this.createdAt,
    this.cardCount,
  });

  SpaceEntity copyWith({
    int? id,
    String? name,
    int? createdAt,
    int? cardCount,
  }) {
    return SpaceEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      cardCount: cardCount ?? this.cardCount,
    );
  }
}
