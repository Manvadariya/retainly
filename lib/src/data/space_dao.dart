part of 'database.dart';

@DriftAccessor(tables: [Spaces, Cards])
class SpaceDao extends DatabaseAccessor<AppDatabase> {
  SpaceDao(super.db);

  // Create a new space
  Future<int> createSpace(SpaceEntity space) async {
    // Using direct SQL with proper escaping for string values
    final query =
        '''
      INSERT INTO spaces (name, created_at) 
      VALUES ('${space.name.replaceAll("'", "''")}', ${space.createdAt})
    ''';

    await customStatement(query, []);

    // Get the last inserted ID
    final result = await customSelect(
      'SELECT last_insert_rowid() as id',
    ).getSingle();

    return result.data['id'] as int;
  }

  // Get all spaces with card counts
  Future<List<SpaceEntity>> getAllSpaces() async {
    // We need to run a join query to get the card counts
    final query = '''
      SELECT s.id, s.name, s.created_at, COUNT(c.id) as card_count 
      FROM spaces s 
      LEFT JOIN cards c ON c.space_id = s.id 
      GROUP BY s.id 
      ORDER BY s.created_at DESC
    ''';

    final rows = await customSelect(query).get();

    return rows.map((row) {
      return mapRowToSpaceEntity(
        row.data,
        cardCount: row.data['card_count'] as int,
      );
    }).toList();
  }

  // Get cards by space ID
  Future<List<CardEntity>> getCardsBySpaceId(
    int spaceId, {
    int offset = 0,
    int limit = 40,
  }) async {
    // Use a direct query with interpolation instead of parameters
    final directQuery =
        '''
      SELECT * FROM cards 
      WHERE space_id = $spaceId
      ORDER BY created_at DESC 
      LIMIT $limit OFFSET $offset
    ''';

    final rows = await customSelect(directQuery).get();

    return rows.map((row) => mapRowToCardEntity(row.data)).toList();
  }

  // Delete a space and update its cards to have null spaceId
  Future<void> deleteSpace(int id) async {
    // First update any cards in this space to have null spaceId
    await customStatement(
      'UPDATE cards SET space_id = NULL WHERE space_id = $id',
      [],
    );

    // Then delete the space
    await customStatement('DELETE FROM spaces WHERE id = $id', []);
  }
}
