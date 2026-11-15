import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import 'kategoriler_ekrani.dart';

class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text(sekmeAyarlar)),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text(kategorilerBaslik),
          subtitle: const Text(kategorilerAltyazi),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const KategorilerEkrani()),
          ),
        ),
        SwitchListTile(
          key: const ValueKey('bildirim-anahtari'),
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text(bildirimAnahtariBaslik),
          subtitle: const Text(bildirimAnahtariAltyazi),
          value: ref.watch(bildirimAcikProvider).value ?? true,
          onChanged: (acik) async {
            final db = ref.read(databaseProvider);
            final kapi = ref.read(bildirimProvider);
            try {
              await db.ayarYaz(bildirimAcikAnahtari, acik ? '1' : '0');
              if (acik) await kapi.izinIste();
            } catch (_) {
              // Anahtar ayarın akışından güncellenir; yazılamadıysa eski durumunda kalır.
            }
          },
        ),
      ],
    ),
  );
}
