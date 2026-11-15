// Gün ve ay anahtarları. Hepsi yerel takvim günüdür; UTC'ye çevrilip gün kaymaz.
// Saf Dart: arayüz ve veritabanı içe aktarılmaz.

DateTime _yerel(DateTime d) => d.isUtc ? d.toLocal() : d;

/// Yerel tarih -> yyyymmdd (örn. 20260315).
int gunAnahtari(DateTime d) {
  final y = _yerel(d);
  return y.year * 10000 + y.month * 100 + y.day;
}

/// Yerel tarih -> yyyymm. Ay başlangıcı sonradan maaş gününe taşınırsa yalnız burası değişir.
int ayAnahtari(DateTime d) {
  final y = _yerel(d);
  return y.year * 100 + y.month;
}

/// [yil] yılının [ay]. ayının gün sayısı (28/29/30/31).
int ayGunSayisi(int yil, int ay) => DateTime(yil, ay + 1, 0).day;

/// yyyymm -> (ilk gün, son gün) yyyymmdd olarak; ikisi de dahil.
({int ilk, int son}) ayAraligi(int ayAnahtari) {
  final yil = ayAnahtari ~/ 100;
  final ay = ayAnahtari % 100;
  return (
    ilk: ayAnahtari * 100 + 1,
    son: ayAnahtari * 100 + ayGunSayisi(yil, ay),
  );
}
