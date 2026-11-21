// Karakter/parça kutularını sözcük gruplarına birleştirir (PyMuPDF span'ına benzer). Saf Dart.

import 'dokum.dart';

/// Aynı y bandındaki, aradaki boşluğu yazı yüksekliğinden küçük parçalar birleşir;
/// sütunlar arası büyük boşluk ayırır. Girdi sırası önemsizdir.
List<MetinParcasi> parcalariBirlestir(List<MetinParcasi> girdi) {
  final sirali = [...girdi]..sort((a, b) => a.y.compareTo(b.y));
  final sonuc = <MetinParcasi>[];
  var i = 0;
  while (i < sirali.length) {
    // Satır: ilk parçanın yüksekliğinin yarısı içindeki y'ler.
    final ilk = sirali[i];
    final satir = <MetinParcasi>[];
    while (i < sirali.length && (sirali[i].y - ilk.y).abs() < ilk.h * 0.5) {
      satir.add(sirali[i++]);
    }
    satir.sort((a, b) => a.x.compareTo(b.x));
    var grup = satir.first;
    for (final p in satir.skip(1)) {
      final bosluk = p.x - (grup.x + grup.w);
      if (bosluk < grup.h) {
        // Küçük boşluk sözcük arası sayılır, daha küçüğü bitişik harf.
        final ek = bosluk > grup.h * 0.2 ? ' ' : '';
        grup = MetinParcasi(
          grup.x,
          grup.y < p.y ? grup.y : p.y,
          p.x + p.w - grup.x,
          grup.h > p.h ? grup.h : p.h,
          '${grup.t}$ek${p.t}',
        );
      } else {
        sonuc.add(grup);
        grup = p;
      }
    }
    sonuc.add(grup);
  }
  return sonuc;
}
