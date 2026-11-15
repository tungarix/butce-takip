// Para her yerde kuruş `int`; `double` yok. Saf Dart: arayüz ve veritabanı içe aktarılmaz.

/// 999.999.999,99 ₺ (kuruş cinsinden). Tuş takımı bunun üstüne çıkmaz.
const int paraUstSinirKurus = 99999999999;

/// 123450 -> "1.234,50 ₺". Eksi değer "-" ile başlar (kalan bütçe eksiye düşebilir).
String paraYaz(int kurus) {
  final m = kurus.abs();
  final lira = (m ~/ 100).toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final kr = (m % 100).toString().padLeft(2, '0');
  return '${kurus < 0 ? '-' : ''}$lira,$kr ₺';
}

/// Sağdan dolan tuş takımı: 0 -> 5 -> 52 -> 523 kuruş ("5,23"). Üst sınırı aşan basış yok sayılır.
int tusaBas(int mevcutKurus, int rakam) {
  assert(rakam >= 0 && rakam <= 9);
  final yeni = mevcutKurus * 10 + rakam;
  return yeni > paraUstSinirKurus ? mevcutKurus : yeni;
}

/// Geri tuşu: son rakamı atar.
int tusSil(int mevcutKurus) => mevcutKurus ~/ 10;
