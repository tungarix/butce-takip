import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/tarih.dart';
import 'database/baglanti.dart';
import 'database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(baglantiAc());
  ref.onDispose(db.close);
  return db;
});

/// Seçili ay (yyyymm). İşlemler de Özet de bunu kullanır.
class SeciliAy extends Notifier<int> {
  @override
  int build() => ayAnahtari(DateTime.now());

  void kaydir(int adim) => state = ayKaydir(state, adim);
}

final seciliAyProvider = NotifierProvider<SeciliAy, int>(SeciliAy.new);

final kategorilerProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(databaseProvider).kategorileriIzle(),
);

final ayIslemleriProvider = StreamProvider<List<Transaction>>(
  (ref) => ref
      .watch(databaseProvider)
      .ayIslemleriniIzle(ref.watch(seciliAyProvider)),
);

final sonIslemlerProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(databaseProvider).sonIslemleriIzle(),
);
