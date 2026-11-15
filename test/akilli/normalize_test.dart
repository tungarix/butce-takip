import 'package:butce_takip/akilli/normalize.dart';
import 'package:butce_takip/data/database/tohum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notNormalize', () {
    test('İ/I/ı/i Türkçe kurala göre küçülür', () {
      expect(notNormalize('İSTANBUL'), 'istanbul'); // İ -> i
      expect(notNormalize('ISIK'), 'isik'); // I -> ı -> i
      expect(notNormalize('ılık'), 'ilik');
      expect(notNormalize('iI'), 'ii');
      expect(notNormalize('IĞDIR'), 'igdir');
    });

    test('ışğüöç -> isguoc, büyük ve küçük harf', () {
      expect(notNormalize('ışğüöç'), 'isguoc');
      expect(notNormalize('IŞĞÜÖÇ'), 'isguoc');
      expect(notNormalize('İŞĞÜÖÇ'), 'isguoc');
      expect(
        notNormalize('Şeker Çay Öğle Ütü Güneş'),
        'seker cay ogle utu gunes',
      );
    });

    test(
      'rakam ve noktalama atılır, boşluklar teklenir, kenarlar kırpılır',
      () {
        expect(notNormalize('A101, Migros! 2024'), 'a101 migros');
        expect(notNormalize("Migros'a"), 'migros a');
        expect(notNormalize('3 ekmek'), 'ekmek');
        expect(notNormalize('2x süt'), '2x sut');
        expect(notNormalize('  Çok   boşluk\t\nvar '), 'cok bosluk var');
        expect(notNormalize('123 !?'), '');
        expect(notNormalize(''), '');
      },
    );
  });

  group('notSozcukleri', () {
    test('2 harften kısa sözcükler atılır, tekrarlar teke iner', () {
      expect(notSozcukleri('A101 Migros x market Market'), [
        'a101',
        'migros',
        'market',
      ]);
      expect(notSozcukleri('b ab'), ['ab']);
      expect(notSozcukleri("Migros'a"), ['migros']);
      expect(notSozcukleri('  '), isEmpty);
    });
  });

  test('tohum anahtar kelimeleri normalize çıktısıyla birebir uyumlu', () {
    final adlar = {for (final k in tohumKategoriler) k.ad};
    for (final e in tohumAnahtarKelimeler.entries) {
      expect(adlar, contains(e.key));
      for (final kelime in e.value) {
        expect(
          notNormalize(kelime),
          kelime,
          reason: '$kelime normalize edilince değişmemeli',
        );
        expect(notSozcukleri(kelime), [
          kelime,
        ], reason: '$kelime tek sözcük olarak aranabilmeli');
      }
    }
  });
}
