import 'package:butce_takip/app.dart';
import 'package:butce_takip/core/tarih.dart';
import 'package:butce_takip/features/ice_aktar/onizleme_ekrani.dart';
import 'package:butce_takip/ice_aktar/dokum.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  final buAy = ayAnahtari(DateTime.now()) * 100;

  DokumSatiri satir(String ad, int tutar, {bool gelir = false}) =>
      DokumSatiri(gun: buAy + 3, aciklama: ad, tutarKurus: tutar, gelir: gelir);

  void onizlemeAc(WidgetTester t, Dokum d) {
    Navigator.of(
      t.element(find.byType(Kabuk)),
    ).push(MaterialPageRoute<void>(builder: (_) => OnizlemeEkrani(dokum: d)));
  }

  uiTest(
    'önizleme: varsayılan işaretler, işaret kaldırınca N azalır, ekle sonrası liste ve bakiye eşitleme',
    (t) async {
      telefonBoyutu(t);
      final db = await bellekDb(t);
      // 4. satır zaten var.
      await t.runAsync(
        () => db.islemEkle(
          tutarKurus: 7500,
          gelir: false,
          kategoriId: 9,
          not: 'ZATEN KAYITLI',
          gun: buAy + 3,
        ),
      );
      await uygulamaAc(t, db);
      onizlemeAc(
        t,
        Dokum(
          banka: 'Yapı Kredi',
          sonBakiyeKurus: 123456,
          atlanan: 1,
          satirlar: [
            satir('EPOS MIGROS SANAL MARKET', 25040),
            satir('EPOS SPOTIFY*PREMIUM', 9999),
            satir('GELEN FAST - AD - kendi hesabım', 100000, gelir: true),
            satir('ZATEN KAYITLI', 7500),
          ],
        ),
      );
      await bekle(t);

      expect(find.text(dokumBaslik('Yapı Kredi', 4)), findsOneWidget);
      expect(find.byKey(const ValueKey('dokum-uyari')), findsOneWidget);
      bool isaret(int i) =>
          t.widget<Checkbox>(find.byKey(ValueKey('dokum-isaret-$i'))).value!;
      expect(
        [for (var i = 0; i < 4; i++) isaret(i)],
        [true, true, false, false],
      );
      expect(find.text(dokumZatenVar), findsOneWidget);
      expect(find.text(dokumKendiHesap), findsOneWidget);
      expect(find.text('-250,40 ₺'), findsOneWidget);
      expect(find.text('+1.000,00 ₺'), findsOneWidget);
      // Öneri: Migros -> Market, Spotify -> Abonelik.
      expect(find.widgetWithText(ActionChip, 'Market'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Abonelik'), findsOneWidget);
      expect(find.text(dokumEkleEtiket(2)), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('dokum-isaret-1')));
      await bekle(t, 2);
      expect(find.text(dokumEkleEtiket(1)), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('dokum-isaret-1')));
      await bekle(t, 2);

      // Gider satırı için gelir kategorisi (Maaş) listelenmez.
      await t.tap(find.byKey(const ValueKey('dokum-kat-cip-0')));
      await bekle(t);
      expect(find.byKey(const ValueKey('dokum-kat-10')), findsNothing);
      await t.tap(find.byKey(const ValueKey('dokum-kat-5'))); // Yemek
      await bekle(t);
      expect(find.widgetWithText(ActionChip, 'Yemek'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('dokum-ekle')));
      await bekle(t);
      expect(find.text(dokumBakiyeSorusu('1.234,56 ₺')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('dokum-bakiye-evet')));
      await bekle(t);

      expect(find.text(dokumEklendi(2)), findsOneWidget);
      expect(find.byType(OnizlemeEkrani), findsNothing);

      await t.tap(find.text(sekmeIslemler).first);
      await bekle(t);
      expect(find.text('EPOS MIGROS SANAL MARKET'), findsOneWidget);
      expect(find.text('EPOS SPOTIFY*PREMIUM'), findsOneWidget);
      expect(find.text('GELEN FAST - AD - kendi hesabım'), findsNothing);
      await t.tap(find.text(sekmeOzet).first);
      await bekle(t);
      expect(
        t.widget<Text>(find.byKey(const ValueKey('ozet-bakiye'))).data,
        '1.234,56 ₺',
      );
    },
  );

  uiTest('hiçbir satır işaretli değilse ekle düğmesi pasif, uyarı yok', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    onizlemeAc(
      t,
      Dokum(
        banka: 'Yapı Kredi',
        satirlar: [satir('KENDI HESABIM', 100, gelir: true)],
      ),
    );
    await bekle(t);
    expect(find.text(dokumEkleEtiket(0)), findsOneWidget);
    expect(
      t
          .widget<FilledButton>(find.byKey(const ValueKey('dokum-ekle')))
          .onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('dokum-uyari')), findsNothing);
  });
}
