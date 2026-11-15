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

Bu makinede `flutter test` süreci (`flutter_tester.exe`) projeden bağımsız, rastgele çöker (0xC0000005):
"Connection closed before test suite loaded" ya da testlerin topluca "did not complete".

- Çökme saf Dart test dosyasında da oluyor.
- Windows hata raporlarında (WER) kayıtlar 2026-11-03'ten beri var; yani proje başlamadan önce de çöküyordu.
- Test koduyla ilgisi yok: çökmeyen koşuda testler yeşil geçer.

Testleri dosya dosya çalıştırın (`flutter test test/x_test.dart`). Yalnız çökme belirtisiyle biten dosyayı yeniden deneyin;
`Expected/Actual` ya da istisna içeren hata gerçektir, yeniden denemeyle geçmez.
