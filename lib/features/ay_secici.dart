import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/tarih.dart';
import '../data/providers.dart';
import '../ui_metin.dart';

/// İşlemler ve Özet'in ortak ay seçicisi; ikisi de [seciliAyProvider]'ı kullanır.
class AySecici extends ConsumerWidget {
  const AySecici({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ay = ref.watch(seciliAyProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: oncekiAyEtiket,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(seciliAyProvider.notifier).kaydir(-1),
        ),
        Expanded(
          child: Text(
            DateFormat('MMMM y', 'tr_TR').format(gunTarihi(ay * 100 + 1)),
            key: const ValueKey('ay-basligi'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: sonrakiAyEtiket,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => ref.read(seciliAyProvider.notifier).kaydir(1),
        ),
      ],
    );
  }
}
