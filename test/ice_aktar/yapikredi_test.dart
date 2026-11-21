import 'dart:convert';
import 'dart:io';

import 'package:butce_takip/ice_aktar/birlestir.dart';
import 'package:butce_takip/ice_aktar/dokum.dart';
import 'package:butce_takip/ice_aktar/yapikredi.dart';
import 'package:flutter_test/flutter_test.dart';

List<MetinParcasi> _ornek() {
  final j = jsonDecode(
    File('test/ornekler/yapikredi_parcalar.json').readAsStringSync(),
  );
  return [
    for (final p in j['parcalar'] as List)
      MetinParcasi(
        (p['x'] as num).toDouble(),
        (p['y'] as num).toDouble(),
        (p['w'] as num).toDouble(),
        (p['h'] as num).toDouble(),
        p['t'] as String,
      ),
  ];
}

void _dogrula(Dokum d) {
  final beklenen = [
    (20261121, 'EPOS MIGROS SANAL MARKET 1234 5678', 25040, false, 123456),
    (20261121, 'EPOS SPOTIFY*PREMIUM 1234 5678', 9999, false, 148496),
    (20261121, 'GELEN FAST - AD SOYAD - kendi hesabım', 100000, true, 158495),
    (
      20261121,
      'GELEN FAST - AD SOYAD - kendi hesabıma para gönderme',
      50000,
      true,
      58495,
    ),
  ];
  expect(d.banka, 'Yapı Kredi');
  expect(d.satirlar, hasLength(4));
  for (var i = 0; i < 4; i++) {
    final s = d.satirlar[i], b = beklenen[i];
    expect((s.gun, s.aciklama, s.tutarKurus, s.gelir, s.bakiyeKurus), b);
  }
  expect(d.sonBakiyeKurus, 123456);
  expect(d.atlanan, 0);
  expect(d.tutarsiz, isFalse);
}

void main() {
  test('örnek dökümden 4 satır birebir', () => _dogrula(yapiKrediOku(_ornek())!));

  test('parça sırası karışınca aynı sonuç', () {
    final p = _ornek();
    _dogrula(yapiKrediOku(p.reversed.toList())!);
    _dogrula(yapiKrediOku((p..shuffle()).toList())!);
  });

  test('tanınmayan belge null', () {
    expect(yapiKrediOku([const MetinParcasi(0, 0, 10, 10, 'merhaba')]), isNull);
    expect(yapiKrediOku([]), isNull);
  });

  test('bozuk tutar atlanır, sayılır', () {
    final p = _ornek()
        .map((e) => e.t == '-250,40 TL' ? MetinParcasi(e.x, e.y, e.w, e.h, '25x,40 TL') : e)
        .toList();
    final d = yapiKrediOku(p)!;
    expect(d.satirlar, hasLength(3));
    expect(d.atlanan, 1);
  });

  test('geçersiz tarih ve üst sınır aşan tutar atlanır', () {
    final p = _ornek().map((e) {
      if (e.t == '21/11/2026' && e.y == 245.2) {
        return MetinParcasi(e.x, e.y, e.w, e.h, '31/02/2026');
      }
      if (e.t == '-99,99 TL') {
        return MetinParcasi(e.x, e.y, e.w, e.h, '-9.999.999.999,99 TL');
      }
      return e;
    }).toList();
    final d = yapiKrediOku(p)!;
    expect(d.satirlar, hasLength(2));
    expect(d.atlanan, 2);
  });

  test('U+FFFD açıklamada ? olur', () {
    final p = _ornek()
        .map((e) => e.t == 'hesabım' ? MetinParcasi(e.x, e.y, e.w, e.h, 'hesab�m') : e)
        .toList();
    expect(yapiKrediOku(p)!.satirlar[2].aciklama, 'GELEN FAST - AD SOYAD - kendi hesab?m');
  });

  test('tutarlar bakiyeyle uyuşmazsa tutarsiz', () {
    final p = _ornek()
        .map((e) => e.t == '-250,40 TL' ? MetinParcasi(e.x, e.y, e.w, e.h, '-251,40 TL') : e)
        .toList();
    expect(yapiKrediOku(p)!.tutarsiz, isTrue);
  });

  test('parcalariBirlestir: boşluk karakteri sözcük arası, büyük x boşluğu ve satır sonu keser', () {
    MetinParcasi k(double x, String t, {double y = 10}) => MetinParcasi(x, y, 5, 10, t);
    final r = parcalariBirlestir([
      k(100, 'A'), k(105, 'B'), k(110, ' '), k(113, 'C'),
      k(200, 'X'), // 1,5 x 10'dan büyük boşluk: ayrı parça
      k(100, 'Y', y: 30), k(105, '\r'), k(105, '\n'), k(105, 'Z', y: 30), // satır sonu keser
    ]);
    expect(r.map((e) => e.t).toList(), ['AB C', 'X', 'Y', 'Z']);
    expect(r.first.x, 100);
  });

  test('parcalariBirlestir: gerçek pdfium karakter kutularından 4 satır birebir', () {
    final j = jsonDecode(File('test/ornekler/yapikredi_karakterler.json').readAsStringSync());
    final k = [
      for (final c in j as List)
        MetinParcasi(
          (c[1] as num).toDouble(),
          (c[2] as num).toDouble(),
          (c[3] as num).toDouble(),
          (c[4] as num).toDouble(),
          c[0] as String,
        ),
    ];
    final parcalar = parcalariBirlestir(k);
    expect(parcalar.map((p) => p.t), containsAll(['1.234,56 TL', '1.000,00 TL', '-250,40 TL']));
    _dogrula(yapiKrediOku(parcalar)!);
  });

  test('int64 taşıran tutar ve bakiye çökertmez, satır atlanır', () {
    const dev = '-999.999.999.999.999.999.999,99 TL';
    final p = _ornek()
        .map((e) => e.t == '-250,40 TL' ? MetinParcasi(e.x, e.y, e.w, e.h, dev) : e)
        .toList();
    final d = yapiKrediOku(p)!;
    expect(d.satirlar, hasLength(3));
    expect(d.atlanan, 1);
    final b = _ornek()
        .map((e) => e.t == '1.234,56 TL' ? MetinParcasi(e.x, e.y, e.w, e.h, '9.999.999.999.999.999.999,99 TL') : e)
        .toList();
    expect(yapiKrediOku(b)!.satirlar, hasLength(4));
  });

  // Gerçek Yapı Kredi dökümünün satır konumları (metinler uydurma): iki satırlı açıklamanın
  // son satırı tarihle aynı y'de, ilk satırı üstte durur; satır aralığı her yerde ~14.
  // Orta nokta bandı burada sınırın üstüne düşüp açıklamayı önceki satıra kaydırıyordu.
  for (final kayma in [0.0, -2.0, 2.0]) {
    test('gerçek satır geometrisi: açıklama kendi satırında (kayma $kayma)', () {
      final ust = _ornek().where((p) => p.y < 225 || p.y > 800).toList();
      MetinParcasi m(double x, double y, String t) => MetinParcasi(x, y, 40, 9, t);
      MetinParcasi a(double y, String t) => m(276, y + kayma, t);
      final veri = [
        m(28, 231, '-'), m(85, 231, '-'), a(231, 'Diğer Bekleyen İşlemler'), m(470, 231, '0,00 TL'), m(564, 231, '-'),
        m(28, 245, '21/11/2026'), m(85, 245, '16:03:43'), a(245, 'EPOS MIGROS SANAL MARKET  1234 5678'),
        m(458, 245, '-250,40 TL'), m(525, 245, '1.234,56 TL'),
        m(28, 274, '21/11/2026'), m(85, 274, '15:33:48'), a(260, 'EPOS SPOTIFY*PREMIUM 1234'), a(274, '5678'),
        m(458, 274, '-99,99 TL'), m(525, 274, '1.484,96 TL'),
        m(28, 302, '21/11/2026'), m(85, 302, '15:21:33'), a(288, 'GELEN FAST - AD SOYAD - kendi'), a(302, 'hesabım'),
        m(454, 302, '1.000,00 TL'), m(525, 302, '1.584,95 TL'),
        m(28, 331, '21/11/2026'), m(85, 331, '15:19:54'), a(317, 'GELEN FAST - AD SOYAD - kendi'),
        a(331, 'hesabıma para gönderme'), m(454, 331, '500,00 TL'), m(525, 331, '584,95 TL'),
      ];
      _dogrula(yapiKrediOku([...ust, ...veri])!);
    });
  }

  test('çok sayfa: önceki sayfanın alt bilgisi sonraki sayfanın ilk satırına karışmaz', () {
    final ornek = _ornek();
    // İkinci sayfa: aynı parçalar 10000 aşağıda, ilk sayfanın alt bilgisi (y > 800) arada kalır.
    final ikinci = [
      for (final p in ornek)
        if (p.y > 225 && p.y < 800) MetinParcasi(p.x, p.y + 10000, p.w, p.h, p.t),
    ];
    final baslik = [
      for (final p in ornek)
        if ((p.y - ornek.firstWhere((e) => e.t.trim() == 'Tarih').y).abs() < 2)
          MetinParcasi(p.x, p.y + 10000, p.w, p.h, p.t),
    ];
    final d = yapiKrediOku([...ornek, ...baslik, ...ikinci])!;
    expect(d.satirlar, hasLength(8));
    expect(d.atlanan, 0);
    expect(d.satirlar[4].aciklama, 'EPOS MIGROS SANAL MARKET 1234 5678');
    expect(d.satirlar[4].tutarKurus, 25040);
  });
}
