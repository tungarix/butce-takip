import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/features/ice_aktar/onizleme_ekrani.dart';
import 'package:butce_takip/ice_aktar/dokum.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'akilli_test.dart' show SahteBildirim;

DokumSatiri _s(int gun, String ad, int tutar, {bool gelir = false}) =>
    DokumSatiri(gun: gun, aciklama: ad, tutarKurus: tutar, gelir: gelir);

IceAktarSatiri _i(DokumSatiri s, int kat) => (
  gun: s.gun,
  not: s.aciklama,
  tutarKurus: s.tutarKurus,
  gelir: s.gelir,
  kategoriId: kat,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final dosya = [
    _s(20260310, 'EPOS MIGROS 1234', 25040),
    _s(20260310, 'EPOS SPOTIFY*PREMIUM', 9999),
    _s(20260311, 'GELEN FAST - kendi hesabım', 100000, gelir: true),
  ];

  Future<int> migrosHits() async => (await (db.select(
    db.keywordHits,
  )..where((k) => k.keyword.equals('migros'))).getSingle()).hits;

  test('içe aktarma toplamları ve anahtar kelime öğrenimi', () async {
    final n = await db.iceAktar([
      _i(dosya[0], 1),
      _i(dosya[1], 8),
      _i(dosya[2], 10),
    ]);
    expect(n, 3);
    final t = await db.tumToplamlar();
    expect(t.gider, 25040 + 9999);
    expect(t.gelir, 100000);
    expect(await migrosHits(), 2, reason: 'tohum 1 + içe aktarma 1');
  });

  test('aynı dosya iki kez: ikinci sefer hepsi "zaten var"', () async {
    expect(await db.zatenVar(dosya), [false, false, false]);
    await db.iceAktar([_i(dosya[0], 1), _i(dosya[1], 8), _i(dosya[2], 10)]);
    expect(await db.zatenVar(dosya), [true, true, true]);
    expect(await db.zatenVar([]), isEmpty);
  });

  test('eşleşmeler sayılır: birebir aynı iki satır ayrı sayılır', () async {
    final a = _s(20260310, 'EPOS BIM 55', 5000);
    expect(await db.zatenVar([a, a]), [false, false]);
    await db.iceAktar([_i(a, 1)]);
    expect(await db.zatenVar([a, a]), [true, false], reason: 'veritabanında 1');
    await db.iceAktar([_i(a, 1)]);
    expect(await db.zatenVar([a, a]), [true, true]);
    expect(await db.zatenVar([a, a, a]), [true, true, false]);
  });

  test(
    'tür, tutar, gün ve not farkı eşleşme sayılmaz; not normalize edilir',
    () async {
      await db.iceAktar([_i(_s(20260310, 'Migros Şube', 1000), 1)]);
      expect(
        await db.zatenVar([
          _s(20260310, 'MIGROS SUBE', 1000), // normalize aynı
          _s(20260310, 'MIGROS SUBE', 1001),
          _s(20260311, 'MIGROS SUBE', 1000),
          _s(20260310, 'MIGROS SUBE', 1000, gelir: true),
          _s(20260310, 'BIM', 1000),
        ]),
        [true, false, false, false, false],
      );
    },
  );

  test('tek transaction: ortada hata olursa hiçbiri yazılmaz', () async {
    await expectLater(
      db.iceAktar([_i(dosya[0], 1), _i(dosya[1], 9999)]), // 9999: kategori yok
      throwsA(anything),
    );
    expect(await db.tumToplamlar(), (gelir: 0, gider: 0));
    expect(await migrosHits(), 1, reason: 'öğrenim de geri alındı');
  });

  test('aşım uyarısı içe aktarmada kategori başına tek kez', () async {
    await db.limitKoy(1, 1000);
    final kapi = SahteBildirim();
    final n = await iceAktarKaydet(db, kapi, [
      for (var i = 0; i < 3; i++) _i(_s(20260310 + i, 'MIGROS $i', 400), 1),
    ]);
    expect(n, 3);
    expect(kapi.gosterilen, hasLength(1));
  });
}
