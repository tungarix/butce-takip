import 'package:butce_takip/core/butce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('limitYuzdesi', () {
    test('limit yoksa (0 ya da eksi) 0, sıfıra bölme yok', () {
      expect(limitYuzdesi(5000, 0), 0);
      expect(limitYuzdesi(5000, -1), 0);
      expect(limitYuzdesi(0, 0), 0);
    });

    test('tam sayı bölme: aşağı yuvarlanır', () {
      expect(limitYuzdesi(0, 10000), 0);
      expect(limitYuzdesi(7900, 10000), 79);
      expect(limitYuzdesi(7999, 10000), 79);
      expect(limitYuzdesi(8000, 10000), 80);
      expect(limitYuzdesi(9999, 10000), 99);
      expect(limitYuzdesi(10000, 10000), 100);
      expect(limitYuzdesi(25000, 10000), 250);
    });

    test('çok büyük tutarlar taşmaz', () {
      const ust = 99999999999; // 999.999.999,99 ₺
      expect(limitYuzdesi(ust, ust), 100);
      expect(limitYuzdesi(ust, 1), ust * 100);
      expect(limitYuzdesi(ust * 1000, ust), 100000);
    });
  });

  test('limitDurumu: 79 normal, 80-99 uyarı, 100+ aşım', () {
    expect(limitDurumu(0), LimitDurumu.normal);
    expect(limitDurumu(79), LimitDurumu.normal);
    expect(limitDurumu(80), LimitDurumu.uyari);
    expect(limitDurumu(99), LimitDurumu.uyari);
    expect(limitDurumu(100), LimitDurumu.asim);
    expect(limitDurumu(250), LimitDurumu.asim);
  });

  group('ozetHesapla', () {
    test('limit yoksa kalan null, hepsi limitsiz, toplam tüm harcama', () {
      final o = ozetHesapla(
        giderler: {1: 3000, 2: 7000},
        limitler: {},
        limitGecerli: {1, 2},
      );
      expect(o.harcanan, 10000);
      expect(o.limitToplami, isNull);
      expect(o.kalan, isNull);
      expect(o.limitli, isEmpty);
      expect(o.limitsiz.map((s) => s.kategoriId), [2, 1]);
    });

    test(
      'kalan eksiye düşebilir; yalnız limitli kategorilerin harcaması düşülür',
      () {
        final o = ozetHesapla(
          giderler: {1: 12000, 2: 50000},
          limitler: {1: 10000},
          limitGecerli: {1, 2},
        );
        expect(o.harcanan, 62000);
        expect(o.limitToplami, 10000);
        expect(o.kalan, -2000);
        expect(o.limitli.single.yuzde, 120);
        expect(o.limitli.single.durum, LimitDurumu.asim);
        expect(o.limitsiz.single.kategoriId, 2);
      },
    );

    test(
      'harcamasız limitli kategori çubukta görünür; yüzdeye göre sıralı',
      () {
        final o = ozetHesapla(
          giderler: {2: 9000},
          limitler: {1: 10000, 2: 10000},
          limitGecerli: {1, 2},
        );
        expect(o.limitli.map((s) => (s.kategoriId, s.yuzde)), [
          (2, 90),
          (1, 0),
        ]);
        expect(o.kalan, 11000);
      },
    );

    test('arşivli kategori limiti işlemez ama harcaması toplama ve limitsize girer', () {
      final o = ozetHesapla(
        giderler: {1: 4000, 3: 6000},
        limitler: {1: 10000, 3: 5000},
        limitGecerli: {1}, // 3 arşivli
      );
      expect(o.harcanan, 10000);
      expect(o.limitToplami, 10000);
      expect(o.kalan, 6000);
      expect(o.limitsiz.single, (kategoriId: 3, harcanan: 6000));
    });
  });
}
