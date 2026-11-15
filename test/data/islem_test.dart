import 'package:butce_takip/data/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> ekle(
    int gun, {
    int tutar = 1000,
    bool gelir = false,
    String not = '',
  }) => db.islemEkle(
    tutarKurus: tutar,
    gelir: gelir,
    kategoriId: gelir ? 10 : 1,
    not: not,
    gun: gun,
  );

  Future<List<Transaction>> ay(int a) => db.ayIslemleriniIzle(a).first;

  test('ekle: not trim + küçük harf noteNorm, createdAt dolu', () async {
    final id = await ekle(20260315, tutar: 12350, not: '  Migros ');
    final t = (await ay(202603)).single;
    expect(t.id, id);
    expect(t.amountKurus, 12350);
    expect(t.note, 'Migros');
    expect(t.noteNorm, 'migros');
    expect(t.createdAt, greaterThan(0));
  });

  test('güncelle: değerler değişir, id ve createdAt kalır', () async {
    final id = await ekle(20260315, not: 'a');
    final once = (await ay(202603)).single;
    await db.islemGuncelle(
      id,
      tutarKurus: 500,
      gelir: true,
      kategoriId: 10,
      not: 'Maaş',
      gun: 20260401,
    );
    expect(await ay(202603), isEmpty);
    final sonra = (await ay(202604)).single;
    expect(sonra.id, id);
    expect(sonra.createdAt, once.createdAt);
    expect(
      (sonra.amountKurus, sonra.isIncome, sonra.categoryId, sonra.day),
      (500, true, 10, 20260401),
    );
  });

  test('sil + geri yükle: aynı id ve createdAt ile döner', () async {
    final id = await ekle(20260315, not: 'x');
    final orijinal = (await ay(202603)).single;
    await db.islemSil(id);
    expect(await ay(202603), isEmpty);
    await db.islemGeriYukle(orijinal);
    expect((await ay(202603)).single, orijinal);
  });

  test('ay sorgusu: ay sınırı günleri dahil, komşu aylar hariç', () async {
    await ekle(20260228); // şubat son (2026 artık değil)
    await ekle(20260301);
    await ekle(20260331);
    await ekle(20260401);
    expect((await ay(202603)).map((t) => t.day), [20260331, 20260301]);
    expect((await ay(202602)).map((t) => t.day), [20260228]);
    expect((await ay(202604)).map((t) => t.day), [20260401]);
  });

  test('ay sorgusu: artık yıl şubat 29 dahil, sıra yeni gün üstte', () async {
    await ekle(20240229);
    await ekle(20240201);
    await ekle(20240301);
    expect((await ay(202402)).map((t) => t.day), [20240229, 20240201]);
  });

  test('akış: ekleme ve silme izleyiciye yansır', () async {
    final adetler = <int>[];
    final abonelik = db
        .ayIslemleriniIzle(202603)
        .listen((l) => adetler.add(l.length));
    Future<void> bekle() =>
        Future<void>.delayed(const Duration(milliseconds: 50));
    await bekle();
    final id = await ekle(20260310);
    await bekle();
    await db.islemSil(id);
    await bekle();
    await abonelik.cancel();
    expect(adetler, [0, 1, 0]);
  });

  test('tutar 0 ya da eksi veritabanında reddedilir', () async {
    expect(ekle(20260310, tutar: 0), throwsA(anything));
  });
}
