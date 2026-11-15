import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR');
  final container = ProviderContainer();
  // Veritabanını açılışta aç: şema ve tohum hatası ilk kullanımda değil burada patlasın.
  await container.read(databaseProvider).customSelect('SELECT 1').get();
  runApp(
    UncontrolledProviderScope(container: container, child: const ButceTakipApp()),
  );
}
