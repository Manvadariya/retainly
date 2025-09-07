part of 'database.dart';

@DriftAccessor(tables: [Cards])
class CardDao extends DatabaseAccessor<AppDatabase> with _$CardDaoMixin {
  CardDao(super.db);

  Future<int> insertCard(CardEntity card) async {
    return into(cards).insert(card.toCompanion());
  }

  Future<List<CardEntity>> getAllCards({int offset = 0, int limit = 40}) async {
    final query =
        (select(cards)
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(limit, offset: offset))
            .get();
    final rows = await query;
    return rows.map((e) => e.toEntity()).toList(growable: false);
  }

  Future<List<CardEntity>> searchCards(String query) async {
    final like = '%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%';
    final rows =
        await (select(cards)
              ..where(
                (t) =>
                    t.content.like(like) |
                    (t.body.isNotNull() & t.body.like(like)) |
                    (t.url.isNotNull() & t.url.like(like)),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(100))
            .get();
    return rows.map((e) => e.toEntity()).toList(growable: false);
  }

  Future<void> deleteCard(int id) async {
    await (delete(cards)..where((t) => t.id.equals(id))).go();
  }
}
