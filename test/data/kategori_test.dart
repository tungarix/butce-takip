import 'package:butce_takip/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> ekle(int gun, int tutar, {bool gelir = false, int kat = 1}) => db.islemEkle(
    tutarKurus: tutar,
    gelir: gelir,
    kategoriId: gelir ? 10 : kat,
    not: '',
    gun: gun,
  );

  Future<Map<int, int>> toplam(int ay) => db.ayGiderToplamlariniIzle(ay).first;

  Future<Category> kategori(int id) =>
      (db.select(db.categories)..where((x) => x.id.equals(id))).getSingle();

  group('ay toplamı', () {
    test('kategori bazında toplar, gelir hariç', () async {
      await ekle(20260310, 1000, kat: 1);
      await ekle(20260311, 2500, kat: 1);
      await ekle(20260312, 700, kat: 2);
      await ekle(20260312, 500000, gelir: true);
      expect(await toplam(202603), {1: 3500, 2: 700});
      expect(await db.ayGelirToplaminiIzle(202603).first, 500000);
    });

    test('ay sınırı: ilk ve son gün dahil, komşu aylar hariç', () async {
      await ekle(20260228, 111);
      await ekle(20260301, 100);
      await ekle(20260331, 200);
      await ekle(20260401, 999);
      expect(await toplam(202603), {1: 300});
      expect(await toplam(202602), {1: 111});
      expect(await toplam(202605), isEmpty);
      expect(await db.ayGelirToplaminiIzle(202605).first, 0);
    });

    test('arşivli kategorinin harcaması dahil; sum(kategori) == genel toplam', () async {
      await ekle(20260310, 1000, kat: 1);
      await ekle(20260311, 4000, kat: 2);
      await db.kategoriArsivle(2, arsivli: true);
      final t = await toplam(202603);
      expect(t, {1: 1000, 2: 4000});
      final genel = (await db.ayIslemleriniIzle(202603).first)
          .where((x) => !x.isIncome)
          .fold<int>(0, (a, x) => a + x.amountKurus);
      expect(t.values.fold<int>(0, (a, b) => a + b), genel);
    });
  });

  group('kategori yönetimi', () {
    test('ekle: temizlenmiş ad, sona sıra, arşivli değil', () async {
      final id = await db.kategoriEkle(ad: '  Kedi maması ', simge: 12, gelir: false);
      final c = await kategori(id);
      expect(
        (c.name, c.icon, c.isIncome, c.sortOrder, c.archived),
        ('Kedi maması', 12, false, 10, false),
      );
    });

    test('aynı ad reddedilir: büyük/küçük harf, kenar boşluğu, Türkçe İ/ı', () async {
      for (final ad in ['market', 'MARKET', '  Market  ', 'sağlık', 'SAĞLIK']) {
        await expectLater(
          db.kategoriEkle(ad: ad, simge: 0, gelir: false),
          throwsA(isA<KategoriAdiHatasi>().having((e) => e.neden, 'neden', AdHatasi.ayni)),
          reason: ad,
        );
      }
      await db.kategoriEkle(ad: 'Işık', simge: 0, gelir: false);
      await expectLater(
        db.kategoriEkle(ad: 'ışık', simge: 0, gelir: false),
        throwsA(isA<KategoriAdiHatasi>()),
      );
      await db.kategoriEkle(ad: 'İz', simge: 0, gelir: false);
      await expectLater(
        db.kategoriEkle(ad: 'iz', simge: 0, gelir: false),
        throwsA(isA<KategoriAdiHatasi>()),
      );
      // Ad tablo genelinde tekil: gelir kategorisinin adı da çakışır.
      await expectLater(
        db.kategoriEkle(ad: 'maaş', simge: 0, gelir: false),
        throwsA(isA<KategoriAdiHatasi>()),
      );
    });

    test('arşivli kategorinin adı da çakışır', () async {
      await db.kategoriArsivle(1, arsivli: true);
      await expectLater(
        db.kategoriEkle(ad: 'market', simge: 0, gelir: false),
        throwsA(isA<KategoriAdiHatasi>()),
      );
    });

    test('boş ad reddedilir', () async {
      await expectLater(
        db.kategoriEkle(ad: '   ', simge: 0, gelir: false),
        throwsA(isA<KategoriAdiHatasi>().having((e) => e.neden, 'neden', AdHatasi.bos)),
      );
    });

    test('yeniden adlandır: kendi adını harf farkıyla alabilir, başkasınınkini alamaz', () async {
      await db.kategoriGuncelle(1, ad: 'MARKET', simge: 3);
      var c = await kategori(1);
      expect((c.name, c.icon), ('MARKET', 3));
      await expectLater(
        db.kategoriGuncelle(1, ad: ' ulaşım', simge: 3),
        throwsA(isA<KategoriAdiHatasi>()),
      );
      await db.kategoriGuncelle(1, ad: 'Çarşı', simge: 3);
      c = await kategori(1);
      expect(c.name, 'Çarşı');
    });

    test('arşivle ve geri çıkar; kategori satırı silinmez, işlemler durur', () async {
      await ekle(20260310, 1000);
      await db.kategoriArsivle(1, arsivli: true);
      expect((await db.select(db.categories).get()).where((c) => c.archived).map((c) => c.id), [1]);
      expect(await db.select(db.categories).get(), hasLength(10));
      expect(await db.select(db.transactions).get(), hasLength(1));
      await db.kategoriArsivle(1, arsivli: false);
      expect((await db.select(db.categories).get()).any((c) => c.archived), isFalse);
    });

    test('işlemi olan kategori veritabanında da silinemez (dış anahtar)', () async {
      await ekle(20260310, 1000);
      await expectLater(
        (db.delete(db.categories)..where((c) => c.id.equals(1))).go(),
        throwsA(anything),
      );
    });
  });

  group('limit', () {
    Future<Map<int, int>> limitler() => db.limitleriIzle().first;

    test('koy, değiştir, kaldır', () async {
      expect(await limitler(), isEmpty);
      await db.limitKoy(1, 500000);
      await db.limitKoy(2, 100000);
      expect(await limitler(), {1: 500000, 2: 100000});
      await db.limitKoy(1, 750000);
      expect(await limitler(), {1: 750000, 2: 100000});
      expect(await db.select(db.budgets).get(), hasLength(2), reason: 'değiştirme satır eklemez');
      await db.limitKaldir(1);
      expect(await limitler(), {2: 100000});
      await db.limitKaldir(1); // olmayanı kaldırmak hata değil
      expect(await limitler(), {2: 100000});
    });

    test('0 ya da eksi limit reddedilir', () {
      expect(() => db.limitKoy(1, 0), throwsArgumentError);
      expect(() => db.limitKoy(1, -5), throwsArgumentError);
    });

    test('olmayan kategoriye limit dış anahtarla reddedilir', () async {
      await expectLater(db.limitKoy(999, 100), throwsA(anything));
    });
  });
}
