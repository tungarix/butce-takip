import 'dart:io';

import 'package:butce_takip/data/database/database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Directory dizin;
  late String kopya;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dizin = Directory.systemTemp.createTempSync('butce_sifirla_');
    kopya = '${dizin.path}${Platform.pathSeparator}sifirlama.sqlite';
    // Tohum: 1 Market ... 10 Maaş.
    await db.islemEkle(
      tutarKurus: 1000,
      gelir: false,
      kategoriId: 1,
      not: 'zzyx market',
      gun: 20260305,
    );
    await db.islemEkle(
      tutarKurus: 5000,
      gelir: true,
      kategoriId: 10,
      not: 'maas',
      gun: 20260301,
    );
    await db.kategoriEkle(ad: 'Hobi', simge: 3, gelir: false);
    await db.limitKoy(1, 500000);
    await db.acilisBakiyeYaz(12345);
    await db.ayarYaz('alert_1_202603_80', '1');
    await db.ayarYaz('tekrar_red_k:1:1000', '1');
    await db.ayarYaz('bildirim_acik', '0');
    await db.ayarYaz('update_check', '0');
  });

  tearDown(() async {
    await db.close();
    dizin.deleteSync(recursive: true);
  });

  Future<Set<String>> ayarlar() async => {
    for (final s in await db.select(db.settings).get()) s.key,
  };

  Future<int> hit(String k) async =>
      (await (db.select(
        db.keywordHits,
      )..where((h) => h.keyword.equals(k))).get()).fold<int>(
        0,
        (a, h) => a + h.hits,
      );

  test('yalnız işlemler: işlem ve bağlı ayarlar gider, gerisi kalır', () async {
    await db.islemleriSifirla(kopyaYolu: kopya);

    expect(await db.select(db.transactions).get(), isEmpty);
    expect(await db.acilisBakiyeOku(), 0);
    expect(await ayarlar(), {'bildirim_acik', 'update_check'});
    expect((await db.select(db.categories).get()).length, 11);
    expect(await db.limitOku(1), 500000);
    expect(await hit('zzyx'), 1, reason: 'öğrenilmiş kelime kalır');
    expect(File(kopya).existsSync(), isTrue);
  });

  test('her şey: ilk kurulum hali, yalnız update_ ayarı kalır', () async {
    final taze = AppDatabase(NativeDatabase.memory());
    addTearDown(taze.close);
    final tazeAdlar = [
      for (final c in await taze.select(taze.categories).get()) c.name,
    ];
    final tazeHit = (await taze.select(taze.keywordHits).get()).length;

    await db.herSeyiSifirla(kopyaYolu: kopya);

    expect([
      for (final c in await db.select(db.categories).get()) c.name,
    ], tazeAdlar);
    expect((await db.select(db.keywordHits).get()).length, tazeHit);
    expect(await db.select(db.budgets).get(), isEmpty);
    expect(await hit('zzyx'), 0);
    expect(await ayarlar(), {'update_check'});
    final id = await db.islemEkle(
      tutarKurus: 100,
      gelir: false,
      kategoriId: 1,
      not: '',
      gun: 20260401,
    );
    expect(id, 1, reason: 'AUTOINCREMENT sayacı sıfırlandı');
    expect(await db.kategoriEkle(ad: 'Yeni', simge: 1, gelir: false), 11);
  });

  test('kopya alınamazsa hiçbir şey silinmez', () async {
    final yanlis =
        '${dizin.path}${Platform.pathSeparator}yok${Platform.pathSeparator}k.sqlite';
    await expectLater(
      db.islemleriSifirla(kopyaYolu: yanlis),
      throwsA(isA<SifirlamaKopyasiHatasi>()),
    );
    await expectLater(
      db.herSeyiSifirla(kopyaYolu: yanlis),
      throwsA(isA<SifirlamaKopyasiHatasi>()),
    );
    expect(await db.select(db.transactions).get(), hasLength(2));
    expect(await db.acilisBakiyeOku(), 12345);
    expect(await db.limitOku(1), 500000);
    expect(await ayarlar(), contains('alert_1_202603_80'));
  });
}
