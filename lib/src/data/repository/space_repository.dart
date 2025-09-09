import '../../data/space_entity.dart';
import '../../data/database.dart';

/// Repository to abstract database access for spaces
class SpaceRepository {
  final AppDatabase _database;

  SpaceRepository({AppDatabase? database})
    : _database = database ?? AppDatabase();

  // Create a new space
  Future<int> createSpace(SpaceEntity space) async {
    // Using a direct SQL insert with string interpolation
    final query =
        '''
      INSERT INTO spaces (name, created_at) 
      VALUES ('${space.name.replaceAll("'", "''")}', ${space.createdAt})
    ''';

    await _database.customStatement(query, []);

    // Get the last inserted ID
    final result = await _database
        .customSelect('SELECT last_insert_rowid() as id')
        .getSingle();

    return result.data['id'] as int;
  }

  // Get all spaces with card counts
  Future<List<SpaceEntity>> getAllSpaces() async {
    // We'll create a custom SQL query to get spaces with card counts
    final query = '''
      SELECT s.id, s.name, s.created_at, COUNT(c.id) as card_count 
      FROM spaces s 
      LEFT JOIN cards c ON c.space_id = s.id 
      GROUP BY s.id 
      ORDER BY s.created_at DESC
    ''';

    final result = await _database.customSelect(query).get();

    return result
        .map(
          (row) => SpaceEntity(
            id: row.data['id'] as int,
            name: row.data['name'] as String,
            createdAt: row.data['created_at'] as int,
            cardCount: row.data['card_count'] as int,
          ),
        )
        .toList();
  }

  // Delete a space (cards will remain in global view with null spaceId)
  Future<void> deleteSpace(int id) async {
    // First update any cards in this space to have null spaceId
    await _database.customStatement(
      'UPDATE cards SET space_id = NULL WHERE space_id = $id',
      [],
    );

    // Then delete the space
    await _database.customStatement('DELETE FROM spaces WHERE id = $id', []);
  }

  // Update a space's name
  Future<void> updateSpace(SpaceEntity space) async {
    if (space.id == null) {
      throw ArgumentError('Space ID cannot be null for update');
    }

    // Escape single quotes in name
    final escapedName = space.name.replaceAll("'", "''");
    await _database.customStatement(
      "UPDATE spaces SET name = '$escapedName' WHERE id = ${space.id!}",
      [],
    );
  }

  // Create a sample space for testing
  Future<int> createSampleSpace() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final space = SpaceEntity(name: 'Sample Space', createdAt: now);
    return createSpace(space);
  }
}
