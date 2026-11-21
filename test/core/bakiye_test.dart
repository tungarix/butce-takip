import 'package:butce_takip/core/butce.dart';
import 'package:butce_takip/core/para.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toplamBakiye: açılış + gelir - gider, eksi olabilir', () {
    expect(toplamBakiye(1000, 5000, 2000), 4000);
    expect(toplamBakiye(0, 100, 900), -800);
    expect(toplamBakiye(-500, 0, 0), -500);
  });

  test('sıfır veri: bakiye açılışa eşit', () {
    expect(toplamBakiye(0, 0, 0), 0);
    expect(bankaBakiyesindenAcilis(0, 0, 0), 0);
  });

  test('bankaya eşitleme gidiş-dönüş (eksi banka ve eksi fark dahil)', () {
    for (final banka in [123456, 0, -98765, paraUstSinirKurus]) {
      final acilis = bankaBakiyesindenAcilis(banka, 700000, 250000);
      expect(toplamBakiye(acilis, 700000, 250000), banka);
    }
    final acilis = bankaBakiyesindenAcilis(100, 0, 5000);
    expect(acilis, 5100);
  });

  test('üst sınır: sınırdaki kabul, aşan red (iki işaret)', () {
    expect(bankaBakiyesindenAcilis(paraUstSinirKurus, 0, 0), paraUstSinirKurus);
    expect(
      bankaBakiyesindenAcilis(-paraUstSinirKurus, 0, 0),
      -paraUstSinirKurus,
    );
    expect(
      () => bankaBakiyesindenAcilis(paraUstSinirKurus + 1, 0, 0),
      throwsRangeError,
    );
    expect(
      () => bankaBakiyesindenAcilis(-paraUstSinirKurus - 1, 0, 0),
      throwsRangeError,
    );
  });
}
