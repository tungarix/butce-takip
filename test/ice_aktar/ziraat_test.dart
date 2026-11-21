import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:butce_takip/ice_aktar/dokum.dart';
import 'package:butce_takip/ice_aktar/yapikredi.dart';
import 'package:butce_takip/ice_aktar/ziraat.dart';
import 'package:flutter_test/flutter_test.dart';

List<MetinParcasi> _ornek({
  double olcek = 1,
  double Function()? oynama,
  String Function(MetinParcasi)? metin,
}) {
  final j = jsonDecode(
    File('test/ornekler/ziraat_kelimeler.json').readAsStringSync(),
  );
  double o() => oynama?.call() ?? 0;
  return [
        for (final p in j['kelimeler'] as List)
          MetinParcasi(
            ((p['x'] as num) + o()) * olcek,
            ((p['y'] as num) + o()) * olcek,
            (p['w'] as num) * olcek.toDouble(),
            (p['h'] as num) * olcek.toDouble(),
            p['t'] as String,
          ),
      ]
      .map(
        (p) => metin == null ? p : MetinParcasi(p.x, p.y, p.w, p.h, metin(p)),
      )
      .toList();
}

void _dogrula(Dokum? d) {
  final beklenen = [
    (
      20261121,
      'kendi hesabım 000000000 - 5002 Nolu Hesaptan, Ziraat Mobil Virman',
      100000,
      true,
      123456,
    ),
    (20261115, 'MIGROS SANAL MARKET ODEME', 25344, false, 23456),
    (20261105, 'ISTANBULKART YUKLEME', 10000, false, 48800),
    (
      20261030,
      'VODAFONE NO: 5550000000 /fat no: FD00000000000',
      41200,
      false,
      58800,
    ),
  ];
  expect(d, isNotNull);
  expect(d!.ocr, isTrue);
  expect(d.satirlar, hasLength(4));
  for (var i = 0; i < 4; i++) {
    final s = d.satirlar[i];
    expect((
      s.gun,
      s.aciklama,
      s.tutarKurus,
      s.gelir,
      s.bakiyeKurus,
    ), beklenen[i]);
  }
  expect(d.sonBakiyeKurus, 123456);
  expect(d.atlanan, 0);
  expect(d.tutarsiz, isFalse);
}

void main() {
  test(
    'örnek JSON: 4 satır birebir, toplamlar tutarlı',
    () => _dogrula(ziraatOku(_ornek())),
  );

  test('karışık sırada aynı sonuç', () {
    _dogrula(ziraatOku(_ornek().reversed.toList()));
    final k = _ornek()..shuffle(Random(7));
    _dogrula(ziraatOku(k));
  });

  test('2x ölçek', () => _dogrula(ziraatOku(_ornek(olcek: 2))));

  test('±2 px oynama', () {
    final r = Random(3);
    _dogrula(ziraatOku(_ornek(oynama: () => r.nextDouble() * 4 - 2)));
  });

  test('bölünmüş tutar kelimesi birleşir', () {
    final k = _ornek();
    final i = k.indexWhere((p) => p.t == '1.000,00' && p.x == 805);
    final p = k.removeAt(i);
    k.addAll([
      MetinParcasi(p.x, p.y, 40, p.h, '1.000,'),
      MetinParcasi(p.x + 44, p.y, 12, p.h, '00'),
    ]);
    _dogrula(ziraatOku(k));
  });

  test('bozuk okunan tutar satırı atlar ve tutarsız sayılır', () {
    final d = ziraatOku(
      _ornek(metin: (p) => p.t == '-253,44' ? '-253,S4' : p.t),
    )!;
    expect(d.satirlar, hasLength(3));
    expect(d.atlanan, 1);
    expect(d.tutarsiz, isTrue);
    expect(d.satirlar.map((s) => s.tutarKurus), isNot(contains(25344)));
  });

  test('Borç toplamı uyuşmazsa tutarsız', () {
    final d = ziraatOku(
      _ornek(metin: (p) => p.t == '-765,44' ? '-765,45' : p.t),
    )!;
    expect(d.satirlar, hasLength(4));
    expect(d.tutarsiz, isTrue);
  });

  test('bakiye zinciri tutmazsa tutarsız', () {
    final d = ziraatOku(
      _ornek(metin: (p) => p.t == '234,56' ? '234,57' : p.t),
    )!;
    expect(d.tutarsiz, isTrue);
  });

  test('tanınmayan belge null', () {
    expect(ziraatOku(const []), isNull);
    expect(ziraatOku([const MetinParcasi(0, 0, 10, 10, 'Merhaba')]), isNull);
    expect(ziraatOku(_ornek().where((p) => p.t != 'Bakiye').toList()), isNull);
    // 'ziraat' hiçbir kelimede yoksa tanınmaz (logo, açıklama ve alt bilgi dahil).
    expect(
      ziraatOku(
        _ornek(metin: (p) => p.t.toLowerCase().contains('ziraat') ? 'X' : p.t),
      ),
      isNull,
    );
  });

  test('Yapı Kredi parçaları ziraatOku\'da null, ziraat parçaları yapiKrediOku\'da null', () {
    final j = jsonDecode(
      File('test/ornekler/yapikredi_parcalar.json').readAsStringSync(),
    );
    final yk = [
      for (final p in j['parcalar'] as List)
        MetinParcasi(
          (p['x'] as num).toDouble(),
          (p['y'] as num).toDouble(),
          (p['w'] as num).toDouble(),
          (p['h'] as num).toDouble(),
          p['t'] as String,
        ),
    ];
    expect(ziraatOku(yk), isNull);
    expect(yapiKrediOku(_ornek()), isNull);
  });
}
