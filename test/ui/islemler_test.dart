import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'ui_yardimci.dart';

void main() {
  Future<void> ekle(
    WidgetTester t,
    AppDatabase db,
    int gun,
    int tutar, {
    bool gelir = false,
    int kat = 1,
    String not = '',
  }) => t.runAsync(
    () => db.islemEkle(
      tutarKurus: tutar,
      gelir: gelir,
      kategoriId: gelir ? 10 : kat,
      not: not,
      gun: gun,
    ),
  );

  Future<void> islemlerAc(WidgetTester t, AppDatabase db) async {
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeIslemler));
    await bekle(t);
  }

  Future<int> adet(WidgetTester t, AppDatabase db) =>
      t.runAsync(() => db.select(db.transactions).get()).then((l) => l!.length);

  uiTest(
    'güne göre gruplama: Türkçe gün başlığı, gider toplamı, gelir yeşil +',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      final simdi = DateTime.now();
      final bu = simdi.year * 10000 + simdi.month * 100;
      await ekle(t, db, bu + 2, 10000, not: 'migros');
      await ekle(t, db, bu + 2, 2550, kat: 2);
      await ekle(t, db, bu + 2, 500000, gelir: true);
      await ekle(t, db, bu + 1, 700);
      await islemlerAc(t, db);

      expect(
        find.text('125,50 ₺'),
        findsOneWidget,
        reason: '2. günün gider toplamı (gelir hariç)',
      );
      expect(
        find.text('7,00 ₺'),
        findsNWidgets(2),
        reason: 'başlık toplamı + satır tutarı',
      );
      expect(find.text('+5.000,00 ₺'), findsOneWidget);
      expect(find.text('migros'), findsOneWidget);
      for (final g in [1, 2]) {
        final baslik = DateFormat(
          'd MMMM EEEE',
          'tr_TR',
        ).format(DateTime(simdi.year, simdi.month, g));
        expect(find.text(baslik), findsOneWidget);
      }
      final yazi = t.widget<Text>(find.text('+5.000,00 ₺'));
      expect(yazi.style?.color, isNotNull);
    },
  );

  uiTest('ay seçici: önceki aya gidince bu ayın işlemi görünmez, boş durum', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    final simdi = DateTime.now();
    await ekle(
      t,
      db,
      simdi.year * 10000 + simdi.month * 100 + 1,
      1234,
      not: 'burada',
    );
    await islemlerAc(t, db);
    expect(find.text('burada'), findsOneWidget);

    await t.tap(find.byTooltip(oncekiAyEtiket));
    await bekle(t);
    expect(find.text('burada'), findsNothing);
    expect(find.text(bosAyMetni), findsOneWidget);

    await t.tap(find.byTooltip(sonrakiAyEtiket));
    await t.tap(find.byTooltip(sonrakiAyEtiket));
    await bekle(t);
    expect(
      find.text(bosAyMetni),
      findsOneWidget,
      reason: 'gelecek aya gidilebilir',
    );
  });

  uiTest('kaydırıp sil + Geri al: kayıt aynı id ve createdAt ile döner', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    final simdi = DateTime.now();
    await ekle(
      t,
      db,
      simdi.year * 10000 + simdi.month * 100 + 1,
      4200,
      not: 'silinecek',
    );
    final once = (await t.runAsync(() => db.select(db.transactions).get()))!
        .single;
    await islemlerAc(t, db);

    await t.drag(find.text('silinecek'), const Offset(-500, 0));
    await bekle(t);
    expect(find.text('silinecek'), findsNothing);
    expect(await adet(t, db), 0);
    expect(find.text(islemSilindi), findsOneWidget);

    await t.tap(find.text(geriAlEtiket));
    await bekle(t);
    expect(find.text('silinecek'), findsOneWidget);
    final sonra = (await t.runAsync(() => db.select(db.transactions).get()))!
        .single;
    expect(sonra, once);
  });

  uiTest('provider hata verirse kısa Türkçe hata metni görünür', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(
      t,
      db,
      ekstra: [
        ayIslemleriProvider.overrideWith(
          (ref) => Stream.error(StateError('x')),
        ),
      ],
    );
    await t.tap(find.text(sekmeIslemler));
    await bekle(t);
    expect(find.text(veriYuklenemedi), findsOneWidget);
  });
}
