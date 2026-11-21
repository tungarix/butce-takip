// PDF -> konumlu metin parçaları (pdfrx / pdfium). Native motor gerektirir.

import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import 'birlestir.dart';
import 'dokum.dart';

const int _enCokSayfa = 10;

/// Sayfalar alt alta dizilir (sayfa başına 10000 birim kayma); y sol-üst kökenlidir.
Future<List<MetinParcasi>> pdfParcalari(Uint8List bayt) async {
  await pdfrxFlutterInitialize();
  final belge = await PdfDocument.openData(bayt);
  try {
    final karakterler = <MetinParcasi>[];
    for (var s = 0; s < belge.pages.length && s < _enCokSayfa; s++) {
      final sayfa = belge.pages[s];
      final metin = await sayfa.loadText();
      if (metin == null) continue;
      for (var k = 0; k < metin.fullText.length && k < metin.charRects.length; k++) {
        final r = metin.charRects[k];
        final bosluk = metin.fullText[k].trim().isEmpty;
        if (!bosluk && r.isEmpty) continue;
        karakterler.add(
          MetinParcasi(
            r.left,
            s * 10000 + sayfa.height - r.top,
            r.width,
            r.height,
            metin.fullText[k],
          ),
        );
      }
    }
    return parcalariBirlestir(karakterler);
  } finally {
    await belge.dispose();
  }
}
