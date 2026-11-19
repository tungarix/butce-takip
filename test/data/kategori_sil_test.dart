import 'package:butce_takip/data/database/database.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  // Tohum: 1 Market, 2 Ulaşım, 9 Diğer, 10 Maaş.
  Future<void> ekle(int kat, int tutar, {bool gelir = false}) => db.islemEkle(
    tutarKurus: tutar,
    gelir: gelir,
    kategoriId: kat,
    not: 'deneme',
    gun: 20260310,
  );

  Future<List<int>> kategoriIdleri(int hedef) async =>
      (await (db.select(db.transactions)
                ..where((t) => t.categoryId.equals(hedef))
                ..orderBy([(t) => OrderingTerm.asc(t.id)]))
              .get())
          .map((t) => t.id)
          .toList();

  Future<int> adet() async => (await db.select(db.transactions).get()).length;

  Future<Category?> bul(String ad) => (db.select(
    db.categories,
  )..where((c) => c.name.equals(ad))).getSingleOrNull();

  test('işlemler Diğer\'e taşınır; sayı ve ay toplamları aynı; limit ve kelimeler gider', () async {
    await ekle(1, 1000);
    await ekle(1, 2500);
    await ekle(2, 700);
    await ekle(9, 300);
    await db.limitKoy(1, 50000);
    expect(await db.kategoriIslemSayisi(1), 2);
    final oncesi = await db.ayGiderToplamlariniIzle(202603).first;
    final toplamOnce = oncesi.values.reduce((a, b) => a + b);

    await db.kategoriSil(1);

    expect(await adet(), 4);
    expect(await db.kategoriIslemSayisi(9), 3);
    final sonra = await db.ayGiderToplamlariniIzle(202603).first;
    expect(sonra.values.reduce((a, b) => a + b), toplamOnce);
    expect(sonra[9], 3800);
    expect(await bul('Market'), isNull);
    expect(await db.limitOku(1), isNull);
    expect(
      await (db.select(
        db.keywordHits,
      )..where((k) => k.categoryId.equals(1))).get(),
      isEmpty,
    );
    expect(
      await (db.select(
        db.keywordHits,
      )..where((k) => k.categoryId.equals(2))).get(),
      isNotEmpty,
      reason: 'başka kategorinin kelimeleri durur',
    );
  });

  test('gelir kategorisi Diğer gelir\'e gider; yoksa oluşur', () async {
    final id = await db.kategoriEkle(ad: 'Burs', simge: 19, gelir: true);
    await ekle(id, 5000, gelir: true);
    expect(await bul('Diğer gelir'), isNull);

    await db.kategoriSil(id);

    final hedef = (await bul('Diğer gelir'))!;
    expect((hedef.isIncome, hedef.archived, hedef.icon), (true, false, 9));
    expect(await db.kategoriIslemSayisi(hedef.id), 1);
    expect(await db.ayGelirToplaminiIzle(202603).first, 5000);
  });

  test('hedef yoksa (yeniden adlandırılmış) oluşur', () async {
    await db.kategoriGuncelle(9, ad: 'Başka', simge: 8);
    await ekle(1, 100);
    await db.kategoriSil(1);
    final diger = (await bul('Diğer'))!;
    expect((diger.id == 9, diger.icon, diger.isIncome), (false, 8, false));
    expect(await db.kategoriIslemSayisi(diger.id), 1);
  });

  test('hedef arşivliyse arşivden çıkar', () async {
    await db.kategoriArsivle(9, arsivli: true);
    await ekle(1, 100);
    await db.kategoriSil(1);
    expect((await bul('Diğer'))!.archived, isFalse);
    expect(await db.kategoriIslemSayisi(9), 1);
  });

  test('Diğer ve Diğer gelir silinemez', () async {
    await ekle(9, 100);
    await expectLater(db.kategoriSil(9), throwsStateError);
    final id = await db.kategoriEkle(ad: 'Diğer gelir', simge: 9, gelir: true);
    await expectLater(db.kategoriSil(id), throwsStateError);
    expect(await bul('Diğer'), isNotNull);
    expect(await db.kategoriIslemSayisi(9), 1);
    expect(digerMi((await bul('Diğer'))!), isTrue);
    expect(digerMi((await bul('Market'))!), isFalse);
  });

  test('yarıda hata olursa hiçbir şey değişmez (tek transaction)', () async {
    await ekle(1, 1000);
    await ekle(2, 700);
    await db.limitKoy(1, 50000);
    // Son adım (kategoriyi silme) başarısız olsun: taşıma ve limit silme geri alınmalı.
    await db.customStatement(
      "CREATE TRIGGER engel BEFORE DELETE ON categories "
      "BEGIN SELECT RAISE(ABORT, 'engel'); END",
    );
    await expectLater(db.kategoriSil(1), throwsA(anything));

    expect(await db.kategoriIslemSayisi(1), 1);
    expect(await db.kategoriIslemSayisi(9), 0);
    expect(await db.limitOku(1), 50000);
    expect(await bul('Market'), isNotNull);
    expect(
      await (db.select(
        db.keywordHits,
      )..where((k) => k.categoryId.equals(1))).get(),
      isNotEmpty,
    );
    expect(await kategoriIdleri(1), hasLength(1));
  });
}
