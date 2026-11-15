// Saf Dart.

/// Notun kayıtlı arama biçimi. Tek giriş noktası: işlem yazan her yer bundan geçer.
/// Dart'ın toLowerCase'i yerel ayar almaz: önce İ->i, I->ı elle; sonra küçük harf;
/// sonra ışğüöç -> isguoc; noktalama boşluğa döner; yalnız rakamdan oluşan sözcükler atılır
/// ('a101' kalır, '2024' gider); boşluklar teklenir.
String notNormalize(String not) {
  final kucuk = not.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  const eski = 'ışğüöç';
  const yeni = 'isguoc';
  final sade = StringBuffer();
  for (final r in kucuk.runes) {
    final c = String.fromCharCode(r);
    final i = eski.indexOf(c);
    sade.write(i >= 0 ? yeni[i] : c);
  }
  final tamRakam = RegExp(r'^\p{N}+$', unicode: true);
  return sade
      .toString()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty && !tamRakam.hasMatch(s))
      .join(' ');
}

/// Normalize edilmiş notun sözcükleri; 2 harften kısa olanlar atılır, tekrarlar teke iner.
List<String> notSozcukleri(String not) => [
  ...{
    for (final s in notNormalize(not).split(' '))
      if (s.length >= 2) s,
  },
];
