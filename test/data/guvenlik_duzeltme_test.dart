import 'dart:convert';

import 'package:butce_takip/akilli/tekrar_tespit.dart';
import 'package:butce_takip/akilli/uyari.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/yedek.dart';
import 'package:butce_takip/platform/guncelleme/ayarlar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Tohum: 1 Market, 2 Ulaşım, 9 Diğer, 10 Maaş.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Set<String>> anahtarlar() async => {
    for (final s in await db.select(db.settings).get()) s.key,
  };

  Future<Transaction> islemEkle(int kat) async {
    final id = await db.islemEkle(
      tutarKurus: 12345,
      gelir: false,
      kategoriId: kat,
      not: 'deneme',
      gun: 20260310,
    );
    return (db.select(
      db.transactions,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  Matcher ayrilmis() => throwsA(
    isA<KategoriAdiHatasi>().having((e) => e.neden.name, 'neden', 'ayrilmis'),
  );

  group('yedek: cihaza özel update_ anahtarları', () {
    Yedek yedekten(Map<String, String> ayarlar) {
      final k = jsonDecode(
        '{"uygulama":"butce-takip","schemaVersion":1,"olusturuldu":1700000000000,'
        '"categories":[{"id":1,"name":"Market","icon":0,"isIncome":false,"sortOrder":0,"archived":false}],'
        '"transactions":[],"budgets":[],"keyword_hits":[],"settings":[]}',
      ) as Map<String, Object?>;
      k['settings'] = [
        for (final e in ayarlar.entries) {'key': e.key, 'value': e.value},
      ];
      return yedekDogrula(jsonEncode(k), guncelSurum: 1);
    }

    test('dışa aktarılan JSON\'da update_ anahtarı yok', () async {
      await db.ayarYaz(guncellemeDenetimiAnahtari, '1');
      await db.ayarYaz(guncellemeKaydiAnahtari, '{}');
      await db.ayarYaz(guncellemeYalnizWifiAnahtari, '0');
      await db.ayarYaz('bildirim_acik', '0');
      final json = jsonDecode(await yedekOlustur(db)) as Map<String, Object?>;
      final anahtar = [
        for (final s in json['settings']! as List) (s as Map)['key'],
      ];
      expect(anahtar, ['bildirim_acik']);
    });

    test('yedekteki update_check cihazdakini değiştirmez, silinmez', () async {
      await db.ayarYaz(guncellemeDenetimiAnahtari, '0');
      await db.ayarYaz('bildirim_acik', '0');
      await yedegiUygula(
        db,
        yedekten({guncellemeDenetimiAnahtari: '1', 'bildirim_acik': '1'}),
      );
      expect(await db.ayarOku(guncellemeDenetimiAnahtari), '0');
      expect(await db.ayarOku('bildirim_acik'), '1');
    });

    test('cihazda değer yoksa yedekten de gelmez', () async {
      await yedegiUygula(
        db,
        yedekten({
          guncellemeDenetimiAnahtari: '1',
          guncellemeKaydiAnahtari: '{}',
          guncellemeYalnizWifiAnahtari: '0',
        }),
      );
      expect(await anahtarlar(), isEmpty);
    });
  });

  group('Geri al kategori silinmişken', () {
    test('işlem Diğer\'e, aynı id ve tutarla döner', () async {
      final t = await islemEkle(1);
      await db.islemSil(t.id);
      await db.kategoriSil(1);
      await db.islemGeriYukle(t);
      final l = await db.select(db.transactions).get();
      expect(l, hasLength(1));
      expect(l.single.id, t.id);
      expect(l.single.amountKurus, 12345);
      expect(l.single.createdAt, t.createdAt);
      expect(l.single.categoryId, 9);
    });

    test('Diğer yoksa oluşturulur', () async {
      await db.kategoriGuncelle(9, ad: 'Başka', simge: 8);
      final t = await islemEkle(1);
      await db.islemSil(t.id);
      await db.kategoriSil(1);
      await db.islemGeriYukle(t);
      final hedef = await (db.select(
        db.categories,
      )..where((c) => c.name.equals('Diğer'))).getSingle();
      expect(
        (await db.select(db.transactions).get()).single.categoryId,
        hedef.id,
      );
    });

    test('kategori duruyorsa olduğu yere döner', () async {
      final t = await islemEkle(2);
      await db.islemSil(t.id);
      await db.islemGeriYukle(t);
      expect((await db.select(db.transactions).get()).single.categoryId, 2);
    });
  });

  test('kategoriSil yalnız o kategorinin alert_ ve tekrar_red_k: anahtarlarını siler', () async {
    await db.kategoriEkle(ad: 'On bir', simge: 1, gelir: false); // id 11
    final silinecek = [
      uyariAnahtari(1, 202603, 80),
      uyariAnahtari(1, 202603, 100),
      '$tekrarRedOnEki${tekrarAnahtari((kategoriId: 1, tutar: 500, noteNorm: '', not: '', gun: 20260301))}',
    ];
    final kalacak = [
      uyariAnahtari(11, 202603, 80),
      uyariAnahtari(2, 202603, 80),
      '$tekrarRedOnEki${tekrarAnahtari((kategoriId: 11, tutar: 500, noteNorm: '', not: '', gun: 20260301))}',
      '${tekrarRedOnEki}n:netflix',
      'bildirim_acik',
    ];
    for (final k in [...silinecek, ...kalacak]) {
      await db.ayarYaz(k, '1');
    }
    await db.kategoriSil(1);
    expect(await anahtarlar(), kalacak.toSet());
  });

  group('ayrılmış ad', () {
    test(
      'gelir kategorisine Diğer verilemez (ekleme, yeniden adlandırma)',
      () async {
        await expectLater(
          db.kategoriEkle(ad: ' diğer ', simge: 1, gelir: true),
          ayrilmis(),
        );
        await expectLater(
          db.kategoriGuncelle(10, ad: 'Diğer', simge: 1),
          ayrilmis(),
        );
      },
    );

    test(
      'gider kategorisine Diğer gelir verilemez (ekleme, yeniden adlandırma)',
      () async {
        await expectLater(
          db.kategoriEkle(ad: 'DİĞER GELİR', simge: 1, gelir: false),
          ayrilmis(),
        );
        await expectLater(
          db.kategoriGuncelle(1, ad: 'Diğer gelir', simge: 1),
          ayrilmis(),
        );
      },
    );

    test('kendi türünde ayrılmış ad serbest kalır', () async {
      await db.kategoriEkle(ad: 'Diğer gelir', simge: 9, gelir: true);
      await db.kategoriGuncelle(10, ad: 'Maaş 2', simge: 9);
    });

    test('çakışmalı yedek verisinde kategoriSil anlaşılır hata verir, veri değişmez', () async {
      await db.kategoriGuncelle(9, ad: 'Başka', simge: 8);
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              name: 'Diğer',
              icon: 1,
              isIncome: const Value(true),
              sortOrder: 99,
            ),
          );
      await islemEkle(1);
      final once = await yedekOlustur(db, simdi: 1700000000000);
      await expectLater(db.kategoriSil(1), ayrilmis());
      expect(await yedekOlustur(db, simdi: 1700000000000), once);
    });
  });
}
