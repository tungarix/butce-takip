// Saf Dart.

typedef AnahtarSatiri = ({String keyword, int categoryId, int hits});

/// Notun [sozcukler]i için [satirlar]daki (keyword_hits) hits'ler kategori başına toplanır;
/// en yüksek skorlu kategorinin id'si döner, skor yoksa null. Yalnız [uygun] kategoriler
/// (türü uyan, arşivli olmayan) önerilir; eşitlikte [uygun]daki sırası önde olan kazanır.
int? kategoriOner(
  List<String> sozcukler,
  Iterable<AnahtarSatiri> satirlar,
  List<int> uygun,
) {
  final skor = <int, int>{};
  for (final s in satirlar) {
    if (sozcukler.contains(s.keyword) && uygun.contains(s.categoryId)) {
      skor[s.categoryId] = (skor[s.categoryId] ?? 0) + s.hits;
    }
  }
  int? en;
  for (final id in uygun) {
    if ((skor[id] ?? 0) > (en == null ? 0 : skor[en]!)) en = id;
  }
  return en;
}
