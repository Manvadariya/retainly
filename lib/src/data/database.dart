import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'card_entity.dart';

part 'database.g.dart';
part 'card_dao.dart';

// Drift table definition for cards
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get content => text()();
  TextColumn get body => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  TextColumn get url => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
}

@DriftDatabase(tables: [Cards], daos: [CardDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(QueryExecutor e) : super(e);

  static AppDatabase? _instance;

  factory AppDatabase() =>
      _instance ??= AppDatabase._internal(_openConnection());

  @override
  int get schemaVersion => 1;
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

// Mapping helpers between Drift row and CardEntity
extension CardMapper on Card {
  CardEntity toEntity() => CardEntity(
    id: id,
    type: type,
    content: content,
    body: body,
    imagePath: imagePath,
    url: url,
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
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}
