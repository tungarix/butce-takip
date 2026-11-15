import 'package:drift/drift.dart';

import '../../akilli/normalize.dart';
import '../../core/tarih.dart';
import 'tables.dart';
import 'tohum.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Categories, Transactions, Budgets, KeywordHits, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _tohumla();
    },
    // Dış anahtarlar SQLite'ta varsayılan kapalı; her açılışta açılmalı.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );

  Stream<List<Category>> kategorileriIzle() => (select(categories)
        ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
      .watch();

  /// [ay] (yyyymm) içindeki işlemler, yeni gün üstte. İlk ve son gün dahil.
  Stream<List<Transaction>> ayIslemleriniIzle(int ay) {
    final a = ayAraligi(ay);
    return (select(transactions)
          ..where((t) => t.day.isBetweenValues(a.ilk, a.son))
          ..orderBy([
            (t) => OrderingTerm.desc(t.day),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Kategori kullanım sıklığı için son [limit] işlem.
  Stream<List<Transaction>> sonIslemleriIzle({int limit = 200}) =>
      (select(transactions)
            ..orderBy([
              (t) => OrderingTerm.desc(t.day),
              (t) => OrderingTerm.desc(t.id),
            ])
            ..limit(limit))
          .watch();

  Future<int> islemEkle({
    required int tutarKurus,
    required bool gelir,
    required int kategoriId,
    required String not,
    required int gun,
  }) => into(transactions).insert(
    TransactionsCompanion.insert(
      amountKurus: tutarKurus,
      isIncome: gelir,
      categoryId: kategoriId,
      note: Value(not.trim()),
      noteNorm: Value(notNormalize(not)),
      day: gun,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ),
  );

  /// id ve createdAt korunur.
  Future<void> islemGuncelle(
    int id, {
    required int tutarKurus,
    required bool gelir,
    required int kategoriId,
    required String not,
    required int gun,
  }) => (update(transactions)..where((t) => t.id.equals(id))).write(
    TransactionsCompanion(
      amountKurus: Value(tutarKurus),
      isIncome: Value(gelir),
      categoryId: Value(kategoriId),
      note: Value(not.trim()),
      noteNorm: Value(notNormalize(not)),
      day: Value(gun),
    ),
  );

  Future<void> islemSil(int id) =>
      (delete(transactions)..where((t) => t.id.equals(id))).go();

  /// Silinen kaydı aynı id ve createdAt ile geri koyar ("Geri al").
  Future<void> islemGeriYukle(Transaction t) => into(transactions).insert(t);

  Future<void> _tohumla() async {
    final idler = <String, int>{};
    for (var i = 0; i < tohumKategoriler.length; i++) {
      final k = tohumKategoriler[i];
      idler[k.ad] = await into(categories).insert(
        CategoriesCompanion.insert(
          name: k.ad,
          icon: k.simge,
          isIncome: Value(k.gelir),
          sortOrder: i,
        ),
      );
    }
    for (final e in tohumAnahtarKelimeler.entries) {
      for (final kelime in e.value) {
        await into(keywordHits).insert(
          KeywordHitsCompanion.insert(keyword: kelime, categoryId: idler[e.key]!),
        );
      }
    }
  }
}
