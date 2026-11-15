// Limit yüzdesi ve özet hesabı. Saf Dart: arayüz ve veritabanı içe aktarılmaz.
// Aşama 4'teki aşım bildirimi de aynı fonksiyonları kullanır.

enum LimitDurumu { normal, uyari, asim }

/// harcanan * 100 ~/ limit. Limit yoksa (<= 0) 0.
int limitYuzdesi(int harcananKurus, int limitKurus) =>
    limitKurus <= 0 ? 0 : harcananKurus * 100 ~/ limitKurus;

/// %80'e kadar normal, %80-99 uyarı, %100 ve üstü aşım.
LimitDurumu limitDurumu(int yuzde) => yuzde >= 100
    ? LimitDurumu.asim
    : yuzde >= 80
    ? LimitDurumu.uyari
    : LimitDurumu.normal;

typedef LimitSatiri = ({
  int kategoriId,
  int harcanan,
  int limit,
  int yuzde,
  LimitDurumu durum,
});

class Ozet {
  const Ozet({
    required this.harcanan,
    required this.limitToplami,
    required this.kalan,
    required this.limitli,
    required this.limitsiz,
  });

  /// Bu ay tüm gider kategorilerinin (arşivliler dahil) toplamı.
  final int harcanan;

  /// Limitli ve arşivli olmayan kategorilerin limit toplamı; hiç limit yoksa null.
  final int? limitToplami;

  /// limitToplami - limitli kategorilerin harcaması; eksiye düşebilir. Limit yoksa null.
  final int? kalan;

  /// Yüzdesi büyükten küçüğe.
  final List<LimitSatiri> limitli;

  /// Limiti olmayan (ya da arşivli) ama bu ay harcaması olan kategoriler, tutarı büyükten küçüğe.
  final List<({int kategoriId, int harcanan})> limitsiz;
}

/// [giderler]: kategori -> bu ayki gider toplamı (arşivliler dahil).
/// [limitler]: kategori -> aylık limit. [limitGecerli]: limiti işleyen (arşivli olmayan gider) kategoriler.
Ozet ozetHesapla({
  required Map<int, int> giderler,
  required Map<int, int> limitler,
  required Set<int> limitGecerli,
}) {
  final limitli = <LimitSatiri>[];
  final limitsiz = <({int kategoriId, int harcanan})>[];
  var limitToplami = 0;
  var limitliHarcanan = 0;
  for (final id in {
    ...limitler.keys.where(limitGecerli.contains),
    ...giderler.keys,
  }) {
    final harcanan = giderler[id] ?? 0;
    final limit = limitGecerli.contains(id) ? limitler[id] : null;
    if (limit == null || limit <= 0) {
      if (harcanan > 0) limitsiz.add((kategoriId: id, harcanan: harcanan));
      continue;
    }
    final y = limitYuzdesi(harcanan, limit);
    limitli.add((
      kategoriId: id,
      harcanan: harcanan,
      limit: limit,
      yuzde: y,
      durum: limitDurumu(y),
    ));
    limitToplami += limit;
    limitliHarcanan += harcanan;
  }
  limitli.sort((a, b) => b.yuzde.compareTo(a.yuzde));
  limitsiz.sort((a, b) => b.harcanan.compareTo(a.harcanan));
  return Ozet(
    harcanan: giderler.values.fold(0, (a, b) => a + b),
    limitToplami: limitli.isEmpty ? null : limitToplami,
    kalan: limitli.isEmpty ? null : limitToplami - limitliHarcanan,
    limitli: limitli,
    limitsiz: limitsiz,
  );
}
