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
}
