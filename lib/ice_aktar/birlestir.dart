// Karakter kutularını metin parçalarına birleştirir. Saf Dart.

import 'dokum.dart';

/// [karakterler] pdfium'un fullText sırasındadır; boşluk karakterleri (' ', '\r', '\n')
/// dahildir, kutuları önemsizdir. Boşluk karakteri sözcük arası olur, '\n' parçayı keser.
/// Aynı parçada kalmak için karakter, parçanın dikey bandıyla örtüşmeli (',' ve '.' altta, '*' üstte durur; satırlar arası boşluk örtüşmeyi keser) ve
/// aradaki yatay boşluk 1,5 x satır yüksekliğinden küçük olmalı (sütunlar arası boşluk keser).
/// Çıkan parçanın y/h değeri üyelerin birleşik bandıdır.
List<MetinParcasi> parcalariBirlestir(List<MetinParcasi> karakterler) {
  final sonuc = <MetinParcasi>[];
  final metin = StringBuffer();
  double x = 0, sag = 0, ust = 0, alt = 0, enYuksek = 0;
  var acik = false, bosluk = false;

  void kes() {
    if (acik) sonuc.add(MetinParcasi(x, ust, sag - x, alt - ust, metin.toString()));
    metin.clear();
    acik = bosluk = false;
  }

  for (final k in karakterler) {
    if (k.t.trim().isEmpty) {
      if (k.t.contains('\n')) {
        kes();
      } else {
        bosluk = true;
      }
      continue;
    }
    if (acik) {
      final kAlt = k.y + k.h;
      final ortusme = (alt < kAlt ? alt : kAlt) - (ust > k.y ? ust : k.y);
      final yukseklik = enYuksek > k.h ? enYuksek : k.h;
      if (ortusme <= 0 || k.x - sag > yukseklik * 1.5 || k.x < sag - yukseklik) {
        kes();
      }
    }
    if (!acik) {
      x = k.x;
      ust = k.y;
      alt = k.y + k.h;
      enYuksek = k.h;
      acik = true;
    } else {
      if (bosluk) metin.write(' ');
      if (k.y < ust) ust = k.y;
      if (k.y + k.h > alt) alt = k.y + k.h;
      if (k.h > enYuksek) enYuksek = k.h;
    }
    bosluk = false;
    metin.write(k.t);
    sag = k.x + k.w;
  }
  kes();
  return sonuc;
}
