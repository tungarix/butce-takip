import 'package:butce_takip/core/para.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('paraYaz', () {
    test('biçim', () {
      expect(paraYaz(123450), '1.234,50 ₺');
      expect(paraYaz(0), '0,00 ₺');
      expect(paraYaz(1), '0,01 ₺');
      expect(paraYaz(100), '1,00 ₺');
      expect(paraYaz(99999), '999,99 ₺');
      expect(paraYaz(100000), '1.000,00 ₺');
      expect(paraYaz(123456789), '1.234.567,89 ₺');
      expect(paraYaz(paraUstSinirKurus), '999.999.999,99 ₺');
    });

    test('eksi değer', () {
      expect(paraYaz(-5), '-0,05 ₺');
      expect(paraYaz(-123450), '-1.234,50 ₺');
    });
  });

  group('tuş takımı', () {
    int gir(String rakamlar) =>
        rakamlar.split('').fold(0, (m, r) => tusaBas(m, int.parse(r)));

    test('sağdan dolar', () {
      expect(gir('5'), 5); // 0,05
      expect(gir('52'), 52);
      expect(gir('523'), 523); // 5,23
      expect(gir('150000'), 150000); // 1.500,00
    });

    test('0 ve 1 kuruş', () {
      expect(gir('0'), 0);
      expect(gir('000'), 0);
      expect(gir('1'), 1);
      expect(paraYaz(gir('1')), '0,01 ₺');
    });

    test('geri tuşu son rakamı atar', () {
      expect(tusSil(523), 52);
      expect(tusSil(5), 0);
      expect(tusSil(0), 0);
    });

    test('üst sınır aşılmaz, sınırda kalır', () {
      expect(tusaBas(paraUstSinirKurus, 0), paraUstSinirKurus);
      expect(tusaBas(paraUstSinirKurus, 9), paraUstSinirKurus);
      // Sınıra tam oturan son basış kabul edilir, bir sonraki reddedilir.
      expect(tusaBas(9999999999, 9), paraUstSinirKurus);
      expect(
        tusaBas(paraUstSinirKurus ~/ 10 + 1, 0),
        paraUstSinirKurus ~/ 10 + 1,
      );
    });
  });
}
