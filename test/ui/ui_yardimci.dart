import 'package:butce_takip/app.dart';
import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<AppDatabase> bellekDb() async {
  await initializeDateFormatting('tr_TR');
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

void telefonBoyutu(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> uygulamaAc(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const ButceTakipApp(),
    ),
  );
  await bekle(tester);
}

/// Gerçek async işin (drift) ve animasyonların ilerlemesi için birkaç kare.
Future<void> bekle(WidgetTester tester, [int kare = 8]) async {
  for (var i = 0; i < kare; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Ağacı söker; drift akış zamanlayıcıları test bitmeden dolsun.
Future<void> temizle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await bekle(tester, 2);
}
