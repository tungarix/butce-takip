import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database/baglanti.dart';
import 'database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(baglantiAc());
  ref.onDispose(db.close);
  return db;
});
