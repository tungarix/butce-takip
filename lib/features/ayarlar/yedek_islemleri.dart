import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../data/yedek.dart';
import '../../platform/yedek_dosyasi.dart';
import '../../ui_metin.dart';

/// JSON yedeği dosyaya kaydeder ([paylas] false) ya da paylaşım sayfasına verir.
/// Kaydedildiyse/paylaşıldıysa son yedek zamanını yazar; vazgeçilirse yazmaz.
Future<void> yedekle(
  BuildContext context,
  WidgetRef ref, {
  required bool paylas,
}) async {
  // Özet'teki kart yedek yazılınca kalkar; bağlama ve ref'e await'ten önce erişilir.
  final mesaj = ScaffoldMessenger.of(context);
  final db = ref.read(databaseProvider);
  final dosya = ref.read(yedekDosyasiProvider);
  final simdi = DateTime.now();
  try {
    final json = await yedekOlustur(db, simdi: simdi.millisecondsSinceEpoch);
    final ad = 'butce-takip-yedek-${gunAnahtari(simdi)}.json';
    if (await (paylas ? dosya.paylas(json, ad) : dosya.kaydet(json, ad))) {
      await db.ayarYaz(
        sonYedekAnahtari,
        '${DateTime.now().millisecondsSinceEpoch}',
      );
    }
  } catch (_) {
    mesaj.showSnackBar(const SnackBar(content: Text(yedekHatasi)));
  }
}

/// Dosya seç, doğrula, özetle onay al, uygula. Doğrulama geçmeden veritabanına dokunulmaz.
Future<void> geriYukle(BuildContext context, WidgetRef ref) async {
  final mesaj = ScaffoldMessenger.of(context);
  final db = ref.read(databaseProvider);
  final dosya = ref.read(yedekDosyasiProvider);
  void soyle(String m) => mesaj.showSnackBar(SnackBar(content: Text(m)));

  final String? metin;
  try {
    metin = await dosya.sec();
  } catch (_) {
    soyle(dosyaOkunamadi);
    return;
  }
  if (metin == null) return;
  final Yedek yedek;
  final String ozet;
  try {
    yedek = yedekDogrula(metin, guncelSurum: db.schemaVersion);
    final tarih = DateFormat(
      'd MMMM y',
      'tr_TR',
    ).format(DateTime.fromMillisecondsSinceEpoch(yedek.olusturuldu));
    ozet = yedekOzeti(
      yedek.transactions.length,
      yedek.categories.length,
      tarih,
    );
  } on YedekHatasi catch (e) {
    soyle(e.mesaj);
    return;
  } catch (_) {
    soyle(yedekOkunamadi);
    return;
  }
  if (!context.mounted) return;
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(geriYuklemeBaslik),
      content: Text(ozet),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(vazgecEtiket),
        ),
        FilledButton(
          key: const ValueKey('geri-yukle-onay'),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(geriYukleOnayEtiket),
        ),
      ],
    ),
  );
  if (onay != true) return;
  try {
    await yedegiUygula(db, yedek, kopyaYolu: await dosya.kopyaYolu());
    // Geri yüklenen veri artık bir yedeğin kendisi; hatırlatma sayacı sıfırlanır.
    await db.ayarYaz(
      sonYedekAnahtari,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
    soyle(geriYuklendi);
  } on YedekHatasi catch (e) {
    soyle(e.mesaj);
  } catch (_) {
    soyle(geriYuklemeBasarisiz);
  }
}
