import 'package:butce_takip/app.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Her işlem yazışında hata veren DB (kaydetme hatası yolunu denemek için).
class BozukDb extends AppDatabase {
  BozukDb() : super(NativeDatabase.memory());

  @override
  Future<int> islemEkle({
    required int tutarKurus,
    required bool gelir,
    required int kategoriId,
    required String not,
    required int gun,
  }) => Future.error(StateError('yazılamadı'));
}

/// Arşivleme her seferinde hata veren DB.
class ArsivBozukDb extends AppDatabase {
  ArsivBozukDb() : super(NativeDatabase.memory());

  @override
  Future<void> kategoriArsivle(int id, {required bool arsivli}) =>
      Future.error(StateError('yazılamadı'));
}

/// Geri al (islemGeriYukle) her seferinde hata veren DB.
class GeriAlBozukDb extends AppDatabase {
  GeriAlBozukDb() : super(NativeDatabase.memory());

  @override
  Future<void> islemGeriYukle(Transaction t) =>
      Future.error(StateError('yazılamadı'));
}

// Testin açtığı DB'ler; testin kendisine bağlı, global liste yok.
final _dbler = Expando<List<AppDatabase>>();

/// Bellek içi DB. [uiTest] bitince (test başarısız olsa da) kapatır.
Future<AppDatabase> bellekDb(
  WidgetTester tester, {
  bool bozuk = false,
  bool arsivBozuk = false,
  bool geriAlBozuk = false,
}) async {
  await initializeDateFormatting('tr_TR');
  final db = bozuk
      ? BozukDb()
      : arsivBozuk
      ? ArsivBozukDb()
      : geriAlBozuk
      ? GeriAlBozukDb()
      : AppDatabase(NativeDatabase.memory());
  (_dbler[tester] ??= []).add(db);
  return db;
}

/// testWidgets + garantili temizlik. Temizlik test gövdesinin içinde (finally) yapılmalı:
/// drift akışlarının zamanlayıcısı gövde bitince bekliyor olmamalı, DB de sahte zamanda değil
/// gerçek zamanda kapanmalı (aksi halde sqlite3 sonlandırıcıları yarım kapalı bağlantıya girer).
void uiTest(String ad, Future<void> Function(WidgetTester t) govde) {
  testWidgets(ad, (t) async {
    try {
      await govde(t);
    } finally {
      await t.pumpWidget(const SizedBox());
      await bekle(t, 2);
      for (final db in _dbler[t] ?? const <AppDatabase>[]) {
        await t.runAsync(db.close);
      }
      _dbler[t] = null;
    }
  });
}

void telefonBoyutu(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> uygulamaAc(
  WidgetTester tester,
  AppDatabase db, {
  List<Override> ekstra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [databaseProvider.overrideWithValue(db), ...ekstra],
      retry: (_, _) => null,
      child: const ButceTakipApp(),
    ),
  );
  await bekle(tester);
}

/// Gerçek async işin (drift) ve animasyonların ilerlemesi için birkaç kare.
Future<void> bekle(WidgetTester tester, [int kare = 8]) async {
  for (var i = 0; i < kare; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}
