import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'card_entity.dart';
import 'space_entity.dart';

part 'database.g.dart';
part 'card_dao.dart';
part 'space_dao.dart';

// Drift table definition for spaces
class Spaces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
}

// Drift table definition for cards
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get content => text()();
  TextColumn get body => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get url => text().nullable()();
  TextColumn get transcript =>
      text().nullable()(); // Added for YouTube transcripts
  TextColumn get metadata =>
      text().nullable()(); // Added for additional structured data
  IntColumn get spaceId => integer().nullable().references(Spaces, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DriftDatabase(tables: [Cards, Spaces], daos: [CardDao, SpaceDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(QueryExecutor e) : super(e);

  static AppDatabase? _instance;

  factory AppDatabase() =>
      _instance ??= AppDatabase._internal(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        // In version 2, we're adding spaces functionality
        // First create the spaces table
        await customStatement('''
          CREATE TABLE spaces (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');

        // Then add the space_id column to cards table
        await customStatement(
          'ALTER TABLE cards ADD COLUMN space_id INTEGER REFERENCES spaces(id)',
        );
      }

      if (from <= 2) {
        // In version 3, we're adding YouTube transcript support
        await customStatement('ALTER TABLE cards ADD COLUMN transcript TEXT');
      }

      if (from <= 3) {
        // In version 4, we're adding metadata column for structured data
        await customStatement('ALTER TABLE cards ADD COLUMN metadata TEXT');
      }
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    try {
      // For mobile platforms
      if (Platform.isAndroid || Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final dbPath = '${dir.path}${Platform.pathSeparator}retainly.db';
        final file = File(dbPath);
        return NativeDatabase(file);
      }
    } catch (e) {
      // Handle case when path_provider doesn't work or platform isn't supported
      // Fallback to a temporary location - don't use in production
      final file = File('retainly.db');
      return NativeDatabase(file);
    }

    // Fallback for web, desktop, or any other platform
    final file = File('retainly.db');
    return NativeDatabase(file);
  });
}

/* 
 * Mapping helpers between Drift rows and Entities
 * NOTE: Temporarily commented out until code generation is run
 * These mappings will be uncommented once the Drift classes are generated
 */

/*
// Mapping helpers between Drift row and CardEntity
extension CardMapper on Card {
  CardEntity toEntity() => CardEntity(
    id: id,
    type: type,
    content: content,
    body: body,
    imagePath: imagePath,
    url: url,
    spaceId: spaceId,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension CardCompanionMapper on CardEntity {
  CardsCompanion toCompanion() => CardsCompanion.insert(
    type: type,
    content: content,
    body: Value(body),
    imagePath: Value(imagePath),
    url: Value(url),
    spaceId: Value(spaceId),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

// Mapping helpers for Spaces
extension SpaceMapper on Space {
  SpaceEntity toEntity({int? cardCount}) => SpaceEntity(
    id: id,
    name: name,
    createdAt: createdAt,
    cardCount: cardCount,
  );
}

extension SpaceCompanionMapper on SpaceEntity {
  SpacesCompanion toCompanion() =>
      SpacesCompanion.insert(name: name, createdAt: createdAt);
}
*/

// Manual mapping functions to use until code generation is complete
// These will be replaced by the extensions above after running the generator
CardEntity mapRowToCardEntity(Map<String, dynamic> row) {
  Map<String, dynamic>? metadataMap;

  if (row['metadata'] != null) {
    try {
      metadataMap = Map<String, dynamic>.from(
        json.decode(row['metadata'] as String),
      );
    } catch (e) {
      print('Error parsing metadata JSON: $e');
    }
  }

  return CardEntity(
    id: row['id'] as int?,
    type: row['type'] as String,
    content: row['content'] as String,
    body: row['body'] as String?,
    imagePath: row['image_path'] as String?,
    url: row['url'] as String?,
    transcript: row['transcript'] as String?,
    metadata: metadataMap,
    spaceId: row['space_id'] as int?,
    createdAt: row['created_at'] as int,
    updatedAt: row['updated_at'] as int,
  );
}

SpaceEntity mapRowToSpaceEntity(Map<String, dynamic> row, {int? cardCount}) {
  return SpaceEntity(
    id: row['id'] as int?,
    name: row['name'] as String,
    createdAt: row['created_at'] as int,
    cardCount: cardCount,
  );
}
