// Yerel bildirimler (flutter_local_notifications). Hangi bildirimin gerektiğine akilli/uyari.dart karar
// verir; bu dosya yalnız Android ile konuşur. Eksik izin hiçbir yerde çökme yaratmaz: bildirim
// sessizce atılır, uyarı zaten Özet'teki çubukta görünür. Zamanlanmış bildirim yok.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../akilli/uyari.dart';
import '../data/database/database.dart';
import '../ui_metin.dart';

/// Uygulamanın bildirim katmanından beklediği (testte sahtesi kullanılır).
abstract class BildirimKapisi {
  Future<void> goster({
    required int id,
    required String baslik,
    required String govde,
  });

  /// Android 13+ bildirim izni; yalnız kullanıcı eylemiyle (ilk limit, anahtarı açma) çağrılır.
  Future<void> izinIste();
}

/// Varsayılan: hiçbir şey yapmaz (testler ve eklentisiz ortamlar).
class BildirimYok implements BildirimKapisi {
  const BildirimYok();

  @override
  Future<void> goster({
    required int id,
    required String baslik,
    required String govde,
  }) async {}

  @override
  Future<void> izinIste() async {}
}

class YerelBildirimler implements BildirimKapisi {
  YerelBildirimler([FlutterLocalNotificationsPlugin? eklenti])
    : _p = eklenti ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _p;
  bool _hazir = false;

  static const _detay = NotificationDetails(
    android: AndroidNotificationDetails(
      'butce_uyari',
      'Bütçe uyarıları',
      channelDescription:
          'Bir kategorinin aylık limiti %80 ve %100 dolduğunda haber verir.',
      importance: Importance.defaultImportance,
    ),
  );

  Future<void> baslat() async {
    try {
      await _p.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _hazir = true;
    } catch (_) {
      // Bildirim kurulamadıysa uygulama bildirimsiz çalışır.
    }
  }

  @override
  Future<void> izinIste() async {
    try {
      await _p
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  @override
  Future<void> goster({
    required int id,
    required String baslik,
    required String govde,
  }) async {
    if (!_hazir) return;
    try {
      await _p.show(
        id: id,
        title: baslik,
        body: govde,
        notificationDetails: _detay,
      );
    } catch (_) {}
  }
}

/// [kategoriId]'nin [gun] gününün ayındaki gider toplamı bu kayıtla [once]'den bugünkü değere geçti:
/// gerekiyorsa bildirimi gösterir ve eşiği settings'e işler (ay + kategori + eşik başına bir kez).
Future<void> asimKontrol(
  AppDatabase db,
  BildirimKapisi kapi, {
  required int kategoriId,
  required int gun,
  required int once,
}) async {
  final ay = gun ~/ 100;
  final sonra = await db.ayKategoriGideri(kategoriId, ay);
  final karar = uyariKarari(
    kategoriId: kategoriId,
    ay: ay,
    once: once,
    sonra: sonra,
    limit: await db.limitOku(kategoriId),
    gonderilen: await db.ayarVarOlanlar([
      for (final e in uyariEsikleri) uyariAnahtari(kategoriId, ay, e),
    ]),
    acik: await bildirimAcikMi(db),
  );
  if (karar == null) return;
  for (final k in karar.anahtarlar) {
    await db.ayarYaz(k, '1');
  }
  await kapi.goster(
    id: kategoriId * 10 + karar.esik ~/ 100,
    baslik: uygulamaAdi,
    govde: uyariMetni(await db.kategoriAdi(kategoriId), karar.esik),
  );
}

Future<bool> bildirimAcikMi(AppDatabase db) async =>
    await db.ayarOku(bildirimAcikAnahtari) != '0';

/// İlk limit konduğunda izni ister (bir kez); bildirimler kapalıysa istemez.
Future<void> izinIsteIlkKez(AppDatabase db, BildirimKapisi kapi) async {
  if (await db.ayarOku(izinSorulduAnahtari) != null ||
      !await bildirimAcikMi(db)) {
    return;
  }
  await db.ayarYaz(izinSorulduAnahtari, '1');
  await kapi.izinIste();
}
