# butce_takip

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Test notu: flutter_tester çökmesi (ortam kaynaklı)

Bu makinede `flutter test` süreci (flutter_tester.exe) kodumuzdan bağımsız, ara sıra çöker:
"Connection closed before test suite loaded" ya da testlerde "did not complete".

- 9 WER dökümünün hepsi aynı yerde: `flutter_tester.exe` içinde 0xC0000005, aynı adres. Çökme motorun kendisinde.
- Çökme test yüklenirken, hiçbir test kodu çalışmadan da olur (tek dosya `islem_test.dart`, 40 koşuda 1).
- Yalnız ham sqlite3 (25 koşu), yalnız drift (30 koşu) ve saf Dart testi (20 koşu) tek başına hiç düşmedi; süreç sayısı arttıkça oran artıyor (tam takım ~%40-60 kırmızı, `-j 2` ile kısmen düşük).
- Makinede Riot Vanguard çekirdek sürücüsü (vgk) çalışıyor; olası şüpheli, kanıtlanmadı.
- Çökmenin test koduyla ilgisi yok: tüm 37 test, çökmeyen koşularda yeşil geçiyor.

Değerlendirme: `flutter test` kırmızıysa ve hata "Connection closed" / "did not complete" ise yeniden çalıştırın; gerçek test hatası (`Expected: ... Actual: ...`) her koşuda tekrarlanır.
