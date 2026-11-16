import 'dart:io';

import 'package:butce_takip/surum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/surum.dart pubspec sürümüyle aynı', () {
    final satir = File(
      'pubspec.yaml',
    ).readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(uygulamaSurumu, satir.substring('version:'.length).trim());
  });
}
