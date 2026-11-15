import 'package:butce_takip/akilli/normalize.dart';
import 'package:butce_takip/akilli/tahmin.dart';
import 'package:butce_takip/akilli/tekrar_tespit.dart';
import 'package:flutter_test/flutter_test.dart';

GiderKaydi _g(int gun, int tutar, {String not = '', int kat = 1}) => (
  tutar: tutar,
  kategoriId: kat,
  noteNorm: notNormalize(not),
  not: not,
  gun: gun,
);

void main() {
  test('ayın ilk 5 gününde null, 6. gün değer', () {
    expect(ayTahmini(giderler: [], bugun: 20260301, buAyHarcanan: 0), isNull);
    expect(
      ayTahmini(giderler: [], bugun: 20260305, buAyHarcanan: 1000),
      isNull,
    );
    expect(ayTahmini(giderler: [], bugun: 20260306, buAyHarcanan: 1000), 1000);
  });

  test('sabit tarihlerle beklenen değer: harcanan + kalan gün * (son 14 gün ~/ 14)', () {
    // 15 Mart (31 gün): kalan 16. Son 14 gün 2-15 Mar: 14000 + 14000 -> 2000/gün. 1 Mar dışında kalır.
    final giderler = [
      _g(20260310, 14000, not: 'Market'),
      _g(20260303, 14000, not: 'Diğer'),
      _g(20260301, 99999, not: 'Eski'),
    ];
    expect(
      ayTahmini(giderler: giderler, bugun: 20260315, buAyHarcanan: 50000),
      50000 + 16 * 2000,
    );
  });

  test('ay uzunlukları: 28 (Şubat), 30 (Nisan), 31 (Mart) gün', () {
    // Her ay: bugün 10'u, son 14 günde toplam 14000 -> 1000/gün, harcanan 0.
    int t(int bugun, int gun) => ayTahmini(
      giderler: [_g(gun, 14000, not: 'a')],
      bugun: bugun,
      buAyHarcanan: 0,
    )!;
    expect(t(20260210, 20260201), 18 * 1000); // 28 - 10
    expect(t(20260410, 20260401), 20 * 1000); // 30 - 10
    expect(t(20260310, 20260301), 21 * 1000); // 31 - 10
    expect(t(20280210, 20280201), 19 * 1000); // artık yıl: 29 - 10
  });

  test('tekrarlayan işlem 14 günlük ortalamaya girmez (çift sayım yok)', () {
    // 20 Mart, kalan 11. Kira 18 Mar'da (2 gün önce) girildi ve aylık grup.
    final giderler = [
      _g(20260118, 30000, not: 'Kira', kat: 4),
      _g(20260218, 30000, not: 'Kira', kat: 4),
      _g(20260318, 30000, not: 'Kira', kat: 4),
      _g(20260312, 14000, not: 'Market'),
    ];
    // Kira sayılsaydı son14 = 44000 -> 3142/gün. Sayılmadığında 14000 ~/ 14 = 1000/gün.
    expect(
      ayTahmini(giderler: giderler, bugun: 20260320, buAyHarcanan: 44000),
      44000 + 11 * 1000,
    );
  });

  test('bu ay beklenen ama gerçekleşmemiş tekrarlayan tutarı eklenir; gelecek aya düşen eklenmez', () {
    final beklenen = [
      _g(20251227, 20000, not: 'Aidat', kat: 4),
      _g(20260126, 20000, not: 'Aidat', kat: 4),
      _g(20260225, 20000, not: 'Aidat', kat: 4), // beklenen 27 Mar
    ];
    expect(
      ayTahmini(giderler: beklenen, bugun: 20260315, buAyHarcanan: 0),
      20000,
    );
    // 5 Mar'da girilmiş: beklenen 4 Nis, bu aya eklenmez.
    final gerceklesmis = [
      _g(20260103, 20000, not: 'Aidat', kat: 4),
      _g(20260204, 20000, not: 'Aidat', kat: 4),
      _g(20260305, 20000, not: 'Aidat', kat: 4),
    ];
    expect(
      ayTahmini(giderler: gerceklesmis, bugun: 20260315, buAyHarcanan: 20000),
      20000,
    );
  });

  test('reddedilen grup tekrarlayan sayılmaz: tutarı ortalamaya girer, ayrıca eklenmez', () {
    final giderler = [
      _g(20251227, 14000, not: 'Aidat'),
      _g(20260126, 14000, not: 'Aidat'),
      _g(20260312, 14000, not: 'Aidat'),
      _g(20260225, 14000, not: 'Aidat'),
    ];
    expect(
      ayTahmini(
        giderler: giderler,
        bugun: 20260315,
        buAyHarcanan: 14000,
        reddedilen: {'n:aidat'},
      ),
      14000 + 16 * 1000,
    );
  });
}
