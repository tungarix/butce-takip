import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  final buAy = ayAnahtari(DateTime.now());

  String yazi(WidgetTester t, String anahtar) =>
      t.widget<Text>(find.byKey(ValueKey(anahtar))).data!;

  Future<void> tus(WidgetTester t, String rakamlar) async {
    for (final r in rakamlar.split('')) {
      await t.tap(find.byKey(ValueKey('tus-$r')));
      await t.pump();
    }
  }

  uiTest(
    'kart görünür, banka bakiyesi girilince o değeri gösterir, ay özeti değişmez',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await t.runAsync(
        () => db.islemEkle(
          tutarKurus: 10000,
          gelir: true,
          kategoriId: 10,
          not: '',
          gun: buAy * 100 + 1,
        ),
      );
      await t.runAsync(
        () => db.islemEkle(
          tutarKurus: 2500,
          gelir: false,
          kategoriId: 1,
          not: '',
          gun: 20200101, // başka ay
        ),
      );
      await uygulamaAc(t, db);

      expect(find.text(toplamBakiyeEtiket), findsOneWidget);
      expect(find.text(toplamBakiyeAciklama), findsOneWidget);
      expect(yazi(t, 'ozet-bakiye'), '75,00 ₺');
      final gelirOnce = yazi(t, 'ozet-gelir');
      final giderOnce = yazi(t, 'ozet-harcanan');

      await t.tap(find.byKey(const ValueKey('bakiye-karti')));
      await bekle(t);
      expect(find.text(bankaBakiyeBaslik), findsOneWidget);
      await tus(t, '123456'); // 1.234,56
      await t.tap(find.byKey(const ValueKey('bakiye-kaydet')));
      await bekle(t);

      expect(find.text(bankaBakiyeBaslik), findsNothing);
      expect(yazi(t, 'ozet-bakiye'), '1.234,56 ₺');
      expect(yazi(t, 'ozet-gelir'), gelirOnce);
      expect(yazi(t, 'ozet-harcanan'), giderOnce);
      expect(
        await t.runAsync(() => db.select(db.transactions).get()),
        hasLength(2),
      );
    },
  );

  uiTest('eksi giriş: "-" ve hata rengi; Sıfırla açılışı 0 yapar', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);

    await t.tap(find.byKey(const ValueKey('bakiye-karti')));
    await bekle(t);
    await t.tap(find.text(bakiyeEksiEtiket));
    await t.pump();
    await tus(t, '5000');
    await t.tap(find.byKey(const ValueKey('bakiye-kaydet')));
    await bekle(t);

    expect(yazi(t, 'ozet-bakiye'), '-50,00 ₺');
    final renk = t
        .widget<Text>(find.byKey(const ValueKey('ozet-bakiye')))
        .style!
        .color;
    final tema = Theme.of(t.element(find.byKey(const ValueKey('ozet-bakiye'))));
    expect(renk, tema.colorScheme.error);

    await t.tap(find.byKey(const ValueKey('bakiye-karti')));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('bakiye-sifirla')));
    await bekle(t);
    expect(yazi(t, 'ozet-bakiye'), '0,00 ₺');
  });
}
