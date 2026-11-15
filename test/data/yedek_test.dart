import 'dart:convert';
import 'dart:io';

import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/yedek.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> doldur(AppDatabase db) async {
  final ozel = await db.kategoriEkle(ad: 'Hobi', simge: 3, gelir: false);
  await db.islemEkle(
    tutarKurus: 12350,
    gelir: false,
    kategoriId: 1,
    not: "Migros'a",
    gun: 20260305,
  );
  await db.islemEkle(
    tutarKurus: 99,
    gelir: false,
    kategoriId: ozel,
    not: '',
    gun: 20260228,
  );
  await db.islemEkle(
    tutarKurus: 5000000,
    gelir: true,
    kategoriId: 10,
    not: 'Maaş',
    gun: 20260301,
  );
  await db.limitKoy(1, 500000);
  await db.kategoriArsivle(2, arsivli: true);
  await db.ayarYaz('bildirim_acik', '0');
}

/// Tablo içeriğinin tam dökümü (olusturuldu sabit): iki veritabanı birebir eşit mi.
Future<String> dokum(AppDatabase db) => yedekOlustur(db, simdi: 1);

Future<int> toplam(AppDatabase db, bool gelir) async {
  final l = await db.select(db.transactions).get();
  return l
      .where((t) => t.isIncome == gelir)
      .fold<int>(0, (a, t) => a + t.amountKurus);
}

// Sabit yedek: iki kategorili küçük veri, veritabanından bağımsız.
const yedekMetniSabit =
    '{"uygulama":"butce-takip","schemaVersion":1,"olusturuldu":1000,'
    '"categories":[{"id":1,"name":"Market","icon":0,"isIncome":false,"sortOrder":0,"archived":false},'
    '{"id":2,"name":"Maaş","icon":9,"isIncome":true,"sortOrder":1,"archived":false}],'
    '"transactions":[{"id":1,"amountKurus":1000,"isIncome":false,"categoryId":1,"note":"a","noteNorm":"a","day":20260305,"createdAt":5},'
    '{"id":2,"amountKurus":2000,"isIncome":true,"categoryId":2,"note":"","noteNorm":"","day":20260306,"createdAt":6}],'
    '"budgets":[{"categoryId":1,"monthlyLimitKurus":5000}],'
    '"keyword_hits":[{"keyword":"migros","categoryId":1,"hits":2}],'
    '"settings":[{"key":"bildirim_acik","value":"1"}]}';

Map<String, dynamic> temel() =>
    jsonDecode(yedekMetniSabit) as Map<String, dynamic>;

String islemAlan(String alan, Object? deger) {
  final m = temel();
  (m['transactions'] as List).first[alan] = deger;
  return jsonEncode(m);
}

void main() {
  // İki bellek içi veritabanı bilerek aynı anda açık.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase kaynak;
  late AppDatabase hedef;

  setUp(() async {
    kaynak = AppDatabase(NativeDatabase.memory());
    hedef = AppDatabase(NativeDatabase.memory());
    await doldur(kaynak);
    // Hedef farklı: kendi işlemi ve ayarı var.
    await hedef.islemEkle(
      tutarKurus: 777,
      gelir: false,
      kategoriId: 3,
      not: 'eski',
      gun: 20250101,
    );
    await hedef.ayarYaz('eski_ayar', 'x');
  });
  tearDown(() async {
    await kaynak.close();
    await hedef.close();
  });

  test(
    'gidiş-dönüş: farklı veritabanına içe aktarınca tüm tablolar birebir eşit',
    () async {
      final json = await dokum(kaynak);
      final y = yedekDogrula(json, guncelSurum: hedef.schemaVersion);
      expect(y.transactions, hasLength(3));
      await yedegiUygula(hedef, y);

      expect(await dokum(hedef), json);
      expect(await toplam(hedef, false), await toplam(kaynak, false));
      expect(await toplam(hedef, true), 5000000);
      expect(
        (await hedef.select(hedef.transactions).get()).map((t) => t.id),
        (await kaynak.select(kaynak.transactions).get()).map((t) => t.id),
      );
      expect(await hedef.ayarOku('eski_ayar'), isNull);
      final islemler = jsonDecode(json)['transactions'] as List;
      expect(islemler.every((t) => t['amountKurus'] is int), isTrue);
    },
  );

  test('gidiş-dönüş: tohumsuz boş veritabanına da yazılır', () async {
    final y = yedekDogrula(await dokum(kaynak), guncelSurum: 1);
    await yedegiUygula(hedef, y);
    // İkinci kez uygulamak da aynı sonucu verir (yerine geçer, birleşmez).
    await yedegiUygula(hedef, y);
    expect(await dokum(hedef), await dokum(kaynak));
  });

  group('reddedilenler: veritabanı değişmez', () {
    final reddedilecekler = <String, String Function()>{
      'bozuk JSON': () => '{"uygulama": ',
      'JSON ama nesne değil': () => '[1,2]',
      'yanlış uygulama alanı': () =>
          jsonEncode(temel()..['uygulama'] = 'baska'),
      'uygulama alanı yok': () => jsonEncode(temel()..remove('uygulama')),
      'daha yeni schemaVersion': () =>
          jsonEncode(temel()..['schemaVersion'] = 2),
      'schemaVersion yok': () => jsonEncode(temel()..remove('schemaVersion')),
      'olusturuldu yok': () => jsonEncode(temel()..remove('olusturuldu')),
      'tablo yok': () => jsonEncode(temel()..remove('budgets')),
      'işlemde alan eksik': () {
        final m = temel();
        (m['transactions'] as List).first.remove('amountKurus');
        return jsonEncode(m);
      },
      'tutar negatif': () => islemAlan('amountKurus', -5),
      'tutar sıfır': () => islemAlan('amountKurus', 0),
      'tutar ondalıklı': () => islemAlan('amountKurus', 10.5),
      'tutar metin': () => islemAlan('amountKurus', '100'),
      'geçersiz gün (30 Şubat)': () => islemAlan('day', 20260230),
      'geçersiz gün (13. ay)': () => islemAlan('day', 20261301),
      'geçersiz gün (sıfır)': () => islemAlan('day', 0),
      'olmayan kategoriye işlem': () => islemAlan('categoryId', 9999),
      'olmayan kategoriye limit': () {
        final m = temel();
        (m['budgets'] as List).first['categoryId'] = 9999;
        return jsonEncode(m);
      },
      'yinelenen kategori adı': () {
        final m = temel();
        final k = m['categories'] as List;
        k[1]['name'] = k[0]['name'];
        return jsonEncode(m);
      },
      'yinelenen işlem numarası': () {
        final m = temel();
        final t = m['transactions'] as List;
        t[1]['id'] = t[0]['id'];
        return jsonEncode(m);
      },
    };

    for (final e in reddedilecekler.entries) {
      test(e.key, () async {
        final once = await dokum(hedef);
        final metin = e.value();
        expect(
          () => yedekDogrula(metin, guncelSurum: hedef.schemaVersion),
          throwsA(isA<YedekHatasi>()),
        );
        expect(await dokum(hedef), once);
      });
    }

    test('sabit yedek geçerli (olumsuz testlerin temeli sağlam)', () {
      final y = yedekDogrula(yedekMetniSabit, guncelSurum: 1);
      expect(y.transactions, hasLength(2));
    });

    test('daha yeni sürüm Türkçe açıklamayla reddedilir', () {
      expect(
        () => yedekDogrula(
          jsonEncode(temel()..['schemaVersion'] = 2),
          guncelSurum: 1,
        ),
        throwsA(
          isA<YedekHatasi>().having(
            (e) => e.mesaj,
            'mesaj',
            contains('daha yeni'),
          ),
        ),
      );
    });
  });

  test(
    'uygulama sırasında hata olursa eski veri durur (transaction geri alınır)',
    () async {
      final once = await dokum(hedef);
      final temiz = yedekDogrula(await dokum(kaynak), guncelSurum: 1);
      // Doğrulamayı atlayan bozuk yedek: son işlem olmayan kategoriye bağlı, dış anahtar patlar.
      final bozuk = Yedek(
        schemaVersion: 1,
        olusturuldu: 1,
        categories: temiz.categories,
        transactions: [
          ...temiz.transactions,
          {...temiz.transactions.first, 'id': 9000, 'categoryId': 9999},
        ],
        budgets: temiz.budgets,
        keywordHits: temiz.keywordHits,
        settings: temiz.settings,
      );
      await expectLater(yedegiUygula(hedef, bozuk), throwsA(anything));
      expect(await dokum(hedef), once);
    },
  );

  test(
    'geri yüklemeden önce veritabanı kopyası alınır ve üstüne yazılır',
    () async {
      final dizin = Directory.systemTemp.createTempSync('butce_yedek_');
      addTearDown(() => dizin.deleteSync(recursive: true));
      final kopya = '${dizin.path}${Platform.pathSeparator}onceki.sqlite';
      final y = yedekDogrula(await dokum(kaynak), guncelSurum: 1);

      await yedegiUygula(hedef, y, kopyaYolu: kopya); // hedefin eski hali
      var k = AppDatabase(NativeDatabase(File(kopya)));
      expect((await k.select(k.transactions).get()).map((t) => t.note), [
        'eski',
      ]);
      await k.close();

      await yedegiUygula(
        hedef,
        y,
        kopyaYolu: kopya,
      ); // ikincide kaynağın verisi
      k = AppDatabase(NativeDatabase(File(kopya)));
      expect(await k.select(k.transactions).get(), hasLength(3));
      await k.close();
    },
  );

  group('yedekHatirlatilsin', () {
    final ilk = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    int gun(int n) => gunEkle(20260101, n);

    bool soru({
      int sayi = 1,
      required int bugun,
      int? sonYedek,
      int? ilkIslem,
      int? erteleme,
    }) => yedekHatirlatilsin(
      islemSayisi: sayi,
      bugun: bugun,
      sonYedekMs: sonYedek,
      ilkIslemMs: ilkIslem,
      ertelemeGunu: erteleme,
    );

    test('hiç yedek yok: ilk işlemden 29/30 gün hayır, 31 gün evet', () {
      expect(soru(bugun: gun(29), ilkIslem: ilk), isFalse);
      expect(soru(bugun: gun(30), ilkIslem: ilk), isFalse);
      expect(soru(bugun: gun(31), ilkIslem: ilk), isTrue);
    });

    test('son yedek varsa ona bakılır, ilk işlem değil', () {
      expect(soru(bugun: gun(200), sonYedek: ilk, ilkIslem: ilk), isTrue);
      final yeni = DateTime(2026, 6, 1).millisecondsSinceEpoch;
      expect(soru(bugun: 20260620, sonYedek: yeni, ilkIslem: ilk), isFalse);
      expect(soru(bugun: 20260702, sonYedek: yeni, ilkIslem: ilk), isTrue);
    });

    test('işlem yok: hatırlatma yok', () {
      expect(soru(sayi: 0, bugun: gun(400), sonYedek: ilk), isFalse);
    });

    test('ertelenmiş: erteleme gününe kadar yok, o gün yeniden', () {
      expect(soru(bugun: gun(40), ilkIslem: ilk, erteleme: gun(47)), isFalse);
      expect(soru(bugun: gun(46), ilkIslem: ilk, erteleme: gun(47)), isFalse);
      expect(soru(bugun: gun(47), ilkIslem: ilk, erteleme: gun(47)), isTrue);
    });
  });
}
