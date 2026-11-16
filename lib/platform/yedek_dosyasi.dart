import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Gerçek bir yedek en fazla birkaç yüz KB; bellekte okunacak üst sınır.
const _enBuyukYedekBayt = 16 * 1024 * 1024;

const _yedekOnEki = 'butce-takip-yedek-';

/// Dosya seçici ve paylaşım sayfası için ince arayüz; widget testlerinde sahtelenir.
abstract class YedekDosyasi {
  /// Kullanıcının seçtiği yedeğin metni; vazgeçtiyse null.
  Future<String?> sec();

  /// Sistemin "belge oluştur" seçicisini açar; kullanıcı konumu seçer (depolama izni gerekmez).
  /// Kaydedildiyse true, kullanıcı vazgeçtiyse false.
  Future<bool> kaydet(String json, String dosyaAdi);

  /// [json]'u geçici dosyaya yazıp paylaşım sayfasını açar. Kullanıcı kapattıysa false.
  Future<bool> paylas(String json, String dosyaAdi);

  /// Geri yüklemeden önce mevcut veritabanının kopyasının gideceği yol; null ise kopya alınmaz.
  Future<String?> kopyaYolu();
}

class SistemYedekDosyasi implements YedekDosyasi {
  @override
  Future<String?> sec() async {
    final dosya = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (dosya == null) return null;
    // content:// adreslerinde File(path) çalışmaz; readAsBytes çalışır.
    final bayt = await dosya.readAsBytes();
    if (bayt.length > _enBuyukYedekBayt) {
      throw const FormatException('Dosya çok büyük.');
    }
    return utf8.decode(bayt);
  }

  @override
  Future<bool> kaydet(String json, String dosyaAdi) async {
    final uri = await FilePicker.saveFile(
      fileName: dosyaAdi,
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
    );
    return uri != null;
  }

  @override
  Future<bool> paylas(String json, String dosyaAdi) async {
    final dizin = await getTemporaryDirectory();
    // Önceki paylaşımlar verinin tam kopyasını bırakır; önce temizle.
    await for (final e in dizin.list()) {
      if (e is File &&
          e.uri.pathSegments.last.startsWith(_yedekOnEki) &&
          e.path.endsWith('.json')) {
        try {
          await e.delete();
        } on FileSystemException {
          // Alıcı uygulama hâlâ kullanıyor; sonraki paylaşım yeniden dener.
        }
      }
    }
    final dosya = File('${dizin.path}${Platform.pathSeparator}$dosyaAdi');
    await dosya.writeAsString(json, flush: true);
    final sonuc = await SharePlus.instance.share(
      ShareParams(files: [XFile(dosya.path, mimeType: 'application/json')]),
    );
    return sonuc.status != ShareResultStatus.dismissed;
  }

  @override
  Future<String?> kopyaYolu() async {
    final dizin = await getApplicationDocumentsDirectory();
    return '${dizin.path}${Platform.pathSeparator}butce_takip_onceki.sqlite';
  }
}

final yedekDosyasiProvider = Provider<YedekDosyasi>(
  (ref) => SistemYedekDosyasi(),
);
