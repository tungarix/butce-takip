// Saf Dart: arayüz ve veritabanı içe aktarılmaz.
import '../core/tarih.dart';

/// Tekrar tespitinin ve tahminin girdisi: tek bir gider işlemi.
typedef GiderKaydi = ({
  int tutar,
  int kategoriId,
  String noteNorm,
  String not,
  int gun,
});

/// Tespit penceresi (gün).
const tekrarPencere = 120;

// Beklenen güne bu kadar gün kala öneri çıkar; geçtikten sonra da bu kadar gün çıkmaya devam eder.
const _once = 3;
const _sonra = 7;

class TekrarGrubu {
  const TekrarGrubu({
    required this.anahtar,
    required this.kategoriId,
    required this.tutar,
    required this.not,
    required this.periyot,
    required this.sonGun,
  });

  /// Kararlı grup anahtarı (reddedilenler settings'te bununla durur).
  final String anahtar;
  final int kategoriId;

  /// Medyan tutar (kuruş).
  final int tutar;

  /// Son kaydın notu (özgün yazılışıyla).
  final String not;

  /// Ardışık gün farklarının medyanı.
  final int periyot;
  final int sonGun;

  int get beklenenGun => gunEkle(sonGun, periyot);
}

/// Not boşsa kategori + tutar, doluysa normalize not.
String tekrarAnahtari(GiderKaydi g) => g.noteNorm.isNotEmpty
    ? 'n:${g.noteNorm}'
    : '${tekrarKategoriOnEki(g.kategoriId)}${g.tutar}';

/// Notsuz tekrar anahtarlarının kategoriye özel başı (ayraç dahil).
String tekrarKategoriOnEki(int kategoriId) => 'k:$kategoriId:';

int _medyan(List<int> l) {
  final s = [...l]..sort();
  final o = s.length ~/ 2;
  return s.length.isOdd ? s[o] : (s[o - 1] + s[o]) ~/ 2;
}

/// Son 120 günün [giderler]inden tekrarlayan gruplar: en az 3 kayıt, gün farkı medyanı 28-32
/// (aylık) ya da 6-8 (haftalık), her tutar medyan tutardan en çok %10 sapar.
/// [bugun]'den sonraki (ileri tarihli) kayıtlar da gruba girer: biri girilmişse sıradaki dönem de dolmuştur.
List<TekrarGrubu> tekrarlayanGruplar(List<GiderKaydi> giderler, int bugun) {
  final ilk = gunEkle(bugun, -tekrarPencere);
  final gruplar = <String, List<GiderKaydi>>{};
  for (final g in giderler) {
    if (g.gun >= ilk) (gruplar[tekrarAnahtari(g)] ??= []).add(g);
  }
  final sonuc = <TekrarGrubu>[];
  for (final e in gruplar.entries) {
    final l = e.value;
    if (l.length < 3) continue;
    l.sort((a, b) => a.gun.compareTo(b.gun));
    final fark = _medyan([
      for (var i = 1; i < l.length; i++) gunFarki(l[i - 1].gun, l[i].gun),
    ]);
    if (!((fark >= 28 && fark <= 32) || (fark >= 6 && fark <= 8))) continue;
    final tutar = _medyan([for (final g in l) g.tutar]);
    if (l.any((g) => (g.tutar - tutar).abs() * 100 > tutar * 10)) continue;
    sonuc.add(
      TekrarGrubu(
        anahtar: e.key,
        kategoriId: l.last.kategoriId,
        tutar: tutar,
        not: l.last.not,
        periyot: fark,
        sonGun: l.last.gun,
      ),
    );
  }
  return sonuc;
}

/// Beklenen güne 3 gün ya da daha az kalan, ya da geçeli en çok 7 gün olan, reddedilmemiş gruplar.
/// "O dönemde zaten eşleşen kayıt" ayrıca aranmaz: beklenen gün son kayıttan hesaplanır;
/// dönem için kayıt girilmişse son kayıt o olur ve beklenen gün bir dönem ileri gider.
List<TekrarGrubu> tekrarOnerileri(
  List<GiderKaydi> giderler,
  int bugun, {
  Set<String> reddedilen = const {},
}) {
  final l = tekrarlayanGruplar(giderler, bugun).where((g) {
    if (reddedilen.contains(g.anahtar)) return false;
    final kalan = gunFarki(bugun, g.beklenenGun);
    return kalan <= _once && kalan >= -_sonra;
  }).toList();
  return l..sort((a, b) => a.beklenenGun.compareTo(b.beklenenGun));
}
