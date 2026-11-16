// Saf Dart: arayüz ve veritabanı içe aktarılmaz.
import '../core/tarih.dart';
import 'tekrar_tespit.dart';

/// İçinde bulunulan ayın sonu için yaklaşık gider (kuruş); ayın ilk 5 gününde ya da hiç gider yokken null.
/// tahmin = buAyHarcanan + kalanGün * (son 14 günün gideri ~/ 14) + bu ay beklenen, gerçekleşmemiş
/// tekrarlayanlar. Çift sayım olmasın diye tekrarlayan gruplara ait işlemler 14 günlük ortalamaya girmez.
/// [giderler]: son 120 günün gider işlemleri. [buAyHarcanan]: bu ayın toplam gideri.
int? ayTahmini({
  required List<GiderKaydi> giderler,
  required int bugun,
  required int buAyHarcanan,
  Set<String> reddedilen = const {},
}) {
  final gun = bugun % 100;
  if (gun <= 5) return null;
  final ayGun = ayGunSayisi(bugun ~/ 10000, bugun ~/ 100 % 100);
  final ayIlk = bugun - gun + 1;
  final aySon = bugun - gun + ayGun;

  final gruplar = tekrarlayanGruplar(
    giderler,
    bugun,
  ).where((g) => !reddedilen.contains(g.anahtar));
  final tekrarlar = {for (final g in gruplar) g.anahtar};

  final ilk14 = gunEkle(bugun, -13);
  var son14 = 0;
  for (final g in giderler) {
    if (g.gun >= ilk14 &&
        g.gun <= bugun &&
        !tekrarlar.contains(tekrarAnahtari(g))) {
      son14 += g.tutar;
    }
  }

  // Bu ay beklenen ama kaydı girilmemiş tekrarlayanlar; günü 7 günden fazla geçmiş beklenti sayılmaz.
  final enEski = gunEkle(bugun, -7);
  var beklenen = 0;
  for (final g in gruplar) {
    for (var e = g.beklenenGun; e <= aySon; e = gunEkle(e, g.periyot)) {
      if (e >= ayIlk && e >= enEski) beklenen += g.tutar;
    }
  }
  final tahmin = buAyHarcanan + (ayGun - gun) * (son14 ~/ 14) + beklenen;
  // Bu ay ve son 14 günde hiç gider yok: "yaklaşık 0 harcarsın" veri değil, veri yokluğudur.
  return tahmin == 0 ? null : tahmin;
}
