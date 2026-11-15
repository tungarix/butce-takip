import 'package:drift/drift.dart';

import '../../akilli/normalize.dart';
import '../../akilli/tekrar_tespit.dart';
import '../../core/tarih.dart';
import 'tables.dart';
import 'tohum.dart';

part 'database.g.dart';

// settings anahtarları.
const bildirimAcikAnahtari = 'bildirim_acik'; // '0' kapalı; yoksa açık
const izinSorulduAnahtari = 'bildirim_izin_soruldu';
const tekrarRedOnEki = 'tekrar_red_'; // + tekrarAnahtari

enum AdHatasi { bos, ayni }

/// Kategori adı boş ya da başka bir kategoriyle aynı (büyük/küçük harf ve kenar boşluğu farkı sayılmaz).
class KategoriAdiHatasi implements Exception {
  const KategoriAdiHatasi(this.neden);
  final AdHatasi neden;
}

// Türkçe İ/I elle çevrilir; Dart toLowerCase yerel ayar almaz.
String _adAnahtari(String ad) =>
    ad.trim().replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

@DriftDatabase(
  tables: [Categories, Transactions, Budgets, KeywordHits, Settings],
)
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

  Stream<List<Category>> kategorileriIzle() => (select(
    categories,
  )..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).watch();

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

  /// Kaydedilen kategori için notun her sözcüğüne hits + 1 (satır yoksa 1 ile eklenir).
  Future<void> _sozcukleriSay(String not, int kategoriId) async {
    for (final kelime in notSozcukleri(not)) {
      await into(keywordHits).insert(
        KeywordHitsCompanion.insert(keyword: kelime, categoryId: kategoriId),
        onConflict: DoUpdate(
          (old) =>
              KeywordHitsCompanion.custom(hits: old.hits + const Constant(1)),
          target: [keywordHits.keyword, keywordHits.categoryId],
        ),
      );
    }
  }

  /// İşlem ve anahtar kelime sayaçları tek transaction'da yazılır.
  Future<int> islemEkle({
    required int tutarKurus,
    required bool gelir,
    required int kategoriId,
    required String not,
    required int gun,
  }) => transaction(() async {
    final id = await into(transactions).insert(
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
    await _sozcukleriSay(not, kategoriId);
    return id;
  });

  /// id ve createdAt korunur. Kategori değiştiyse yeni kategoriye +1 (eskisinden düşülmez).
  Future<void> islemGuncelle(
    int id, {
    required int tutarKurus,
    required bool gelir,
    required int kategoriId,
    required String not,
    required int gun,
  }) => transaction(() async {
    final eski = await (select(
      transactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    await (update(transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        amountKurus: Value(tutarKurus),
        isIncome: Value(gelir),
        categoryId: Value(kategoriId),
        note: Value(not.trim()),
        noteNorm: Value(notNormalize(not)),
        day: Value(gun),
      ),
    );
    if (eski != null && eski.categoryId != kategoriId) {
      await _sozcukleriSay(not, kategoriId);
    }
  });

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
    final enBuyuk =
        await (selectOnly(categories)..addColumns([categories.sortOrder.max()]))
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

  Future<void> kategoriGuncelle(
    int id, {
    required String ad,
    required int simge,
  }) async {
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

  Stream<Map<int, int>> limitleriIzle() =>
      select(budgets)
          .watch()
          .map((l) => {for (final b in l) b.categoryId: b.monthlyLimitKurus});

  /// Limit koyar ya da değiştirir.
  Future<void> limitKoy(int kategoriId, int kurus) {
    if (kurus <= 0) throw ArgumentError.value(kurus, 'kurus', 'limit 0 olamaz');
    return into(budgets).insertOnConflictUpdate(
      BudgetsCompanion.insert(
        categoryId: Value(kategoriId),
        monthlyLimitKurus: kurus,
      ),
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
        for (final r in satirlar)
          r.read(transactions.categoryId)!: r.read(toplam)!,
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

  /// [ay] içinde [kategoriId]'nin gider toplamı.
  Future<int> ayKategoriGideri(int kategoriId, int ay) async {
    final a = ayAraligi(ay);
    final toplam = transactions.amountKurus.sum();
    final r =
        await (selectOnly(transactions)
              ..addColumns([toplam])
              ..where(
                transactions.isIncome.equals(false) &
                    transactions.categoryId.equals(kategoriId) &
                    transactions.day.isBetweenValues(a.ilk, a.son),
              ))
            .getSingle();
    return r.read(toplam) ?? 0;
  }

  /// [ilkGun]'den (yyyymmdd, dahil) sonraki tüm gider işlemleri; ileri tarihli olanlar da gelir.
  Stream<List<GiderKaydi>> giderleriIzle(int ilkGun) =>
      (select(transactions)..where(
            (t) =>
                t.isIncome.equals(false) & t.day.isBiggerOrEqualValue(ilkGun),
          ))
          .watch()
          .map(
            (l) => [
              for (final t in l)
                (
                  tutar: t.amountKurus,
                  kategoriId: t.categoryId,
                  noteNorm: t.noteNorm,
                  not: t.note,
                  gun: t.day,
                ),
            ],
          );

  /// Notun [sozcukler]i için kayıtlı anahtar kelime satırları.
  Future<List<KeywordHit>> anahtarSatirlari(List<String> sozcukler) =>
      (select(keywordHits)..where((k) => k.keyword.isIn(sozcukler))).get();

  Future<int?> limitOku(int kategoriId) async =>
      (await (select(
            budgets,
          )..where((b) => b.categoryId.equals(kategoriId))).getSingleOrNull())
          ?.monthlyLimitKurus;

  Future<String> kategoriAdi(int id) async =>
      (await (select(
        categories,
      )..where((c) => c.id.equals(id))).getSingleOrNull())?.name ??
      '';

  // settings: anahtar -> metin.

  Future<String?> ayarOku(String anahtar) async => (await (select(
    settings,
  )..where((s) => s.key.equals(anahtar))).getSingleOrNull())?.value;

  Future<void> ayarYaz(String anahtar, String deger) => into(settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(key: anahtar, value: deger),
      );

  Stream<String?> ayarIzle(String anahtar) =>
      (select(settings)..where((s) => s.key.equals(anahtar)))
          .watchSingleOrNull()
          .map((s) => s?.value);

  /// [onEk] ile başlayan ayar anahtarları, önek atılmış olarak.
  Stream<Set<String>> ayarAnahtarlariniIzle(String onEk) =>
      (select(settings)..where((s) => s.key.like('$onEk%'))).watch().map(
        (l) => {
          for (final s in l)
            if (s.key.startsWith(onEk)) s.key.substring(onEk.length),
        },
      );

  Future<Set<String>> ayarVarOlanlar(List<String> anahtarlar) async => {
    for (final s in await (select(
      settings,
    )..where((s) => s.key.isIn(anahtarlar))).get())
      s.key,
  };

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
          KeywordHitsCompanion.insert(
            keyword: kelime,
            categoryId: idler[e.key]!,
          ),
        );
      }
    }
  }
}
