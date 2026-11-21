// Android köprüsü: MainActivity'nin method channel'ı (ek paket yok). Yalnız güncelleme için:
//  - agTuru: etkin ağın türü ('wifi' | 'mobil' | 'yok'),
//  - kurulumIzniVar / kurulumIzniAc: "bilinmeyen uygulamaları yükle" izni,
//  - apkKur: doğrulanmış APK'yı PackageInstaller ile kurar,
//  - kurulumSonucu (Kotlin -> Dart): kurulum oturumunun sonucu,
//  - paylasilanDosya / paylasimGeldi: "Paylaş" ile gelen PDF (banka dökümü).
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Testte ve Android dışında null; main() bunu [AndroidKopru] ile değiştirir.
final kopruProvider = Provider<Kopru?>((ref) => null);

abstract class Kopru {
  /// Etkin ağın türü: 'wifi' (ücretsiz) | 'mobil' (kotalı) | 'yok'.
  Future<String> agTuru();

  /// Bu uygulama paket kurabilir mi (Android 8+ "bilinmeyen uygulamaları yükle").
  Future<bool> kurulumIzniVar();

  /// Bu izin için sistem ekranını açar; kullanıcı izni verip geri döner.
  Future<void> kurulumIzniAc();

  /// Doğrulanmış APK'yı kurar. Kotlin yalnız uygulamanın önbellek klasöründeki, aynı paket adlı ve
  /// daha yüksek versionCode'lu APK'yı, SHA-256'sı [ozet]'e eşitse kabul eder; yoksa `PlatformException`.
  /// Başarı = sistemin kurulum penceresi açıldı.
  Future<void> apkKur(String yol, String ozet);

  /// PackageInstaller sonucu (durum kodu + ileti); 0 = başarı.
  void kurulumSonucuDinle(void Function(int durum, String? mesaj) f);

  /// "Paylaş" ile gelip alınmamış PDF'in geçici dosya yolu (bir kez döner); yoksa null.
  /// Paylaşım 5 MB'ı aştıysa bir kez `PlatformException(code: 'buyuk')`.
  Future<String?> paylasilanDosya();

  /// Uygulama açıkken yeni paylaşım gelince çağrılır.
  void paylasimDinle(void Function() f);
}

class AndroidKopru implements Kopru {
  AndroidKopru() : _kanal = const MethodChannel('com.aktenak.butce_takip/kopru') {
    // Tek işleyici: setMethodCallHandler öncekini değiştirir.
    _kanal.setMethodCallHandler((c) async {
      if (c.method == 'paylasimGeldi') {
        _paylasim?.call();
      } else if (c.method == 'kurulumSonucu' && c.arguments is Map) {
        final d = (c.arguments as Map)['durum'];
        final m = (c.arguments as Map)['mesaj'];
        if (d is int) _kurulum?.call(d, m is String ? m : null);
      }
    });
  }
  final MethodChannel _kanal;
  void Function(int, String?)? _kurulum;
  void Function()? _paylasim;

  @override
  Future<String> agTuru() async => (await _kanal.invokeMethod<String>('agTuru')) ?? 'yok';

  @override
  Future<bool> kurulumIzniVar() async => (await _kanal.invokeMethod<bool>('kurulumIzniVar')) ?? false;

  @override
  Future<void> kurulumIzniAc() => _kanal.invokeMethod<void>('kurulumIzniAc');

  @override
  Future<void> apkKur(String yol, String ozet) => _kanal.invokeMethod<void>('apkKur', {'yol': yol, 'ozet': ozet});

  @override
  void kurulumSonucuDinle(void Function(int durum, String? mesaj) f) => _kurulum = f;

  @override
  Future<String?> paylasilanDosya() => _kanal.invokeMethod<String>('paylasilanDosya');

  @override
  void paylasimDinle(void Function() f) => _paylasim = f;
}
