// Dosya baytı -> Dokum. Arayüz yok.

import 'dart:typed_data';

import 'dokum.dart';
import 'ocr.dart';
import 'pdf_metin.dart';
import 'yapikredi.dart';
import 'ziraat.dart';

const int _enBuyukBoyut = 5 * 1024 * 1024;

Future<Dokum> dokumOku(Uint8List bayt) async {
  const okunamadi = DokumHatasi('Bu dosya okunamadı');
  if (bayt.length > _enBuyukBoyut ||
      bayt.length < 5 ||
      String.fromCharCodes(bayt, 0, 5) != '%PDF-') {
    throw okunamadi;
  }
  final List<MetinParcasi> parcalar;
  try {
    parcalar = await pdfParcalari(bayt);
  } catch (_) {
    throw okunamadi;
  }
  final dokum = yapiKrediOku(parcalar);
  if (dokum != null) return dokum;
  // Metin katmanı yoksa (resimli PDF) OCR; Yapı Kredi dosyalarında ML Kit hiç çalışmaz.
  if (harfRakamSayisi(parcalar) < 20) {
    try {
      final ocrDokum = ziraatOku(await ocrParcalari(bayt));
      if (ocrDokum != null) return ocrDokum;
    } catch (_) {
      throw okunamadi;
    }
  }
  throw const DokumHatasi('Bu döküm biçimi tanınmadı');
}

/// Sayfalardaki anlamlı (harf/rakam) karakter sayısı.
int harfRakamSayisi(List<MetinParcasi> parcalar) => parcalar.fold(
  0,
  (n, p) => n + RegExp(r'[\p{L}\p{N}]', unicode: true).allMatches(p.t).length,
);
