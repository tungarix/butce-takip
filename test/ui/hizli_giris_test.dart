import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/features/hizli_giris/hizli_giris.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

Future<List<Transaction>> _hepsi(WidgetTester t, AppDatabase db) =>
    t.runAsync(() => db.select(db.transactions).get()).then((v) => v!);

Future<void> _bas(WidgetTester t, List<int> rakamlar) async {
  for (final r in rakamlar) {
    await t.tap(find.byKey(ValueKey('tus-$r')));
    await t.pump();
  }
}

void main() {
  uiTest('tuşlar -> çip: doğru kuruş, kategori ve bugünün günü kaydedilir', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);

    await t.tap(find.byTooltip(islemEkleEtiket));
    await bekle(t);
    await _bas(t, [1, 2, 3, 4, 5, 0]); // 1.234,50 ₺
    expect(find.text('1.234,50 ₺'), findsWidgets);

    // Market ilk sortOrder: çipler arasında olmalı.
    await t.tap(find.byKey(const ValueKey('cip-1')));
    await bekle(t);

    final satirlar = await _hepsi(t, db);
    expect(satirlar, hasLength(1));
    final s = satirlar.single;
    expect(s.amountKurus, 123450);
    expect(s.categoryId, 1);
    expect(s.isIncome, isFalse);
    expect(s.day, gunAnahtari(DateTime.now()));
    expect(
      find.byKey(const ValueKey('tutar')),
      findsNothing,
      reason: 'sayfa kapanmalı',
    );
  });

  uiTest('tutar 0 iken çip kaydetmez ve sayfa açık kalır', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);

    await t.tap(find.byTooltip(islemEkleEtiket));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('cip-1')));
    await bekle(t);

    expect(await _hepsi(t, db), isEmpty);
    expect(find.byKey(const ValueKey('tutar')), findsOneWidget);
    // Uyarı alt sayfanın içinde (SnackBar değil, sayfanın arkasında kalmaz).
    expect(
      find.descendant(
        of: find.byType(HizliGirisSayfasi),
        matching: find.text(onceTutarYaz),
      ),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
  });

  uiTest('geri tuşu son rakamı siler', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.byTooltip(islemEkleEtiket));
    await bekle(t);
    await _bas(t, [5, 2, 3]);
    expect(find.text('5,23 ₺'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tus-sil')));
    await t.pump();
    expect(find.text('0,52 ₺'), findsOneWidget);
  });

  uiTest(
    'gelir anahtarı gelir kategorilerini gösterir ve gelir olarak kaydeder',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await uygulamaAc(t, db);
      await t.tap(find.byTooltip(islemEkleEtiket));
      await bekle(t);
      await t.tap(find.text(ayrintiEtiket));
      await bekle(t);
      await t.tap(find.text(gelirEtiket));
      await bekle(t);
      expect(find.byKey(const ValueKey('cip-1')), findsNothing);
      await _bas(t, [1, 0, 0, 0, 0]);
      await t.tap(find.byKey(const ValueKey('cip-10'))); // Maaş
      await bekle(t);
      final s = (await _hepsi(t, db)).single;
      expect((s.amountKurus, s.isIncome, s.categoryId), (10000, true, 10));
    },
  );

  uiTest('düzenleme: çip yalnız seçer, Kaydet günceller (id korunur)', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    final id = await t.runAsync(
      () => db.islemEkle(
        tutarKurus: 5000,
        gelir: false,
        kategoriId: 1,
        not: 'eski',
        gun: gunAnahtari(DateTime.now()),
      ),
    );
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeIslemler));
    await bekle(t);
    await t.tap(find.text('Market').first);
    await bekle(t);
    expect(find.text('eski'), findsWidgets);
    expect(find.text('50,00 ₺'), findsWidgets);

    await t.tap(find.byKey(const ValueKey('tus-sil')));
    await _bas(t, [7]); // 50,07
    await t.tap(find.byKey(const ValueKey('cip-2')).last);
    await bekle(t);
    expect(
      await _hepsi(t, db).then((l) => l.single.categoryId),
      1,
      reason: 'çip kaydetmemeli',
    );

    await t.ensureVisible(find.byKey(const ValueKey('kaydet')));
    await t.tap(find.byKey(const ValueKey('kaydet')));
    await bekle(t);
    final s = (await _hepsi(t, db)).single;
    expect((s.id, s.amountKurus, s.categoryId), (id, 5007, 2));
  });

  uiTest(
    'kayıt hatası: Türkçe mesaj görünür, sayfa açık kalır, tekrar denenebilir',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t, bozuk: true);
      await uygulamaAc(t, db);
      await t.tap(find.byTooltip(islemEkleEtiket));
      await bekle(t);
      await _bas(t, [5, 0]);
      await t.tap(find.byKey(const ValueKey('cip-1')));
      await bekle(t);
      expect(find.text(kaydedilemedi), findsOneWidget);
      expect(find.byKey(const ValueKey('tutar')), findsOneWidget);

      // _kaydediyor sıfırlandı: ikinci basış da kaydetmeyi dener (yine hata verir).
      await t.tap(find.byKey(const ValueKey('tus-sil')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('cip-2')));
      await bekle(t);
      expect(find.text(kaydedilemedi), findsOneWidget);
    },
  );

  uiTest('düzenleme: başlık ve tarih etiketi görünür', (t) async {
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
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeIslemler));
    await bekle(t);
    await t.tap(find.text('Market').first);
    await bekle(t);
    expect(find.text(islemDuzenleBaslik), findsOneWidget);
    expect(find.text(tarihEtiket), findsOneWidget);
  });
}
