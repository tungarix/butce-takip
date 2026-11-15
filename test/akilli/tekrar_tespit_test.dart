import 'package:butce_takip/akilli/normalize.dart';
import 'package:butce_takip/akilli/tekrar_tespit.dart';
import 'package:butce_takip/core/tarih.dart';
import 'package:flutter_test/flutter_test.dart';

GiderKaydi _g(
  int gun, {
  int tutar = 22999,
  String not = 'Netflix',
  int kat = 8,
}) => (
  tutar: tutar,
  kategoriId: kat,
  noteNorm: notNormalize(not),
  not: not,
  gun: gun,
);

void main() {
  // Aylık: 5 Oca, 5 Şub, 5 Mar -> farklar 31, 28 -> medyan 29 -> beklenen 3 Nis.
  final aylik = [_g(20260105), _g(20260205), _g(20260305)];

  test('2 kayıt önermez, 3 aylık kayıt önerir', () {
    expect(tekrarOnerileri(aylik.take(2).toList(), 20260402), isEmpty);
    final o = tekrarOnerileri(aylik, 20260402);
    expect(o, hasLength(1));
    expect(o.single.not, 'Netflix');
    expect(o.single.tutar, 22999);
    expect(o.single.kategoriId, 8);
    expect(o.single.periyot, 29);
    expect(o.single.beklenenGun, 20260403);
  });

  test(
    'beklenen güne 3 gün kala çıkar, 4 gün kala çıkmaz; 7 gün geçince düşer',
    () {
      expect(tekrarOnerileri(aylik, 20260331), hasLength(1)); // 3 gün kala
      expect(tekrarOnerileri(aylik, 20260330), isEmpty); // 4 gün kala
      expect(tekrarOnerileri(aylik, 20260410), hasLength(1)); // 7 gün geçmiş
      expect(tekrarOnerileri(aylik, 20260411), isEmpty); // 8 gün geçmiş
    },
  );

  test('haftalık (6-8 gün) önerilir', () {
    final haftalik = [
      _g(20260302, tutar: 5000, not: 'Pazar'),
      _g(20260309, tutar: 5000, not: 'Pazar'),
      _g(20260316, tutar: 5000, not: 'Pazar'),
    ];
    final o = tekrarOnerileri(haftalik, 20260321);
    expect(o.single.periyot, 7);
    expect(o.single.beklenenGun, 20260323);
  });

  test('periyot ne aylık ne haftalıksa (örn. 14 gün) önerilmez', () {
    final ikiHaftada = [_g(20260302), _g(20260316), _g(20260330)];
    expect(tekrarOnerileri(ikiHaftada, 20260412), isEmpty);
  });

  test('tutar medyandan %10 sapabilir, %10 üstü sapma önermez', () {
    GiderKaydi k(int gun, int tutar) => _g(gun, tutar: tutar);
    // medyan 10000: 11000 tam %10 (kabul), 11100 %11 (ret).
    expect(
      tekrarOnerileri([
        k(20260105, 10000),
        k(20260205, 10000),
        k(20260305, 11000),
      ], 20260402),
      hasLength(1),
    );
    expect(
      tekrarOnerileri([
        k(20260105, 10000),
        k(20260205, 10000),
        k(20260305, 11100),
      ], 20260402),
      isEmpty,
    );
    expect(
      tekrarOnerileri([
        k(20260105, 10000),
        k(20260205, 10000),
        k(20260305, 9000),
      ], 20260402),
      hasLength(1),
    );
    expect(
      tekrarOnerileri([
        k(20260105, 10000),
        k(20260205, 10000),
        k(20260305, 8900),
      ], 20260402),
      isEmpty,
    );
  });

  test('reddedilen grup çıkmaz; anahtar kararlı (not normalize edilmiş)', () {
    final o = tekrarOnerileri(aylik, 20260402);
    expect(o.single.anahtar, 'n:netflix');
    expect(
      tekrarOnerileri(aylik, 20260402, reddedilen: {'n:netflix'}),
      isEmpty,
    );
    expect(
      tekrarOnerileri(aylik, 20260402, reddedilen: {'n:baska'}),
      hasLength(1),
    );
  });

  test('not boşsa kategori + tutarla gruplanır', () {
    final notsuz = [
      for (final g in [20260105, 20260205, 20260305]) _g(g, not: '', kat: 3),
    ];
    final o = tekrarOnerileri(notsuz, 20260402);
    expect(o.single.anahtar, 'k:3:22999');
    // Aynı not boş ama başka tutar: ayrı grup, 3'e ulaşmaz.
    expect(
      tekrarOnerileri([
        ...notsuz,
        _g(20260315, not: '', kat: 3, tutar: 100),
      ], 20260402),
      hasLength(1),
    );
  });

  test(
    'bu dönem zaten girilmişse çıkmaz (beklenen gün bir dönem ileri gider)',
    () {
      final girilmis = [...aylik, _g(20260403)];
      expect(tekrarOnerileri(girilmis, 20260403), isEmpty);
      // İleri tarihli kayıt da dönemi doldurur.
      expect(tekrarOnerileri([...aylik, _g(20260410)], 20260402), isEmpty);
    },
  );

  test('120 günden eski kayıtlar sayılmaz', () {
    // bugun 20260402: pencere 20251203'ten başlar; 20251105 dışarıda kalır -> 2 kayıt.
    final eskili = [_g(20251105), _g(20260205), _g(20260305)];
    expect(tekrarOnerileri(eskili, 20260402), isEmpty);
  });

  test('ay sonu: 30 Kas, 31 Ara, 31 Oca -> 31 gün -> beklenen 3 Mar (Şubat 28 gün)', () {
    final o = tekrarOnerileri([
      _g(20251130),
      _g(20251231),
      _g(20260131),
    ], 20260302);
    expect(o.single.periyot, 31);
    expect(o.single.beklenenGun, 20260303);
  });

  test('yıl geçişi: 28 Eki, 28 Kas, 28 Ara -> beklenen 27 Oca', () {
    final yil = [_g(20251028), _g(20251128), _g(20251228)];
    final o = tekrarOnerileri(yil, 20260125);
    expect(o.single.beklenenGun, 20260127);
    expect(
      tekrarOnerileri(yil, 20251230),
      isEmpty,
      reason: 'beklenen güne 28 gün var',
    );
  });

  test('gun hesabı yaz saatinden etkilenmez (gunFarki/gunEkle)', () {
    expect(gunFarki(20260131, 20260301), 29);
    expect(gunFarki(20280228, 20280301), 2); // artık yıl
    expect(gunFarki(20260328, 20260330), 2);
    expect(gunEkle(20260131, 1), 20260201);
    expect(gunEkle(20251231, 1), 20260101);
    expect(gunEkle(20260101, -1), 20251231);
    expect(gunEkle(20260131, 28), 20260228);
  });
}
