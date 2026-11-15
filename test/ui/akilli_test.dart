import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:butce_takip/features/hizli_giris/hizli_giris.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  // Sabit "bugün": 20 Mart 2026 (Cuma). Özet bu ayı gösterir.
  const bugun = 20260320;
  final bugunSabit = bugunProvider.overrideWithValue(bugun);

  Future<void> gider(
    WidgetTester t,
    AppDatabase db,
    int gun,
    int tutar, {
    int kat = 1,
    String not = '',
  }) => t.runAsync(
    () => db.islemEkle(
      tutarKurus: tutar,
      gelir: false,
      kategoriId: kat,
      not: not,
      gun: gun,
    ),
  );

  Future<void> netflix(WidgetTester t, AppDatabase db) async {
    // 22 Ara, 21 Oca, 20 Şub: 30 günlük aralık -> beklenen 22 Mart (2 gün kaldı).
    for (final g in [20251222, 20260121, 20260220]) {
      await gider(t, db, g, 22999, kat: 8, not: 'Netflix');
    }
  }

  Future<int> islemSayisi(WidgetTester t, AppDatabase db) =>
      t.runAsync(() => db.select(db.transactions).get()).then((v) => v!.length);

  group('tahmin kartı', () {
    uiTest(
      'bu ay: "bu hızla ..." metni ve limit toplamı aşılınca nötr fark satırı',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        await gider(t, db, 20260310, 14000);
        await gider(t, db, 20260318, 14000);
        await t.runAsync(() => db.limitKoy(1, 10000));
        await uygulamaAc(t, db, ekstra: [bugunSabit]);

        // harcanan 28000 + kalan 11 gün * (28000 ~/ 14 = 2000) = 50000.
        expect(find.byKey(const ValueKey('tahmin-karti')), findsOneWidget);
        expect(find.text(tahminMetni('500,00 ₺')), findsOneWidget);
        expect(find.text(tahminLimitFarki('400,00 ₺')), findsOneWidget);
      },
    );

    uiTest('limit yoksa ya da tahmin limitin altındaysa fark satırı yok', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await gider(t, db, 20260310, 1400);
      await t.runAsync(() => db.limitKoy(1, 10000000));
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.byKey(const ValueKey('tahmin-metin')), findsOneWidget);
      expect(find.byKey(const ValueKey('tahmin-fark')), findsNothing);
    });

    uiTest('ayın ilk 5 gününde "Henüz yeterli veri yok"', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await gider(t, db, 20260302, 5000);
      await uygulamaAc(
        t,
        db,
        ekstra: [bugunProvider.overrideWithValue(20260305)],
      );
      expect(find.text(tahminYetersiz), findsOneWidget);
      expect(find.textContaining('yaklaşık'), findsNothing);
    });

    uiTest('geçmiş ve gelecek ay seçiliyken kart gösterilmez', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await gider(t, db, 20260310, 14000);
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.byKey(const ValueKey('tahmin-karti')), findsOneWidget);

      await t.tap(find.byTooltip(oncekiAyEtiket));
      await bekle(t);
      expect(find.byKey(const ValueKey('tahmin-karti')), findsNothing);

      await t.tap(find.byTooltip(sonrakiAyEtiket));
      await t.tap(find.byTooltip(sonrakiAyEtiket));
      await bekle(t);
      expect(find.byKey(const ValueKey('tahmin-karti')), findsNothing);
    });
  });

  group('tekrarlayan kartı', () {
    uiTest('3 kayıtlı aylık grup kartta görünür; 2 kayıtlıda görünmez', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await gider(t, db, 20260121, 22999, kat: 8, not: 'Spotify');
      await gider(t, db, 20260220, 22999, kat: 8, not: 'Spotify');
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.byKey(const ValueKey('tekrar-karti')), findsNothing);
      expect(find.text(tekrarBaslik), findsNothing);
    });

    uiTest(
      'kart: ad, tutar, beklenen gün; Ekle kaydetmez, önceden doldurulmuş giriş açar',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        await netflix(t, db);
        await uygulamaAc(t, db, ekstra: [bugunSabit]);

        expect(find.text(tekrarBaslik), findsOneWidget);
        expect(find.text('Netflix'), findsOneWidget);
        expect(
          find.text('229,99 ₺ · ${tekrarBeklenen('22 Mart')}'),
          findsOneWidget,
        );
        expect(await islemSayisi(t, db), 3);

        await t.tap(find.text(tekrarEkleEtiket));
        await bekle(t);
        expect(find.byType(HizliGirisSayfasi), findsOneWidget);
        expect(find.text('229,99 ₺'), findsWidgets);
        expect(
          t.widget<ChoiceChip>(find.byKey(const ValueKey('cip-8'))).selected,
          isTrue,
        );
        expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('not')))
              .controller!
              .text,
          'Netflix',
        );
        expect(
          await islemSayisi(t, db),
          3,
          reason: 'kullanıcı onaylamadan kayıt yok',
        );

        await t.tap(find.byKey(const ValueKey('kaydet')));
        await bekle(t);
        final satirlar = await t.runAsync(
          () => db.select(db.transactions).get(),
        );
        expect(satirlar, hasLength(4));
        final yeni = satirlar!.last;
        expect(
          (yeni.amountKurus, yeni.categoryId, yeni.note, yeni.isIncome),
          (22999, 8, 'Netflix', false),
        );
      },
    );

    uiTest('Gösterme kartı kaldırır ve kalıcı reddeder (yeniden açılınca da)', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await netflix(t, db);
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.text(tekrarBaslik), findsOneWidget);

      await t.tap(find.text(tekrarGosterme));
      await bekle(t);
      expect(find.text(tekrarBaslik), findsNothing);
      expect(
        await t.runAsync(() => db.ayarOku('${tekrarRedOnEki}n:netflix')),
        '1',
      );
      expect(await islemSayisi(t, db), 3);

      // Uygulamayı yeniden kur: ret settings'ten okunur.
      await t.pumpWidget(const SizedBox());
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      expect(find.text(tekrarBaslik), findsNothing);
    });
  });

  group('kategori önerisi', () {
    Future<void> notYaz(WidgetTester t, String not) async {
      await t.tap(find.byTooltip(islemEkleEtiket));
      await bekle(t);
      await t.tap(find.text(ayrintiEtiket));
      await bekle(t);
      await t.enterText(find.byKey(const ValueKey('not')), not);
      await bekle(t, 6); // debounce + sorgu
    }

    List<Key?> cipSirasi(WidgetTester t) => [
      for (final c in t.widgetList<ChoiceChip>(find.byType(ChoiceChip))) c.key,
    ];

    String? etiket(WidgetTester t, int id) => t
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('cip-$id')),
            matching: find.byType(Text),
          ),
        )
        .semanticsLabel;

    uiTest(
      'önerilen kategori çiplerin başına gelir, anlamsal etiketle işaretlenir, seçilmez',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        await uygulamaAc(t, db, ekstra: [bugunSabit]);
        await notYaz(t, 'Netflix aylık');

        expect(cipSirasi(t).first, const ValueKey('cip-8'));
        expect(etiket(t, 8), 'Abonelik, önerilen');
        expect(etiket(t, 1), 'Market');
        for (final c in t.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
          expect(c.selected, isFalse, reason: 'sessiz atama yok');
        }
        expect(await islemSayisi(t, db), 0);

        // Not silinince öneri kalkar, sıra eski haline döner.
        await t.enterText(find.byKey(const ValueKey('not')), '');
        await bekle(t, 6);
        expect(cipSirasi(t).first, const ValueKey('cip-1'));
        expect(find.byIcon(Icons.auto_awesome), findsNothing);
      },
    );

    uiTest(
      'çipe dokununca öneri değil dokunulan kategori kaydedilir; sayaç öğrenir',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        await uygulamaAc(t, db, ekstra: [bugunSabit]);
        await notYaz(t, 'Netflix');
        await t.tap(find.byKey(const ValueKey('tus-5')));
        await t.pump();
        await t.tap(
          find.byKey(const ValueKey('cip-1')),
        ); // Market (öneri Abonelik'ti)
        await bekle(t);
        final s = (await t.runAsync(() => db.select(db.transactions).get()))!
            .single;
        expect(s.categoryId, 1);
        final h = await t.runAsync(() => db.anahtarSatirlari(['netflix']));
        expect({for (final k in h!) k.categoryId: k.hits}, {8: 1, 1: 1});
      },
    );

    uiTest('arşivli kategori ve türü uymayan kategori önerilmez', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await t.runAsync(() => db.kategoriArsivle(8, arsivli: true));
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      await notYaz(t, 'Netflix');
      expect(
        cipSirasi(t).first,
        const ValueKey('cip-1'),
        reason: 'arşivli Abonelik önerilmez',
      );
      expect(find.byIcon(Icons.auto_awesome), findsNothing);

      // Gelir kategorisi (Maaş) gider girişinde önerilmez.
      await t.enterText(find.byKey(const ValueKey('not')), 'maaş');
      await bekle(t, 6);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
      expect(find.byKey(const ValueKey('cip-10')), findsNothing);
    });
  });

  group('bildirim ayarı', () {
    uiTest('anahtar settings\'e yazılır', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await uygulamaAc(t, db, ekstra: [bugunSabit]);
      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      expect(
        t
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('bildirim-anahtari')),
            )
            .value,
        isTrue,
      );
      await t.tap(find.byKey(const ValueKey('bildirim-anahtari')));
      await bekle(t);
      expect(await t.runAsync(() => db.ayarOku(bildirimAcikAnahtari)), '0');
      expect(
        t
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('bildirim-anahtari')),
            )
            .value,
        isFalse,
      );
    });
  });
}
