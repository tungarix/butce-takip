// Uygulama kabuğunda (sekmeler birlikte kurulu): ilk açılış yanıtı, Ayarlar'daki anahtara yansımalı.
import 'dart:io';

import 'package:butce_takip/features/ayarlar/guncelleme_bolumu.dart';
import 'package:butce_takip/platform/guncelleme/ag.dart';
import 'package:butce_takip/platform/guncelleme/ayarlar.dart';
import 'package:butce_takip/platform/guncelleme/guncelleyici.dart';
import 'package:butce_takip/platform/kopru.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

class _SahteAg extends Ag {
  _SahteAg() : super(surum: '0.0.1');
  int sorgu = 0;

  @override
  Future<SonYayinSonucu> sonYayin([String? etag]) async {
    sorgu++;
    return ('yok', null, null);
  }
}

class _SahteKopru implements Kopru {
  @override
  Future<String> agTuru() async => 'wifi';
  @override
  Future<bool> kurulumIzniVar() async => true;
  @override
  Future<void> kurulumIzniAc() async {}
  @override
  Future<void> apkKur(String yol, String ozet) async {}
  @override
  void kurulumSonucuDinle(void Function(int, String?) f) {}

  @override
  Future<String?> paylasilanDosya() async => null;

  @override
  void paylasimDinle(void Function() f) {}
}

void main() {
  Future<_SahteAg> kabukAc(WidgetTester tester) async {
    telefonBoyutu(tester);
    final db = await bellekDb(tester);
    final ag = _SahteAg();
    await uygulamaAc(
      tester,
      db,
      ekstra: [
        kopruProvider.overrideWithValue(_SahteKopru()),
        // Gerçek kurulum gibi her çözümlemede durumu veritabanından yükler.
        guncelleyiciProvider.overrideWith(
          (ref) async => Guncelleyici(
            ayarlar: await GuncellemeAyarlari.yukle(db),
            klasor: Directory.systemTemp,
            surum: '0.0.1',
            ag: ag,
          ),
        ),
      ],
    );
    return ag;
  }

  Future<bool> anahtarAcikMi(WidgetTester tester) async {
    await tester.tap(find.text(sekmeAyarlar));
    await bekle(tester);
    final bul = find.widgetWithText(SwitchListTile, guncellemeDenetle);
    await tester.scrollUntilVisible(
      bul,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    return tester.widget<SwitchListTile>(bul).value;
  }

  uiTest('ilk açılışta "Evet": Ayarlar anahtarı açık görünür', (tester) async {
    final ag = await kabukAc(tester);
    expect(find.text(guncellemeIlkBaslik), findsOneWidget);
    await tester.tap(find.text(guncellemeIlkEvet));
    await bekle(tester);
    expect(ag.sorgu, 1);
    expect(await anahtarAcikMi(tester), isTrue);
  });

  uiTest('ilk açılışta "Hayır": anahtar kapalı kalır, ağ isteği yok',
      (tester) async {
    final ag = await kabukAc(tester);
    await tester.tap(find.text(guncellemeIlkHayir));
    await bekle(tester);
    expect(ag.sorgu, 0);
    expect(await anahtarAcikMi(tester), isFalse);
  });
}
