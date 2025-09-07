// A simple plain Dart model representing a Card record in the local DB.
// Keeping it independent of Drift types makes it easy to test and use in UI.

class CardEntity {
  final int? id;
  final String type; // "text", "image", or "link"
  final String content; // title or short text
  final String? body; // full note text (nullable)
  final String? imagePath; // local file path (nullable)
  final String? url; // original URL if link (nullable)
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis

  const CardEntity({
    this.id,
    required this.type,
    required this.content,
    this.body,
    this.imagePath,
    this.url,
    required this.createdAt,
    required this.updatedAt,
  });

  CardEntity copyWith({
    int? id,
    String? type,
    String? content,
    String? body,
    String? imagePath,
    String? url,
    int? createdAt,
    int? updatedAt,
  }) {
    return CardEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
