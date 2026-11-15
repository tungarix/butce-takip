import 'package:butce_takip/akilli/uyari.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const limit = 10000;

  UyariKarari? karar(
    int once,
    int sonra, {
    Set<String> gonderilen = const {},
    int ay = 202603,
    int? limitDegeri = limit,
    bool acik = true,
  }) => uyariKarari(
    kategoriId: 1,
    ay: ay,
    once: once,
    sonra: sonra,
    limit: limitDegeri,
    gonderilen: gonderilen,
    acik: acik,
  );

  test('79 -> 80: %80 bildirimi bir kez', () {
    final k = karar(7900, 8000)!;
    expect(k.esik, 80);
    expect(k.anahtarlar, ['alert_1_202603_80']);
    expect(karar(7900, 8000, gonderilen: {'alert_1_202603_80'}), isNull);
  });

  test('80 -> 85: yeniden bildirim yok', () {
    expect(karar(8000, 8500), isNull);
    expect(karar(8500, 9900), isNull);
  });

  test('99 -> 100: %100 bildirimi bir kez', () {
    final k = karar(9900, 10000)!;
    expect(k.esik, 100);
    expect(karar(9900, 10000, gonderilen: {'alert_1_202603_100'}), isNull);
    expect(karar(10000, 12000), isNull, reason: 'zaten %100 üstündeydi');
  });

  test('doğrudan 0 -> 120: yalnız %100 bildirimi, ikisi de işaretlenir', () {
    final k = karar(0, 12000)!;
    expect(k.esik, 100);
    expect(k.anahtarlar, ['alert_1_202603_80', 'alert_1_202603_100']);
  });

  test('80 gönderilmişken 85 -> 100 yalnız %100 verir', () {
    final k = karar(8500, 10000, gonderilen: {'alert_1_202603_80'})!;
    expect(k.esik, 100);
  });

  test('yeni ayda yeniden bildirilir; başka kategori ayrı sayılır', () {
    final eski = {'alert_1_202603_80', 'alert_1_202603_100'};
    expect(karar(7900, 8000, gonderilen: eski, ay: 202604)!.esik, 80);
    expect(karar(7900, 8000, gonderilen: eski), isNull);
    expect(
      uyariKarari(
        kategoriId: 2,
        ay: 202603,
        once: 7900,
        sonra: 8000,
        limit: limit,
        gonderilen: eski,
        acik: true,
      )!.esik,
      80,
    );
  });

  test('bildirim kapalıyken ya da limit yokken karar yok', () {
    expect(karar(7900, 8000, acik: false), isNull);
    expect(karar(7900, 12000, limitDegeri: null), isNull);
    expect(karar(7900, 12000, limitDegeri: 0), isNull);
  });

  test('tutar azalan kayıt (düzenleme) bildirim üretmez', () {
    expect(karar(9000, 5000), isNull);
  });
}
