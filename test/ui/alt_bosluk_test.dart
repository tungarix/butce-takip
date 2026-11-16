import 'package:butce_takip/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

/// Uçtan uca (edge-to-edge) 3 düğmeli gezinme çubuğu: altta 48 mantıksal piksel sistem çubuğu.
const _cubuk = 48.0;
const _yukseklik = 640.0;

void kucukEkranCubuklu(WidgetTester t) {
  t.view.physicalSize = const Size(400, _yukseklik);
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 24, bottom: _cubuk);
  t.view.viewPadding = const FakeViewPadding(top: 24, bottom: _cubuk);
  addTearDown(t.view.reset);
}

/// Sayfayı sonuna kadar kaydırır (alt sayfa ve liste için).
Future<void> sonaKaydir(WidgetTester t, Finder kaydirilan) async {
  await t.drag(kaydirilan, const Offset(0, -2000));
  await bekle(t);
}

void gorunur(WidgetTester t, Finder f) {
  expect(f, findsOneWidget);
  expect(
    t.getRect(f).bottom,
    lessThanOrEqualTo(_yukseklik - _cubuk),
    reason: 'alt kenar gezinme çubuğunun üstünde olmalı',
  );
}

void main() {
  uiTest('hızlı giriş: Ayrıntı satırı çubuğun üstünde ve açılır', (t) async {
    kucukEkranCubuklu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.byTooltip(islemEkleEtiket));
    await bekle(t);
    await sonaKaydir(t, find.byType(SingleChildScrollView).last);

    gorunur(t, find.byKey(const ValueKey('ayrinti')));
    await t.tap(find.text(ayrintiEtiket));
    await bekle(t);
    expect(find.byKey(const ValueKey('not')), findsOneWidget);
  });

  uiTest('limit sayfası: Kaydet çubuğun üstünde ve çalışır', (t) async {
    kucukEkranCubuklu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);
    await t.tap(find.text(kategorilerBaslik));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('limit-1')));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('tus-5')));
    await bekle(t);
    await sonaKaydir(t, find.byType(SingleChildScrollView).last);

    gorunur(t, find.byKey(const ValueKey('limit-kaydet')));
    await t.tap(find.byKey(const ValueKey('limit-kaydet')));
    await bekle(t);
    expect(find.byKey(const ValueKey('limit-kaydet')), findsNothing);
  });

  uiTest('kategoriler listesi: son satır kaydırınca çubuğun üstünde', (
    t,
  ) async {
    kucukEkranCubuklu(t);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);
    await t.tap(find.text(kategorilerBaslik));
    await bekle(t);
    await sonaKaydir(t, find.byType(ListView).last);

    gorunur(t, find.byType(ListTile).last);
  });

  uiTest('klavye açıkken alt boşluk çift sayılmaz', (t) async {
    kucukEkranCubuklu(t);
    t.view.viewInsets = const FakeViewPadding(bottom: 300);
    t.view.padding = const FakeViewPadding(top: 24);
    final db = await bellekDb(t);
    await uygulamaAc(t, db);
    await t.tap(find.byTooltip(islemEkleEtiket));
    await bekle(t);
    final govde = find.byType(SingleChildScrollView).last;
    // Kaydırma alanı tam klavyenin üstünde biter: 300, çubuk eklenip 348 olmaz.
    expect(t.getRect(govde).bottom, _yukseklik - 300);
  });
}
