// Saf Dart.

/// Notun kayıtlı arama biçimi. Tek giriş noktası: işlem yazan her yer bundan geçer.
// shortcut: yalnız trim + küçük harf (Türkçe İ/I yanlış küçülür, ışğüöç dönüşmez, noktalama kalır);
// aşama 4'te PLAN.md'deki gerçek normalize ile değişecek.
String notNormalize(String not) => not.trim().toLowerCase();
