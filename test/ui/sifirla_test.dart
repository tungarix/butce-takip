import 'dart:io';

import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:butce_takip/platform/yedek_dosyasi.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

class _Dosya implements YedekDosyasi {
  _Dosya(this.yol);
  final String yol;

  @override
  Future<String?> sec() async => null;
  @override
  Future<bool> kaydet(String json, String dosyaAdi) async => true;
  @override
  Future<bool> paylas(String json, String dosyaAdi) async => true;
  @override
  Future<String?> kopyaYolu() async => yol;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> islem(WidgetTester t, AppDatabase db, int gun) => t.runAsync(
    () => db.islemEkle(
      tutarKurus: 1000,
      gelir: false,
      kategoriId: 1,
      not: '',
      gun: gun,
    ),
  );

  Future<int> sayi(WidgetTester t, AppDatabase db) =>
      t.runAsync(() => db.select(db.transactions).get()).then((v) => v!.length);

  Future<void> sayfayiAc(WidgetTester t, AppDatabase db) async {
    final dizin = Directory.systemTemp.createTempSync('butce_ui_sifirla_');
    addTearDown(() => dizin.deleteSync(recursive: true));
    await uygulamaAc(
      t,
      db,
      ekstra: [
        bugunProvider.overrideWithValue(20260320),
        yedekDosyasiProvider.overrideWithValue(
          _Dosya('${dizin.path}${Platform.pathSeparator}onceki.sqlite'),
        ),
      ],
    );
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('verileri-sifirla')));
    await bekle(t);
  }

  uiTest('varsayılan yalnız işlemler: ek cümle yok; Vazgeç hiçbir şey silmez', (
    t,
  ) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, 20260310);
    await islem(t, db, 20260311);
    await sayfayiAc(t, db);

    expect(find.text(sifirlaYedekOnerisi), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('sifirla-dugme')));
    await bekle(t);
    expect(find.text(sifirlaOnayMetni(2, false)), findsOneWidget);
    expect(find.textContaining('limitlerin'), findsNothing);
    await t.tap(find.text(vazgecEtiket));
    await bekle(t);
    expect(await sayi(t, db), 2);
  });

  uiTest('Sıfırla sonrası işlemler boş, mesaj görünür', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, 20260310);
    await sayfayiAc(t, db);

    await t.tap(find.byKey(const ValueKey('sifirla-dugme')));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('sifirla-onay')));
    await bekle(t);

    expect(find.text(sifirlandi), findsOneWidget);
    expect(await sayi(t, db), 0);
  });

  uiTest('Her şeyi sıfırla: onayda ek cümle görünür', (t) async {
    telefonBoyutu(t);
    final db = await bellekDb(t);
    await islem(t, db, 20260310);
    await sayfayiAc(t, db);

    await t.tap(find.byKey(const ValueKey('sifirla-hepsi')));
    await bekle(t);
    await t.tap(find.byKey(const ValueKey('sifirla-dugme')));
    await bekle(t);
    expect(find.text(sifirlaOnayMetni(1, true)), findsOneWidget);
    expect(find.textContaining('limitlerin'), findsOneWidget);
  });
}
