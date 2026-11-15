import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  final simdi = DateTime.now();
  final buAy = ayAnahtari(simdi);
  final oncekiAy = ayKaydir(buAy, -1);

  Future<void> islem(
    WidgetTester t,
    AppDatabase db,
    int ay,
    int tutar, {
    int kat = 1,
    bool gelir = false,
  }) => t.runAsync(
    () => db.islemEkle(
      tutarKurus: tutar,
      gelir: gelir,
      kategoriId: gelir ? 10 : kat,
      not: '',
      gun: ay * 100 + 1,
    ),
  );

  Future<void> limit(WidgetTester t, AppDatabase db, int kat, int kurus) =>
      t.runAsync(() => db.limitKoy(kat, kurus));

  String yazi(WidgetTester t, String anahtar) =>
      t.widget<Text>(find.byKey(ValueKey(anahtar))).data!;

  double? cubuk(WidgetTester t, int kat) => t
      .widget<LinearProgressIndicator>(
        find.descendant(
          of: find.byKey(ValueKey('limitli-$kat')),
          matching: find.byType(LinearProgressIndicator),
        ),
      )
      .value;

  uiTest('elle girilen veriyle tutarlar, kalan ve yüzde metinleri doğru', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, buAy, 9000, kat: 1); // Market 90,00
    await islem(t, db, buAy, 12000, kat: 2); // Ulaşım 120,00
    await islem(t, db, buAy, 5000, kat: 7); // Eğlence 50,00 (limitsiz)
    await islem(t, db, buAy, 500000, gelir: true);
    await islem(t, db, oncekiAy, 77700, kat: 1); // başka ay: sayılmaz
    await limit(t, db, 1, 10000); // %90
    await limit(t, db, 2, 10000); // %120
    await uygulamaAc(t, db);

    expect(yazi(t, 'ozet-harcanan'), '260,00 ₺');
    expect(
      yazi(t, 'ozet-kalan'),
      '-10,00 ₺',
      reason: '200 limit - 210 harcama, eksiye düşer',
    );
    expect(yazi(t, 'ozet-gelir'), '5.000,00 ₺');
    expect(yazi(t, 'yuzde-1'), '%90');
    expect(yazi(t, 'yuzde-2'), '%120');
    expect(cubuk(t, 1), 0.9);
    expect(cubuk(t, 2), 1.0, reason: 'çubuk doluyu aşmaz');
    expect(find.text('Market bütçesi %90 doldu'), findsOneWidget);
    expect(find.text('Ulaşım bütçesi doldu (%120)'), findsOneWidget);
    expect(find.text('90,00 ₺ / 100,00 ₺'), findsOneWidget);
    expect(find.text(limitsizBaslik), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('limitsiz-7')),
        matching: find.text('50,00 ₺'),
      ),
      findsOneWidget,
    );
    expect(find.text(limitCagrisi), findsNothing);
  });

  uiTest(
    'normal durumda uyarı cümlesi yok; yüzde %79 normal, %80 uyarı rengi',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      await islem(t, db, buAy, 7900, kat: 1);
      await islem(t, db, buAy, 8000, kat: 2);
      await limit(t, db, 1, 10000);
      await limit(t, db, 2, 10000);
      await uygulamaAc(t, db);

      expect(yazi(t, 'yuzde-1'), '%79');
      expect(yazi(t, 'yuzde-2'), '%80');
      expect(find.text('Market bütçesi %79 doldu'), findsNothing);
      expect(find.text('Ulaşım bütçesi %80 doldu'), findsOneWidget);
      final normal = t
          .widget<Text>(find.byKey(const ValueKey('yuzde-1')))
          .style!
          .color;
      final uyari = t
          .widget<Text>(find.byKey(const ValueKey('yuzde-2')))
          .style!
          .color;
      expect(uyari, isNot(normal));
    },
  );

  uiTest('ay değişince güncellenir; limit yokken limit ekleme çağrısı çıkar', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, buAy, 4000, kat: 1);
    await islem(t, db, oncekiAy, 25000, kat: 2);
    await uygulamaAc(t, db);

    expect(yazi(t, 'ozet-harcanan'), '40,00 ₺');
    expect(find.text(limitCagrisi), findsOneWidget);
    expect(find.byKey(const ValueKey('ozet-kalan')), findsNothing);

    await t.tap(find.byTooltip(oncekiAyEtiket));
    await bekle(t);
    expect(yazi(t, 'ozet-harcanan'), '250,00 ₺');

    await t.tap(find.byTooltip(sonrakiAyEtiket));
    await t.tap(find.byTooltip(sonrakiAyEtiket));
    await bekle(t);
    expect(yazi(t, 'ozet-harcanan'), '0,00 ₺');
    expect(find.text(bosAyMetni), findsOneWidget);
  });

  uiTest('arşivli kategorinin harcaması toplamda kalır, limiti işlemez', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, buAy, 3000, kat: 1);
    await islem(t, db, buAy, 2000, kat: 2);
    await limit(t, db, 1, 10000);
    await limit(t, db, 2, 10000);
    await t.runAsync(() => db.kategoriArsivle(2, arsivli: true));
    await uygulamaAc(t, db);

    expect(yazi(t, 'ozet-harcanan'), '50,00 ₺');
    expect(yazi(t, 'ozet-kalan'), '70,00 ₺');
    expect(find.byKey(const ValueKey('limitli-2')), findsNothing);
    expect(find.byKey(const ValueKey('limitsiz-2')), findsOneWidget);
  });

  uiTest('limit ekle düğmesi kategoriler ekranını açar', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.byKey(const ValueKey('limit-ekle')));
    await bekle(t);
    expect(find.text(kategorilerBaslik), findsOneWidget);
  });
}
