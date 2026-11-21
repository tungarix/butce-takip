// Metin katmanı olmayan (resim) PDF -> kelime kutuları: pdfrx ile çiz, ML Kit ile tanı.
// Native motor gerektirir; yalnız oku.dart'ın OCR yolundan çağrılır.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

import 'dokum.dart';

const int _enCokSayfa = 3;
const double _hedefGenislik = 2000;

/// Sol-üst köken, resim pikseli; sayfalar alt alta (sayfa yüksekliği kadar kayık).
Future<List<MetinParcasi>> ocrParcalari(Uint8List pdf) async {
  await pdfrxFlutterInitialize();
  final belge = await PdfDocument.openData(pdf);
  final tanici = TextRecognizer(script: TextRecognitionScript.latin);
  final dizin = await getTemporaryDirectory();
  final parcalar = <MetinParcasi>[];
  try {
    var kayma = 0.0;
    for (var s = 0; s < belge.pages.length && s < _enCokSayfa; s++) {
      final sayfa = belge.pages[s];
      final h = (sayfa.height * _hedefGenislik / sayfa.width).roundToDouble();
      final resim = await sayfa.render(
        fullWidth: _hedefGenislik,
        fullHeight: h,
        backgroundColor: 0xFFFFFFFF,
      );
      if (resim == null) continue;
      final dosya = File(
        '${dizin.path}/ocr_${DateTime.now().microsecondsSinceEpoch}_$s.png',
      );
      try {
        await dosya.writeAsBytes(await _png(resim));
        final sonuc = await tanici.processImage(
          InputImage.fromFilePath(dosya.path),
        );
        for (final blok in sonuc.blocks) {
          for (final satir in blok.lines) {
            for (final e in satir.elements) {
              final r = e.boundingBox;
              parcalar.add(
                MetinParcasi(r.left, kayma + r.top, r.width, r.height, e.text),
              );
            }
          }
        }
      } finally {
        resim.dispose();
        try {
          await dosya.delete();
        } catch (_) {}
      }
      kayma += h;
    }
    return parcalar;
  } finally {
    await tanici.close();
    await belge.dispose();
  }
}

Future<Uint8List> _png(PdfImage resim) async {
  final tampon = await ui.ImmutableBuffer.fromUint8List(resim.pixels);
  final desc = ui.ImageDescriptor.raw(
    tampon,
    width: resim.width,
    height: resim.height,
    pixelFormat: ui.PixelFormat.bgra8888,
  );
  final codec = await desc.instantiateCodec();
  final kare = await codec.getNextFrame();
  final bayt = await kare.image.toByteData(format: ui.ImageByteFormat.png);
  kare.image.dispose();
  codec.dispose();
  desc.dispose();
  tampon.dispose();
  return bayt!.buffer.asUint8List();
}
