import 'package:butce_takip/core/tarih.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ayKaydir: yıl geçişi ve geri', () {
    expect(ayKaydir(202611, 1), 202612);
    expect(ayKaydir(202612, 1), 202701);
    expect(ayKaydir(202601, -1), 202512);
    expect(ayKaydir(202603, -15), 202412);
    expect(ayKaydir(202603, 0), 202603);
  });
  test('gunTarihi, gunAnahtari tersi', () {
    expect(gunTarihi(20240229), DateTime(2024, 2, 29));
    expect(gunAnahtari(gunTarihi(20261231)), 20261231);
  });
}
