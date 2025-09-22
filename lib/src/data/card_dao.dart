part of 'database.dart';

@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  // Insert a card using direct SQL to avoid dependency on generated code
  Future<int> insertCard(CardEntity card) async {
    // Rather than using customStatement with an array of parameters,
    // let's explicitly construct the SQL statement with proper value handling

    print("CardDAO: Inserting new card of type: ${card.type}");
    if (card.type == 'image') {
      print("CardDAO: Image path: ${card.imagePath}");
      if (card.imagePath != null) {
        // Check if the image file exists
        final file = File(card.imagePath!);
        final exists = await file.exists();
        print("CardDAO: Image file exists? $exists at ${file.absolute.path}");
      }
    }

    // Helper function to handle SQL string values
    String sqlString(String? value) =>
        value == null ? 'NULL' : "'${value.replaceAll("'", "''")}'";

    // Helper function to handle SQL int values
    String sqlInt(int? value) => value?.toString() ?? 'NULL';

    // Convert metadata to JSON string if present
    String? metadataJson;
    if (card.metadata != null && card.metadata!.isNotEmpty) {
      try {
        metadataJson = jsonEncode(card.metadata);
      } catch (e) {
        print("CardDAO: Error encoding metadata to JSON: $e");
      }
    }

    final query =
        '''
      INSERT INTO cards (
        type, content, body, image_path, url, transcript, metadata, space_id, created_at, updated_at
      ) VALUES (
        '${card.type}', 
        '${card.content.replaceAll("'", "''")}',
        ${sqlString(card.body)},
        ${sqlString(card.imagePath)},
        ${sqlString(card.url)},
        ${sqlString(card.transcript)},
        ${sqlString(metadataJson)},
        ${sqlInt(card.spaceId)},
        ${card.createdAt},
        ${card.updatedAt}
      )
    ''';

    await customStatement(query, []);

    // Get the last inserted ID
    final result = await customSelect(
      'SELECT last_insert_rowid() as id',
    ).getSingle();

    return result.data['id'] as int;
  }

  Future<List<CardEntity>> getAllCards({int offset = 0, int limit = 40}) async {
    final query = '''
      SELECT * FROM cards 
      ORDER BY created_at DESC 
      LIMIT ? OFFSET ?
    ''';

    final rows = await customSelect(
      query,
      variables: [Variable<int>(limit), Variable<int>(offset)],
    ).get();

    return rows.map((row) => mapRowToCardEntity(row.data)).toList();
  }

  Future<List<CardEntity>> searchCards(String query) async {
    // Prepare case-insensitive like pattern and hashtag token
    final raw = query.trim();
    final lowered = raw.toLowerCase();
    final like = '%${lowered.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final tag = lowered.startsWith('#') ? lowered.substring(1) : lowered;

    // Search content/body/url case-insensitively and metadata JSON for tags
    final sqlQuery = '''
      SELECT * FROM cards 
      WHERE LOWER(content) LIKE ?
         OR (body IS NOT NULL AND LOWER(body) LIKE ?)
         OR (url IS NOT NULL AND LOWER(url) LIKE ?)
         OR (
              metadata IS NOT NULL 
          AND  LOWER(metadata) LIKE ? -- match raw term in JSON
          AND  LOWER(metadata) LIKE '%"tags"%' -- ensure tags key exists
         )
         OR (
              metadata IS NOT NULL
          AND  (
                 LOWER(metadata) LIKE ? -- tag without #
              )
         )
      ORDER BY created_at DESC 
      LIMIT 100
    ''';

    final rows = await customSelect(
      sqlQuery,
      variables: [
        Variable<String>(like), // content
        Variable<String>(like), // body
        Variable<String>(like), // url
        Variable<String>(like), // metadata contains term
        Variable<String>('%"$tag"%'), // metadata contains the tag string
      ],
    ).get();

    return rows.map((row) => mapRowToCardEntity(row.data)).toList();
  }

  Future<void> deleteCard(int id) async {
    await customStatement('DELETE FROM cards WHERE id = ?', [id]);
  }

  // Update card metadata (and updated_at) by matching YouTube videoId.
  // Matches rows where metadata JSON contains the exact videoId, or URL contains the id.
  Future<void> updateCardMetadataByVideoId(
    String videoId,
    Map<String, dynamic> metadata,
  ) async {
    try {
      final metadataJson = jsonEncode(metadata).replaceAll("'", "''");
      final now = DateTime.now().millisecondsSinceEpoch;

      final query =
          '''
        UPDATE cards
        SET metadata = '$metadataJson', updated_at = $now
        WHERE (
                metadata IS NOT NULL
            AND LOWER(metadata) LIKE '%"videoid":"${videoId.toLowerCase()}"%'
        )
        OR (
                url IS NOT NULL
            AND LOWER(url) LIKE '%${videoId.toLowerCase()}%'
        )
      ''';

      await customStatement(query, []);
    } catch (e) {
      // Log and ignore – UI already has fresh data; DB sync can retry later
      print('CardDAO: Failed to update metadata for videoId=$videoId: $e');
    }
  }
}
