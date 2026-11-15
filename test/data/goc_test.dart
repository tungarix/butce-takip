import 'package:butce_takip/data/database/database.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../generated/schema.dart';

// Şema sürümü 2'ye çıkarken: `dart run drift_dev schema dump lib/data/database/database.dart drift_schemas/`
// ve `dart run drift_dev schema generate drift_schemas/ test/generated/` çalıştır, sonra aşağıya
// `startAt(1)` ile açıp `migrateAndValidate(db, 2)` yapan bir yükseltme testi ekle.
void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1: kodun şeması drift_schemas dökümüyle birebir', () async {
    final baglanti = await verifier.startAt(1);
    final db = AppDatabase(baglanti);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 1);
  });
}
