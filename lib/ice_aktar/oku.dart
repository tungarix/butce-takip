// Dosya baytı -> Dokum. Arayüz yok.

import 'dart:typed_data';

import 'dokum.dart';
import 'pdf_metin.dart';
import 'yapikredi.dart';

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
  if (dokum == null) throw const DokumHatasi('Bu döküm biçimi tanınmadı');
  return dokum;
}
