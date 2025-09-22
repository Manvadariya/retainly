// A simple plain Dart model representing a Card record in the local DB.
// Keeping it independent of Drift types makes it easy to test and use in UI.

class CardEntity {
  final int? id;
  final String type; // "text", "image", or "link"
  final String content; // title or short text
  final String? body; // full note text (nullable)
  final String? imagePath; // local file path (nullable)
  final String? url; // original URL if link (nullable)
  final String? transcript; // YouTube transcript if available (nullable)
  final Map<String, dynamic>?
  metadata; // Additional metadata (e.g., YouTube data)
  final int? spaceId; // ID of the space this card belongs to (nullable)
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis

  const CardEntity({
    this.id,
    required this.type,
    required this.content,
    this.body,
    this.imagePath,
    this.url,
    this.transcript,
    this.metadata,
    this.spaceId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  String toString() {
    String bodyPreview = '';
    if (body != null) {
      final previewLength = body!.length > 20 ? 20 : body!.length;
      bodyPreview = body!.substring(0, previewLength) + '...';
    }
    return 'CardEntity(id: $id, type: $type, content: $content, body: $bodyPreview, imagePath: $imagePath, url: $url, transcript: ${transcript != null ? 'available' : 'null'}, metadata: ${metadata != null ? 'available' : 'null'}, spaceId: $spaceId)';
  }

  CardEntity copyWith({
    int? id,
    String? type,
    String? content,
    String? body,
    String? imagePath,
    String? url,
    String? transcript,
    Map<String, dynamic>? metadata,
    int? spaceId,
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
      transcript: transcript ?? this.transcript,
      metadata: metadata ?? this.metadata,
      spaceId: spaceId ?? this.spaceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
