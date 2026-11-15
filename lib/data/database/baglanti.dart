import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Cihazdaki gerçek veritabanı (`butce_takip.sqlite`, uygulamanın özel klasöründe).
QueryExecutor baglantiAc() => driftDatabase(name: 'butce_takip');
