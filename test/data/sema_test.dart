import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/database/tohum.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> islemEkle({int tutar = 1000, int? kategori}) {
    return db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        amountKurus: tutar,
        isIncome: false,
        categoryId: kategori ?? 1,
        day: 20260315,
        createdAt: 0,
      ),
    );
  }

  test('onCreate: 10 hazır kategori, sıra ve gelir bayrağı', () async {
    final liste = await (db.select(db.categories)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
    expect(liste.map((c) => c.name), tohumKategoriler.map((k) => k.ad));
    expect(liste, hasLength(10));
    expect(liste.where((c) => c.isIncome).map((c) => c.name), ['Maaş']);
    expect(liste.every((c) => !c.archived), isTrue);
  });

  test('tohum anahtar kelimeler doğru kategoriye bağlı', () async {
    Future<String> kategoriOf(String kelime) async {
      final satir = await (db.select(db.keywordHits)
            ..where((h) => h.keyword.equals(kelime)))
          .getSingle();
      final c = await (db.select(db.categories)
            ..where((c) => c.id.equals(satir.categoryId)))
          .getSingle();
      return c.name;
    }

    expect(await kategoriOf('migros'), 'Market');
    expect(await kategoriOf('sok'), 'Market');
    expect(await kategoriOf('shell'), 'Ulaşım');
    expect(await kategoriOf('netflix'), 'Abonelik');
    expect(await kategoriOf('eczane'), 'Sağlık');
    final toplam = tohumAnahtarKelimeler.values.fold(0, (a, l) => a + l.length);
    expect(await db.select(db.keywordHits).get(), hasLength(toplam));
  });

  test('foreign_keys açık: olmayan kategoriye işlem reddedilir', () async {
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.single, 1);
    await expectLater(islemEkle(kategori: 9999), throwsA(isA<Exception>()));
  });

  test('CHECK: tutar 0 ve eksi reddedilir, 1 kuruş kabul edilir', () async {
    await expectLater(islemEkle(tutar: 0), throwsA(isA<Exception>()));
    await expectLater(islemEkle(tutar: -5), throwsA(isA<Exception>()));
    expect(await islemEkle(tutar: 1), isPositive);
  });

  test('kategori adı benzersiz', () async {
    await expectLater(
      db.into(db.categories).insert(
        CategoriesCompanion.insert(name: 'Market', icon: 0, sortOrder: 99),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('indeksler oluştu', () async {
    final r = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'transactions'",
        )
        .get();
    final adlar = r.map((e) => e.read<String>('name')).toSet();
    expect(
      adlar,
      containsAll([
        'transactions_day',
        'transactions_category_day',
        'transactions_note_norm',
      ]),
    );
  });

  test('sum(kategori) == genel toplam', () async {
    await islemEkle(tutar: 1050, kategori: 1);
    await islemEkle(tutar: 250, kategori: 1);
    await islemEkle(tutar: 799, kategori: 2);
    final toplam = db.transactions.amountKurus.sum();
    final genel = await (db.selectOnly(db.transactions)..addColumns([toplam]))
        .map((r) => r.read(toplam))
        .getSingle();
    final kategoriBazli = await (db.selectOnly(db.transactions)
          ..addColumns([db.transactions.categoryId, toplam])
          ..groupBy([db.transactions.categoryId]))
        .map((r) => r.read(toplam)!)
        .get();
    expect(genel, 2099);
    expect(kategoriBazli.fold(0, (a, b) => a + b), genel);
  });
}
