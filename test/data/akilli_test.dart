import 'package:butce_takip/akilli/kategori_onerici.dart';
import 'package:butce_takip/akilli/normalize.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/platform/bildirimler.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class SahteBildirim implements BildirimKapisi {
  final gosterilen = <({int id, String baslik, String govde})>[];
  int izinSayisi = 0;

  @override
  Future<void> goster({
    required int id,
    required String baslik,
    required String govde,
  }) async => gosterilen.add((id: id, baslik: baslik, govde: govde));

  @override
  Future<void> izinIste() async => izinSayisi++;
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> hits(String kelime, int kat) async {
    final l = await (db.select(
      db.keywordHits,
    )..where((k) => k.keyword.equals(kelime) & k.categoryId.equals(kat))).get();
    return l.isEmpty ? 0 : l.single.hits;
  }

  Future<int> ekle(
    String not,
    int kat, {
    int gun = 20260310,
    int tutar = 1000,
  }) => db.islemEkle(
    tutarKurus: tutar,
    gelir: false,
    kategoriId: kat,
    not: not,
    gun: gun,
  );

  group('anahtar kelime sayaçları', () {
    test('kayıtta notun her sözcüğüne +1; satır yoksa 1 ile eklenir; noteNorm yeni kuralla yazılır', () async {
      expect(await hits('migros', 1), 1, reason: 'tohum');
      await ekle("Migros ŞUBE'ye ODA 5", 1);
      expect(await hits('migros', 1), 2);
      expect(
        await hits('sube', 1),
        0,
        reason: "apostrof atılınca 'subeye' olur",
      );
      expect(await hits('subeye', 1), 1);
      expect(await hits('oda', 1), 1);
      expect(await hits('5', 1), 0);
      final t = await db.select(db.transactions).getSingle();
      expect(t.noteNorm, 'migros subeye oda');
    });

    test('aynı sözcük iki kez geçse bile işlem başına bir kez sayılır; boş not sayaç yazmaz', () async {
      await ekle('kafe kafe', 5);
      expect(await hits('kafe', 5), 2, reason: 'tohum 1 + 1');
      final once = (await db.select(db.keywordHits).get()).length;
      await ekle('  ', 5);
      await ekle('a 1', 5);
      expect((await db.select(db.keywordHits).get()).length, once);
    });

    test(
      'düzenlemede kategori değişirse yeni kategoriye +1, eskisinden düşülmez',
      () async {
        final id = await ekle('Migros', 1);
        expect(await hits('migros', 1), 2);
        await db.islemGuncelle(
          id,
          tutarKurus: 1000,
          gelir: false,
          kategoriId: 5,
          not: 'Migros',
          gun: 20260310,
        );
        expect(await hits('migros', 5), 1);
        expect(await hits('migros', 1), 2);
        // Kategori aynı kalırsa sayaç artmaz.
        await db.islemGuncelle(
          id,
          tutarKurus: 2000,
          gelir: false,
          kategoriId: 5,
          not: 'Migros',
          gun: 20260310,
        );
        expect(await hits('migros', 5), 1);
      },
    );

    test(
      'işlem ve sayaç tek transaction: işlem yazılamazsa sayaç da kalmaz',
      () async {
        final once = (await db.select(db.keywordHits).get()).length;
        await expectLater(
          ekle('Yenikelime', 999),
          throwsA(anything),
        ); // geçersiz kategori
        expect(await db.select(db.transactions).get(), isEmpty);
        expect((await db.select(db.keywordHits).get()).length, once);
      },
    );

    test('öğrenilen sözcük sonraki öneriyi etkiler', () async {
      for (var i = 0; i < 3; i++) {
        await ekle('Pideci Hasan', 5);
      }
      final sozcukler = notSozcukleri('Hasan usta');
      final satirlar = await db.anahtarSatirlari(sozcukler);
      final uygun = [
        for (final c in await (db.select(
          db.categories,
        )..orderBy([(c) => OrderingTerm.asc(c.sortOrder)])).get())
          c.id,
      ];
      final oneri = kategoriOner(sozcukler, [
        for (final k in satirlar)
          (keyword: k.keyword, categoryId: k.categoryId, hits: k.hits),
      ], uygun);
      expect(oneri, 5);
    });

    test('tohumdan öneri: Migros -> Market', () async {
      final sozcukler = notSozcukleri('Migros alışveriş');
      final satirlar = await db.anahtarSatirlari(sozcukler);
      final oneri = kategoriOner(
        sozcukler,
        [
          for (final k in satirlar)
            (keyword: k.keyword, categoryId: k.categoryId, hits: k.hits),
        ],
        [1, 2, 3],
      );
      expect(oneri, 1);
    });
  });

  group('aşım bildirimi (asimKontrol)', () {
    late SahteBildirim kapi;

    setUp(() async {
      kapi = SahteBildirim();
      await db.limitKoy(1, 10000); // Market 100,00 ₺
    });

    Future<void> harca(int tutar, {int gun = 20260310, int kat = 1}) async {
      final once = await db.ayKategoriGideri(kat, gun ~/ 100);
      await ekle('', kat, gun: gun, tutar: tutar);
      await asimKontrol(db, kapi, kategoriId: kat, gun: gun, once: once);
    }

    test(
      '%80 ve %100 ay + kategori + eşik başına bir kez; metin nötr',
      () async {
        await harca(7900);
        expect(kapi.gosterilen, isEmpty);
        await harca(100); // 79 -> 80
        expect(kapi.gosterilen.map((g) => g.govde), [
          "Market bütçesinin %80'i doldu",
        ]);
        await harca(500); // 80 -> 85
        expect(kapi.gosterilen, hasLength(1));
        await harca(1500); // 85 -> 100
        expect(kapi.gosterilen, hasLength(2));
        expect(kapi.gosterilen.last.govde, 'Market bütçesi doldu (%100)');
        await harca(100); // 100 -> 101
        expect(kapi.gosterilen, hasLength(2));
        await harca(100000, gun: 20260311);
        expect(kapi.gosterilen, hasLength(2));
        expect(await db.ayarOku('alert_1_202603_80'), '1');
        expect(await db.ayarOku('alert_1_202603_100'), '1');
      },
    );

    test('doğrudan 0 -> 120: yalnız bir bildirim (%100)', () async {
      await harca(12000);
      expect(kapi.gosterilen, hasLength(1));
      expect(kapi.gosterilen.single.govde, contains('doldu (%100)'));
      expect(
        await db.ayarOku('alert_1_202603_80'),
        '1',
        reason: '%80 eşiği de işaretlendi',
      );
      expect(await db.ayarOku('alert_1_202603_100'), '1');
    });

    test('yeni ayda yeniden bildirilir', () async {
      await harca(9000); // Mart: 90% -> %80
      await harca(9000, gun: 20260401); // Nisan
      expect(kapi.gosterilen, hasLength(2));
    });

    test(
      'bildirim kapalıyken ve limit yokken bildirim yok; gelir sayılmaz',
      () async {
        await db.ayarYaz(bildirimAcikAnahtari, '0');
        await harca(12000);
        expect(kapi.gosterilen, isEmpty);
        await db.ayarYaz(bildirimAcikAnahtari, '1');
        await harca(12000, kat: 2); // Ulaşım'ın limiti yok
        expect(kapi.gosterilen, isEmpty);
      },
    );

    test('düzenleme: tutar artırılıp eşik aşılırsa bildirilir', () async {
      final id = await ekle('', 1, tutar: 5000);
      const gun = 20260310;
      final once = await db.ayKategoriGideri(1, gun ~/ 100);
      await db.islemGuncelle(
        id,
        tutarKurus: 8500,
        gelir: false,
        kategoriId: 1,
        not: '',
        gun: gun,
      );
      await asimKontrol(db, kapi, kategoriId: 1, gun: gun, once: once);
      expect(kapi.gosterilen.single.govde, contains('%80'));
    });

    test('izin yalnız bir kez istenir, bildirim kapalıysa istenmez', () async {
      await izinIsteIlkKez(db, kapi);
      await izinIsteIlkKez(db, kapi);
      expect(kapi.izinSayisi, 1);
      final kapali = SahteBildirim();
      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await db2.ayarYaz(bildirimAcikAnahtari, '0');
      await izinIsteIlkKez(db2, kapali);
      expect(kapali.izinSayisi, 0);
    });
  });
}
