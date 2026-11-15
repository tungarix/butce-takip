import 'package:butce_takip/akilli/kategori_onerici.dart';
import 'package:flutter_test/flutter_test.dart';

AnahtarSatiri _s(String k, int kat, int hits) =>
    (keyword: k, categoryId: kat, hits: hits);

void main() {
  final satirlar = [
    _s('migros', 1, 5),
    _s('migros', 2, 2),
    _s('kasap', 2, 9),
    _s('netflix', 8, 1),
  ];

  test(
    'en yüksek skorlu kategori; sözcük skorları kategori başına toplanır',
    () {
      expect(kategoriOner(['migros'], satirlar, [1, 2, 8]), 1);
      expect(
        kategoriOner(['migros', 'kasap'], satirlar, [1, 2, 8]),
        2,
        reason: '2+9 > 5',
      );
      expect(kategoriOner(['netflix'], satirlar, [1, 2, 8]), 8);
    },
  );

  test('eşleşme yoksa null; satırlarda olmayan sözcük sayılmaz', () {
    expect(kategoriOner(['bilinmeyen'], satirlar, [1, 2, 8]), isNull);
    expect(kategoriOner([], satirlar, [1, 2, 8]), isNull);
  });

  test('uygun olmayan (arşivli ya da türü uymayan) kategori önerilmez', () {
    expect(
      kategoriOner(['migros'], satirlar, [2, 8]),
      2,
      reason: '1 uygun değil',
    );
    expect(kategoriOner(['netflix'], satirlar, [1, 2]), isNull);
  });

  test('eşit skorda uygun listesindeki sırası önde olan kazanır', () {
    final esit = [_s('market', 3, 2), _s('market', 4, 2)];
    expect(kategoriOner(['market'], esit, [4, 3]), 4);
    expect(kategoriOner(['market'], esit, [3, 4]), 3);
  });
}
