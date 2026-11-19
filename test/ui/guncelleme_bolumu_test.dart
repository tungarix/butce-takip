// Ayarlar'da Güncellemeler bölümü görünür ve denetim varsayılan olarak kapalıdır (ağ isteği yok).
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

class _SayanAg extends Ag {
  _SayanAg() : super(surum: '0.0.1');
  int sorgu = 0;

  @override
  Future<SonYayinSonucu> sonYayin([String? etag]) async {
    sorgu++;
    return ('yok', null, null);
  }
}

class _Kopru implements Kopru {
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
}

void main() {
  uiTest('Güncellemeler bölümü bildirim anahtarının altında, varsayılan kapalı', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    final ag = _SayanAg();
    final klasor = Directory.systemTemp.createTempSync('butce_gunc_ui');
    addTearDown(() => klasor.deleteSync(recursive: true));
    final g = Guncelleyici(
      ayarlar: await t.runAsync(() => GuncellemeAyarlari.yukle(db)).then((v) => v!),
      klasor: klasor,
      surum: '0.0.1',
      ag: ag,
    );
    await uygulamaAc(
      t,
      db,
      ekstra: [
        kopruProvider.overrideWithValue(_Kopru()),
        guncelleyiciProvider.overrideWith((ref) async => g),
      ],
    );
    // İlk açılışta bir kez sorulur; "Hayır" = kapalı, ağ isteği yok.
    expect(find.text(guncellemeIlkBaslik), findsOneWidget);
    await t.tap(find.text(guncellemeIlkHayir));
    await bekle(t);
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);

    final baslik = find.text(guncellemeBaslik);
    await t.scrollUntilVisible(baslik, 200);
    expect(baslik, findsOneWidget);
    final anahtar = tester(t, find.text(guncellemeDenetle));
    expect(anahtar.value, isFalse);
    expect(g.denetim, isFalse);
    await t.scrollUntilVisible(find.byKey(const ValueKey('surum-metni')), 200);
    // Sıra: bildirim anahtarı < Güncellemeler < sürüm metni.
    double y(Finder f) => t.getTopLeft(f).dy;
    expect(y(find.text(bildirimAnahtariBaslik)), lessThan(y(baslik)));
    expect(y(baslik), lessThan(y(find.byKey(const ValueKey('surum-metni')))));
    expect(ag.sorgu, 0, reason: 'varsayılan kapalıyken ağ isteği yok');
  });
}

SwitchListTile tester(WidgetTester t, Finder metin) => t.widget<SwitchListTile>(
  find.ancestor(of: metin, matching: find.byType(SwitchListTile)),
);
