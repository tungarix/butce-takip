import 'package:drift/drift.dart';

import '../../akilli/normalize.dart';
import '../../core/tarih.dart';
import 'tables.dart';
import 'tohum.dart';

part 'database.g.dart';

enum AdHatasi { bos, ayni }

/// Kategori adı boş ya da başka bir kategoriyle aynı (büyük/küçük harf ve kenar boşluğu farkı sayılmaz).
class KategoriAdiHatasi implements Exception {
  const KategoriAdiHatasi(this.neden);
  final AdHatasi neden;
}

// Türkçe İ/I elle çevrilir; Dart toLowerCase yerel ayar almaz.
String _adAnahtari(String ad) =>
    ad.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

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

  // Kategori yönetimi. Silme yok: yalnız arşivlenir, eski işlemlerde adı görünmeye devam eder.

  /// Adı doğrular; [haricId] yeniden adlandırılan kategorinin kendisidir.
  Future<String> _adiDogrula(String ad, {int? haricId}) async {
    final temiz = ad.trim();
    if (temiz.isEmpty) throw const KategoriAdiHatasi(AdHatasi.bos);
    final anahtar = _adAnahtari(temiz);
    final hepsi = await select(categories).get();
    if (hepsi.any((c) => c.id != haricId && _adAnahtari(c.name) == anahtar)) {
      throw const KategoriAdiHatasi(AdHatasi.ayni);
    }
    return temiz;
  }

  Future<int> kategoriEkle({
    required String ad,
    required int simge,
    required bool gelir,
  }) async {
    final temiz = await _adiDogrula(ad);
    final enBuyuk = await (selectOnly(categories)
          ..addColumns([categories.sortOrder.max()]))
        .map((r) => r.read(categories.sortOrder.max()))
        .getSingle();
    return into(categories).insert(
      CategoriesCompanion.insert(
        name: temiz,
        icon: simge,
        isIncome: Value(gelir),
        sortOrder: (enBuyuk ?? -1) + 1,
      ),
    );
  }

  Future<void> kategoriGuncelle(int id, {required String ad, required int simge}) async {
    final temiz = await _adiDogrula(ad, haricId: id);
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(name: Value(temiz), icon: Value(simge)),
    );
  }

  Future<void> kategoriArsivle(int id, {required bool arsivli}) =>
      (update(categories)..where((c) => c.id.equals(id))).write(
        CategoriesCompanion(archived: Value(arsivli)),
      );

  // Limitler.

  Stream<Map<int, int>> limitleriIzle() => select(budgets).watch().map(
    (l) => {for (final b in l) b.categoryId: b.monthlyLimitKurus},
  );

  /// Limit koyar ya da değiştirir.
  Future<void> limitKoy(int kategoriId, int kurus) {
    if (kurus <= 0) throw ArgumentError.value(kurus, 'kurus', 'limit 0 olamaz');
    return into(budgets).insertOnConflictUpdate(
      BudgetsCompanion.insert(categoryId: Value(kategoriId), monthlyLimitKurus: kurus),
    );
  }

  Future<void> limitKaldir(int kategoriId) =>
      (delete(budgets)..where((b) => b.categoryId.equals(kategoriId))).go();

  // Ay toplamları (aşama 4'teki aşım bildirimi de bunu kullanır).

  /// [ay] (yyyymm) için kategori -> gider toplamı. Gelir hariç; arşivli kategoriler dahil.
  Stream<Map<int, int>> ayGiderToplamlariniIzle(int ay) {
    final a = ayAraligi(ay);
    final toplam = transactions.amountKurus.sum();
    final sorgu = selectOnly(transactions)
      ..addColumns([transactions.categoryId, toplam])
      ..where(
        transactions.isIncome.equals(false) &
            transactions.day.isBetweenValues(a.ilk, a.son),
      )
      ..groupBy([transactions.categoryId]);
    return sorgu.watch().map(
      (satirlar) => {
        for (final r in satirlar) r.read(transactions.categoryId)!: r.read(toplam)!,
      },
    );
  }

  /// [ay] içindeki toplam gelir.
  Stream<int> ayGelirToplaminiIzle(int ay) {
    final a = ayAraligi(ay);
    final toplam = transactions.amountKurus.sum();
    final sorgu = selectOnly(transactions)
      ..addColumns([toplam])
      ..where(
        transactions.isIncome.equals(true) &
            transactions.day.isBetweenValues(a.ilk, a.son),
      );
    return sorgu.watchSingle().map((r) => r.read(toplam) ?? 0);
  }

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
