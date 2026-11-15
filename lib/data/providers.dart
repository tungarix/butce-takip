import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../akilli/tekrar_tespit.dart';
import '../core/tarih.dart';
import '../platform/bildirimler.dart';
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
  int build() => ref.read(bugunProvider) ~/ 100;

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

final limitlerProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(databaseProvider).limitleriIzle(),
);

final ayGiderToplamlariProvider = StreamProvider<Map<int, int>>(
  (ref) => ref
      .watch(databaseProvider)
      .ayGiderToplamlariniIzle(ref.watch(seciliAyProvider)),
);

final ayGelirToplamiProvider = StreamProvider<int>(
  (ref) => ref
      .watch(databaseProvider)
      .ayGelirToplaminiIzle(ref.watch(seciliAyProvider)),
);

/// Bugün (yyyymmdd). Testte sabit bir günle ezilir.
final bugunProvider = Provider<int>((ref) => gunAnahtari(DateTime.now()));

/// Tekrar tespiti ve tahmin için son 120 günün (ve ileri tarihli) gider işlemleri.
final giderKayitlariProvider = StreamProvider<List<GiderKaydi>>(
  (ref) => ref
      .watch(databaseProvider)
      .giderleriIzle(gunEkle(ref.watch(bugunProvider), -tekrarPencere)),
);

/// "Gösterme" ile reddedilen tekrar grupları.
final reddedilenTekrarlarProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(databaseProvider).ayarAnahtarlariniIzle(tekrarRedOnEki),
);

final bildirimAcikProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(databaseProvider)
      .ayarIzle(bildirimAcikAnahtari)
      .map((v) => v != '0'),
);

/// main.dart gerçek eklentiyi verir; varsayılan hiçbir şey yapmaz.
final bildirimProvider = Provider<BildirimKapisi>((ref) => const BildirimYok());
