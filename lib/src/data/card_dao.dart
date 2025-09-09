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

    final query =
        '''
      INSERT INTO cards (
        type, content, body, image_path, url, space_id, created_at, updated_at
      ) VALUES (
        '${card.type}', 
        '${card.content.replaceAll("'", "''")}',
        ${sqlString(card.body)},
        ${sqlString(card.imagePath)},
        ${sqlString(card.url)},
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
    final like = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final sqlQuery = '''
      SELECT * FROM cards 
      WHERE content LIKE ? 
         OR (body IS NOT NULL AND body LIKE ?) 
         OR (url IS NOT NULL AND url LIKE ?)
      ORDER BY created_at DESC 
      LIMIT 100
    ''';

    final rows = await customSelect(
      sqlQuery,
      variables: [
        Variable<String>(like),
        Variable<String>(like),
        Variable<String>(like),
      ],
    ).get();

    return rows.map((row) => mapRowToCardEntity(row.data)).toList();
  }

  Future<void> deleteCard(int id) async {
    await customStatement('DELETE FROM cards WHERE id = ?', [id]);
  }
}
