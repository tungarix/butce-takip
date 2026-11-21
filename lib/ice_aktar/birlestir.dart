// Karakter/parça kutularını sözcük gruplarına birleştirir (PyMuPDF span'ına benzer). Saf Dart.

import 'dokum.dart';

/// Satır, kutuların dikey örtüşmesine göre kurulur (sıkı glif kutularında '.' ve ',' alçakta
/// durur, üst y'leri farklıdır). Aynı satırdaki, aradaki boşluğu satır yüksekliğinden küçük
/// parçalar birleşir; sütunlar arası büyük boşluk ayırır. Girdi sırası önemsizdir.
/// Çıkan parçaların y/h değeri satır bandından gelir.
List<MetinParcasi> parcalariBirlestir(List<MetinParcasi> girdi) {
  final sirali = [...girdi]..sort((a, b) => a.y.compareTo(b.y));
  final sonuc = <MetinParcasi>[];
  var i = 0;
  while (i < sirali.length) {
    final ust = sirali[i].y;
    var alt = ust + sirali[i].h;
    final uyeler = <MetinParcasi>[sirali[i++]];
    // Kutunun en az yarısı banda giriyorsa aynı satırdır.
    while (i < sirali.length) {
      final p = sirali[i];
      final ortusme = (alt < p.y + p.h ? alt : p.y + p.h) - p.y;
      if (ortusme <= p.h * 0.5) break;
      uyeler.add(p);
      if (p.y + p.h > alt) alt = p.y + p.h;
      i++;
    }
    final h = alt - ust;
    final satir = [for (final p in uyeler) MetinParcasi(p.x, ust, p.w, h, p.t)]
      ..sort((a, b) => a.x.compareTo(b.x));
    var grup = satir.first;
    for (final p in satir.skip(1)) {
      final bosluk = p.x - (grup.x + grup.w);
      if (bosluk < h) {
        // Küçük boşluk sözcük arası sayılır, daha küçüğü bitişik harf.
        final ek = bosluk > h * 0.2 ? ' ' : '';
        grup = MetinParcasi(grup.x, ust, p.x + p.w - grup.x, h, '${grup.t}$ek${p.t}');
      } else {
        sonuc.add(grup);
        grup = p;
      }
    }
    sonuc.add(grup);
  }
  return sonuc;
}
