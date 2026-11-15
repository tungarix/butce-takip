import 'package:drift/drift.dart';

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
