import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:butce_takip/data/yedek.dart';
import 'package:butce_takip/platform/yedek_dosyasi.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

/// Dosya seçici ve paylaşım sayfası yerine geçer.
class SahteYedekDosyasi implements YedekDosyasi {
  SahteYedekDosyasi({this.secilen});

  String? secilen;
  final paylasilan = <String>[];
  final adlar = <String>[];
  bool paylasildi = true;

  @override
  Future<String?> sec() async => secilen;

  @override
  Future<bool> paylas(String json, String dosyaAdi) async {
    paylasilan.add(json);
    adlar.add(dosyaAdi);
    return paylasildi;
  }

  @override
  Future<String?> kopyaYolu() async => null;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  const bugun = 20260320;
  final bugunSabit = bugunProvider.overrideWithValue(bugun);

  Future<void> islem(WidgetTester t, AppDatabase db, int gun, int tutar) =>
      t.runAsync(
        () => db.islemEkle(
          tutarKurus: tutar,
          gelir: false,
          kategoriId: 1,
          not: '',
          gun: gun,
        ),
      );

  Future<int> islemSayisi(WidgetTester t, AppDatabase db) =>
      t.runAsync(() => db.select(db.transactions).get()).then((v) => v!.length);

  group('geri yükleme', () {
    uiTest(
      'onay penceresi yedeğin özetini gösterir; vazgeçince veri değişmez',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        final kaynak = await bellekDb(t);
        await islem(t, kaynak, 20260305, 1000);
        await islem(t, kaynak, 20260306, 2000);
        await islem(t, db, 20260310, 500);
        final json = (await t.runAsync(
          () => yedekOlustur(
            kaynak,
            simdi: DateTime(2026, 3, 7).millisecondsSinceEpoch,
          ),
        ))!;
        final dosya = SahteYedekDosyasi(secilen: json);
        await uygulamaAc(
          t,
          db,
          ekstra: [bugunSabit, yedekDosyasiProvider.overrideWithValue(dosya)],
        );
        await t.tap(find.text(sekmeAyarlar).first);
        await bekle(t);
        await t.tap(find.byKey(const ValueKey('geri-yukle')));
        await bekle(t);

        expect(
          find.text(yedekOzeti(2, 10, '7 Mart 2026')),
          findsOneWidget,
          reason: 'N işlem, M kategori, tarih ve uyarı',
        );
        await t.tap(find.text(vazgecEtiket));
        await bekle(t);
        expect(find.text(geriYuklemeBaslik), findsNothing);
        expect(await islemSayisi(t, db), 1, reason: 'iptalde veri aynı');
      },
    );

    uiTest('onaylanınca veri yedekle değişir ve sonuç bildirilir', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      final kaynak = await bellekDb(t);
      await islem(t, kaynak, 20260305, 1000);
      await islem(t, db, 20260310, 500);
      final json = (await t.runAsync(() => yedekOlustur(kaynak)))!;
      await uygulamaAc(
        t,
        db,
        ekstra: [
          bugunSabit,
          yedekDosyasiProvider.overrideWithValue(
            SahteYedekDosyasi(secilen: json),
          ),
        ],
      );
      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('geri-yukle')));
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('geri-yukle-onay')));
      await bekle(t);

      expect(find.text(geriYuklendi), findsOneWidget);
      final l = (await t.runAsync(() => db.select(db.transactions).get()))!;
      expect(l.map((x) => x.amountKurus), [1000]);
      expect(await t.runAsync(() => db.ayarOku(sonYedekAnahtari)), isNotNull);
    });

    uiTest('bozuk dosya: mesaj neyin yanlış olduğunu söyler, veri değişmez', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await islem(t, db, 20260310, 500);
      await uygulamaAc(
        t,
        db,
        ekstra: [
          bugunSabit,
          yedekDosyasiProvider.overrideWithValue(
            SahteYedekDosyasi(
              secilen: '{"uygulama":"baska","schemaVersion":1,"olusturuldu":1}',
            ),
          ),
        ],
      );
      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('geri-yukle')));
      await bekle(t);

      expect(find.text('Bu dosya Bütçe Takip yedeği değil.'), findsOneWidget);
      expect(find.text(geriYuklemeBaslik), findsNothing);
      expect(await islemSayisi(t, db), 1);
    });
  });

  group('yedekle', () {
    uiTest('paylaşılınca dosya adı tarihli, son yedek zamanı yazılır', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await islem(t, db, 20260310, 500);
      final dosya = SahteYedekDosyasi();
      await uygulamaAc(
        t,
        db,
        ekstra: [bugunSabit, yedekDosyasiProvider.overrideWithValue(dosya)],
      );
      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('yedekle')));
      await bekle(t);

      expect(dosya.paylasilan, hasLength(1));
      expect(dosya.adlar.single, matches(r'^butce-takip-yedek-\d{8}\.json$'));
      expect(await t.runAsync(() => db.ayarOku(sonYedekAnahtari)), isNotNull);
    });

    uiTest('paylaşım sayfası kapatılırsa son yedek zamanı yazılmaz', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      final dosya = SahteYedekDosyasi()..paylasildi = false;
      await uygulamaAc(
        t,
        db,
        ekstra: [bugunSabit, yedekDosyasiProvider.overrideWithValue(dosya)],
      );
      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('yedekle')));
      await bekle(t);

      expect(await t.runAsync(() => db.ayarOku(sonYedekAnahtari)), isNull);
    });
  });

  group('Özet hatırlatma kartı', () {
    uiTest('işlem yoksa ya da 30 gün geçmediyse görünmez', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.byKey(const ValueKey('yedek-karti')), findsNothing);
      // İlk işlemin kayıt zamanı gerçek saat (sabit günden sonra): 30 gün geçmedi.
      await islem(t, db, 20260310, 500);
      await bekle(t);
      expect(find.byKey(const ValueKey('yedek-karti')), findsNothing);
    });

    uiTest('31 gündür yedek yoksa görünür; Sonra 7 gün erteler', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await islem(t, db, 20260310, 500);
      await t.runAsync(
        () => db.ayarYaz(
          sonYedekAnahtari,
          '${DateTime(2026, 2, 17).millisecondsSinceEpoch}', // 20 Mart'tan 31 gün önce
        ),
      );
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.byKey(const ValueKey('yedek-karti')), findsOneWidget);
      expect(find.text(yedekHatirlatmaMetni), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('yedek-sonra')));
      await bekle(t);
      expect(find.byKey(const ValueKey('yedek-karti')), findsNothing);
      expect(
        await t.runAsync(() => db.ayarOku(yedekErtelemeAnahtari)),
        '20260327',
      );
    });

    uiTest('Yedekle düğmesi paylaşımı açar ve kart kalkar', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await islem(t, db, 20260310, 500);
      await t.runAsync(
        () => db.ayarYaz(
          sonYedekAnahtari,
          '${DateTime(2026, 2, 17).millisecondsSinceEpoch}',
        ),
      );
      final dosya = SahteYedekDosyasi();
      await uygulamaAc(
        t,
        db,
        ekstra: [bugunSabit, yedekDosyasiProvider.overrideWithValue(dosya)],
      );
      await t.tap(find.byKey(const ValueKey('yedek-yedekle')));
      await bekle(t);
      expect(dosya.paylasilan, hasLength(1));
      expect(find.byKey(const ValueKey('yedek-karti')), findsNothing);
    });
  });

  uiTest('uygulama öne gelince bugün yeniden hesaplanır', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    var simdi = 20260320;
    await uygulamaAc(
      t,
      db,
      ekstra: [bugunProvider.overrideWith((ref) => simdi)],
    );
    final kap = ProviderScope.containerOf(
      t.element(find.byType(Scaffold).first),
    );
    expect(kap.read(bugunProvider), 20260320);

    simdi = 20260321; // gece yarısı geçti
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await bekle(t);
    expect(kap.read(bugunProvider), 20260321);
  });
}
