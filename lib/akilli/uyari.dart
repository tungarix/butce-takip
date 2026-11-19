// Saf Dart: arayüz, veritabanı ve bildirim eklentisi içe aktarılmaz.
import '../core/butce.dart';

const uyariEsikleri = [80, 100];

/// settings anahtarı: ay + kategori + eşik başına bir kez.
String uyariAnahtari(int kategoriId, int ay, int esik) =>
    '${uyariKategoriOnEki(kategoriId)}${ay}_$esik';

/// Bir kategorinin tüm uyarı anahtarlarının ortak başı (ayraç dahil: 1, 11'e karışmaz).
String uyariKategoriOnEki(int kategoriId) => 'alert_${kategoriId}_';

typedef UyariKarari = ({int esik, List<String> anahtarlar});

/// Bu kayıt [once] toplamını [sonra]ya taşıdığında hangi bildirim gerekir; gerekmiyorsa null.
/// Yalnız bu kayıtla aşılan (önce altında, şimdi üstünde) ve henüz gönderilmemiş eşikler sayılır;
/// birden çok eşik birden aşılırsa yalnız en yüksek bildirilir, [anahtarlar] hepsini işaretler.
UyariKarari? uyariKarari({
  required int kategoriId,
  required int ay,
  required int once,
  required int sonra,
  required int? limit,
  required Set<String> gonderilen,
  required bool acik,
}) {
  if (!acik || limit == null || limit <= 0) return null;
  final y0 = limitYuzdesi(once, limit);
  final y1 = limitYuzdesi(sonra, limit);
  final asilan = [
    for (final e in uyariEsikleri)
      if (y0 < e &&
          y1 >= e &&
          !gonderilen.contains(uyariAnahtari(kategoriId, ay, e)))
        e,
  ];
  if (asilan.isEmpty) return null;
  final esik = asilan.last;
  return (
    esik: esik,
    anahtarlar: [
      for (final e in uyariEsikleri)
        if (e <= esik) uyariAnahtari(kategoriId, ay, e),
    ],
  );
}
