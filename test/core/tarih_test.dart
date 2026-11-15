import 'package:butce_takip/core/tarih.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gunAnahtari ve ayAnahtari', () {
    expect(gunAnahtari(DateTime(2026, 3, 5)), 20260305);
    expect(ayAnahtari(DateTime(2026, 3, 5)), 202603);
  });

  test('gece 23:59 ve 00:01 ayrı günlere düşer', () {
    expect(gunAnahtari(DateTime(2026, 3, 31, 23, 59)), 20260331);
    expect(gunAnahtari(DateTime(2026, 4, 1, 0, 1)), 20260401);
    expect(ayAnahtari(DateTime(2026, 3, 31, 23, 59)), 202603);
    expect(ayAnahtari(DateTime(2026, 4, 1, 0, 1)), 202604);
  });

  test('yıl geçişi', () {
    expect(gunAnahtari(DateTime(2026, 12, 31, 23, 59)), 20261231);
    expect(gunAnahtari(DateTime(2027, 1, 1, 0, 1)), 20270101);
    expect(ayAnahtari(DateTime(2027, 1, 1)), 202701);
  });

  test('UTC girdi yerel güne çevrilir', () {
    final u = DateTime.utc(2026, 6, 15, 12);
    expect(gunAnahtari(u), gunAnahtari(u.toLocal()));
  });

  test('ayGunSayisi: 28/29/30/31', () {
    expect(ayGunSayisi(2026, 2), 28);
    expect(ayGunSayisi(2028, 2), 29);
    expect(ayGunSayisi(1900, 2), 28);
    expect(ayGunSayisi(2000, 2), 29);
    expect(ayGunSayisi(2026, 4), 30);
    expect(ayGunSayisi(2026, 1), 31);
    expect(ayGunSayisi(2026, 12), 31);
  });

  test('ayAraligi', () {
    expect(ayAraligi(202602), (ilk: 20260201, son: 20260228));
    expect(ayAraligi(202802), (ilk: 20280201, son: 20280229));
    expect(ayAraligi(202604), (ilk: 20260401, son: 20260430));
    expect(ayAraligi(202612), (ilk: 20261201, son: 20261231));
  });
}
