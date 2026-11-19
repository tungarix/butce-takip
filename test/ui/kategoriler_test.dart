import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  Future<void> kategorilerAc(WidgetTester t, AppDatabase db) async {
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);
    await t.tap(find.text(kategorilerBaslik));
    await bekle(t);
  }

  Future<List<Category>> kategoriler(WidgetTester t, AppDatabase db) =>
      t.runAsync(() => db.select(db.categories).get()).then((v) => v!);

  Future<void> ekleDialogu(
    WidgetTester t,
    String tooltip,
    String ad, {
    int? simge,
  }) async {
    await t.tap(find.byTooltip(tooltip));
    await bekle(t);
    await t.enterText(find.byKey(const ValueKey('kategori-ad')), ad);
    if (simge != null) {
      await t.ensureVisible(find.byKey(ValueKey('simge-$simge')));
      await t.tap(find.byKey(ValueKey('simge-$simge')));
      await t.pump();
    }
    await t.tap(find.byKey(const ValueKey('kategori-kaydet')));
    await bekle(t);
  }

  uiTest('gider ve gelir kategorisi eklenir (ad, simge, tür doğru)', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await kategorilerAc(t, db);

    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Maaş'), findsOneWidget);

    await ekleDialogu(t, giderKategorisiEkle, '  Kedi maması ', simge: 12);
    await ekleDialogu(t, gelirKategorisiEkle, 'Burs', simge: 19);

    final liste = await kategoriler(t, db);
    final kedi = liste.singleWhere((c) => c.name == 'Kedi maması');
    expect((kedi.icon, kedi.isIncome, kedi.archived), (12, false, false));
    final burs = liste.singleWhere((c) => c.name == 'Burs');
    expect((burs.icon, burs.isIncome), (19, true));
    expect(find.text('Kedi maması'), findsOneWidget);
  });

  uiTest('aynı ad (harf ve boşluk farkıyla) Türkçe hata verir, kayıt olmaz', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await kategorilerAc(t, db);

    await ekleDialogu(t, giderKategorisiEkle, '  MARKET ');
    expect(find.text(adAyni), findsOneWidget);
    expect(await kategoriler(t, db), hasLength(10));

    await t.enterText(find.byKey(const ValueKey('kategori-ad')), '   ');
    await t.tap(find.byKey(const ValueKey('kategori-kaydet')));
    await bekle(t);
    expect(find.text(adBos), findsOneWidget);
  });

  uiTest('yeniden adlandırma ve simge değiştirme', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await kategorilerAc(t, db);

    await t.tap(find.byKey(const ValueKey('kategori-2')));
    await bekle(t);
    expect(find.text(kategoriDuzenleBaslik), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('kategori-ad')), 'Yol');
    await t.ensureVisible(find.byKey(const ValueKey('simge-14')));
    await t.tap(find.byKey(const ValueKey('simge-14')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('kategori-kaydet')));
    await bekle(t);

    final c = (await kategoriler(t, db)).singleWhere((c) => c.id == 2);
    expect((c.name, c.icon), ('Yol', 14));
    expect(find.text('Yol'), findsOneWidget);
  });

  uiTest(
    'arşivle: yeni girişte çip yok, eski işlemde adı görünür; arşivden çıkar geri getirir',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await t.runAsync(
        () => db.islemEkle(
          tutarKurus: 1234,
          gelir: false,
          kategoriId: 1,
          not: 'eski',
          gun: gunAnahtari(DateTime.now()),
        ),
      );
      await kategorilerAc(t, db);

      await t.tap(find.byKey(const ValueKey('arsiv-1')));
      await bekle(t);
      expect(
        (await kategoriler(t, db)).singleWhere((c) => c.id == 1).archived,
        isTrue,
      );
      expect(await kategoriler(t, db), hasLength(10), reason: 'silinmez');
      expect(find.textContaining(arsivliEtiket), findsOneWidget);

      await t.tap(find.byType(BackButton));
      await bekle(t);
      await t.tap(find.text(sekmeIslemler));
      await bekle(t);
      expect(
        find.text('Market'),
        findsOneWidget,
        reason: 'eski işlemde adı görünür',
      );

      await t.tap(find.byTooltip(islemEkleEtiket));
      await bekle(t);
      expect(
        find.byKey(const ValueKey('cip-1')),
        findsNothing,
        reason: 'yeni girişte çip yok',
      );
      await t.tapAt(const Offset(200, 20)); // alt sayfayı kapat
      await bekle(t);

      await t.tap(find.text(sekmeAyarlar).first);
      await bekle(t);
      await t.tap(find.text(kategorilerBaslik));
      await bekle(t);
      await t.tap(find.byKey(const ValueKey('arsiv-1')));
      await bekle(t);
      expect(
        (await kategoriler(t, db)).singleWhere((c) => c.id == 1).archived,
        isFalse,
      );
    },
  );

  uiTest('limit: tuş takımıyla koy, değiştir, kaldır', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await kategorilerAc(t, db);
    Future<Map<int, int>> limitler() =>
        t.runAsync(() => db.limitleriIzle().first).then((v) => v!);

    expect(find.text(limitYok), findsNWidgets(9), reason: '9 gider kategorisi');
    expect(
      find.byKey(const ValueKey('limit-10')),
      findsNothing,
      reason: 'gelire limit yok',
    );

    await t.tap(find.byKey(const ValueKey('limit-2')));
    await bekle(t);
    expect(
      find.byKey(const ValueKey('tus-5')),
      findsOneWidget,
      reason: 'hızlı girişteki tuş takımı',
    );
    for (final r in [5, 0, 0, 0, 0]) {
      await t.tap(find.byKey(ValueKey('tus-$r')));
      await t.pump();
    }
    expect(find.text('500,00 ₺'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('limit-kaydet')));
    await bekle(t);
    expect(await limitler(), {2: 50000});
    expect(find.text(limitSatiri('500,00 ₺')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('limit-2')));
    await bekle(t);
    expect(
      find.text('500,00 ₺'),
      findsOneWidget,
      reason: 'mevcut limit dolu açılır',
    );
    await t.tap(find.byKey(const ValueKey('tus-sil')));
    await t.tap(find.byKey(const ValueKey('tus-7')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('limit-kaydet')));
    await bekle(t);
    expect(await limitler(), {2: 50007});

    await t.tap(find.byKey(const ValueKey('limit-2')));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('limit-kaldir')));
    await bekle(t);
    expect(await limitler(), isEmpty);
    expect(find.text(limitYok), findsNWidgets(9));
  });

  uiTest('limit 0 iken Kaydet kapalı', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await kategorilerAc(t, db);
    await t.tap(find.byKey(const ValueKey('limit-1')));
    await bekle(t);
    final dugme = t.widget<FilledButton>(
      find.byKey(const ValueKey('limit-kaydet')),
    );
    expect(dugme.onPressed, isNull);
    expect(
      find.byKey(const ValueKey('limit-kaldir')),
      findsNothing,
      reason: 'kaldırılacak limit yok',
    );
  });

  uiTest(
    'Kaydet düğmesine hızlı çift dokunuş tek kategori ekler ve ekranı iki kez kapatmaz',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await kategorilerAc(t, db);

      await t.tap(find.byTooltip(giderKategorisiEkle));
      await bekle(t);
      await t.enterText(find.byKey(const ValueKey('kategori-ad')), 'Deneme');
      await t.tap(find.byKey(const ValueKey('kategori-kaydet')));
      await t.tap(
        find.byKey(const ValueKey('kategori-kaydet')),
      ); // ilk işlem bitmeden
      await bekle(t);

      final liste = await kategoriler(t, db);
      expect(liste.where((c) => c.name == 'Deneme'), hasLength(1));
      expect(
        find.text(kategorilerBaslik),
        findsOneWidget,
        reason: 'ekran kapanmadı',
      );
      expect(
        find.byKey(const ValueKey('kategori-ad')),
        findsNothing,
        reason: 'diyalog kapandı',
      );
    },
  );

  uiTest('arşivleme hatasında kısa Türkçe mesaj çıkar, kategori değişmez', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t, arsivBozuk: true);
    await kategorilerAc(t, db);

    await t.tap(find.byKey(const ValueKey('arsiv-1')));
    await bekle(t);
    expect(find.text(arsivHatasi), findsOneWidget);
    expect(
      (await kategoriler(t, db)).firstWhere((c) => c.id == 1).archived,
      isFalse,
    );
  });

  group('silme', () {
    uiTest('sil düğmesi: onay metni işlem sayısıyla, Vazgeç değiştirmez', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      for (var i = 0; i < 3; i++) {
        await t.runAsync(
          () => db.islemEkle(
            tutarKurus: 100,
            gelir: false,
            kategoriId: 1,
            not: '',
            gun: gunAnahtari(DateTime.now()),
          ),
        );
      }
      await kategorilerAc(t, db);

      await t.tap(find.byTooltip('Market: $silEtiket'));
      await bekle(t);
      expect(find.text('Market silinsin mi?'), findsOneWidget);
      expect(
        find.text("İçindeki 3 işlem Diğer'e taşınacak. Bu geri alınamaz."),
        findsOneWidget,
      );
      await t.tap(find.text(vazgecEtiket));
      await bekle(t);
      expect(find.text('Market'), findsOneWidget);
      expect(await kategoriler(t, db), hasLength(10));
    });

    uiTest(
      'Sil: satır kaybolur, işlemler Diğere gider; işlemsizde kısa metin',
      (t) async {
        telefonBoyutu(t);
        final db = await bellekDb(t);
        await t.runAsync(
          () => db.islemEkle(
            tutarKurus: 100,
            gelir: false,
            kategoriId: 1,
            not: '',
            gun: gunAnahtari(DateTime.now()),
          ),
        );
        await kategorilerAc(t, db);

        await t.tap(find.byTooltip('Market: $silEtiket'));
        await bekle(t);
        await t.tap(find.byKey(const ValueKey('sil-onay')));
        await bekle(t);
        expect(find.text('Market'), findsNothing);
        final islemler = await t.runAsync(
          () => db.select(db.transactions).get(),
        );
        expect(islemler!.single.categoryId, 9);

        await t.tap(find.byTooltip('Ulaşım: $silEtiket'));
        await bekle(t);
        expect(find.text('Bu geri alınamaz.'), findsOneWidget);
      },
    );

    uiTest('Diğer ve Diğer gelir satırında sil düğmesi yok', (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await kategorilerAc(t, db);
      expect(find.byKey(const ValueKey('sil-9')), findsNothing);
      expect(find.byKey(const ValueKey('sil-1')), findsOneWidget);
      await t.runAsync(
        () => db.kategoriEkle(ad: 'Diğer gelir', simge: 9, gelir: true),
      );
      await bekle(t);
      expect(find.text('Diğer gelir'), findsOneWidget);
      expect(find.byKey(const ValueKey('sil-11')), findsNothing);
    });

    uiTest('Diğer satırında arşiv ve limit simgeleri Market ile aynı sütunda', (
      t,
    ) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await kategorilerAc(t, db);
      double x(String anahtar) =>
          t.getCenter(find.byKey(ValueKey(anahtar))).dx;
      expect(x('arsiv-9'), x('arsiv-1'));
      expect(x('limit-9'), x('limit-1'));
    });
  });
}
