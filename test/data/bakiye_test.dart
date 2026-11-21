import 'package:butce_takip/core/butce.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/yedek.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> ekle(int kurus, bool gelir, int gun) => db.islemEkle(
    tutarKurus: kurus,
    gelir: gelir,
    kategoriId: gelir ? 10 : 1,
    not: '',
    gun: gun,
  );

  test('boş veri: toplamlar 0, açılış 0', () async {
    expect(await db.tumToplamlar(), (gelir: 0, gider: 0));
    expect(await db.acilisBakiyeOku(), 0);
  });

  test('tüm zamanlar: geçmiş, bu ay ve gelecekteki işlemler sayılır', () async {
    await ekle(1000, true, 20200115);
    await ekle(500, true, 20990101); // gelecek
    await ekle(300, false, 20251231);
    await ekle(50, false, 20990202);
    expect(await db.tumToplamlar(), (gelir: 1500, gider: 350));
  });

  test('açılış: yazılan okunur; yok ya da bozuksa 0', () async {
    await db.acilisBakiyeYaz(-4200);
    expect(await db.acilisBakiyeOku(), -4200);
    await db.ayarYaz(acilisBakiyeAnahtari, 'abc');
    expect(await db.acilisBakiyeOku(), 0);
    expect(await db.acilisBakiyeIzle().first, 0);
  });

  test('bankaya eşitleme: işlem eklenmez, bakiye girilen değer olur', () async {
    await ekle(10000, true, 20260101);
    await ekle(2500, false, 20260102);
    final t = await db.tumToplamlar();
    await db.acilisBakiyeYaz(bankaBakiyesindenAcilis(-777, t.gelir, t.gider));
    final yeni = await db.tumToplamlar();
    expect(
      toplamBakiye(await db.acilisBakiyeOku(), yeni.gelir, yeni.gider),
      -777,
    );
    expect(await db.select(db.transactions).get(), hasLength(2));
  });

  test('yedek gidiş-dönüş: açılış yedekle gelir, toplam bakiye aynı', () async {
    await ekle(10000, true, 20260101);
    await ekle(2500, false, 20260102);
    await db.acilisBakiyeYaz(-3000);
    final t = await db.tumToplamlar();
    final once = toplamBakiye(-3000, t.gelir, t.gider);
    final json = await yedekOlustur(db);

    await db.islemSil((await db.select(db.transactions).get()).first.id);
    await db.acilisBakiyeYaz(5);
    await yedegiUygula(db, yedekDogrula(json, guncelSurum: db.schemaVersion));

    final s = await db.tumToplamlar();
    expect(toplamBakiye(await db.acilisBakiyeOku(), s.gelir, s.gider), once);
    expect(db.schemaVersion, 1);
  });
}
