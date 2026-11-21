import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../surum.dart';
import '../../ui_metin.dart';
import '../ice_aktar/onizleme_ekrani.dart';
import 'guncelleme_bolumu.dart';
import 'kategoriler_ekrani.dart';
import 'yedek_islemleri.dart';

class AyarlarEkrani extends ConsumerWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text(sekmeAyarlar)),
    body: ListView(
      // FAB son satırı kapatmasın.
      padding: const EdgeInsets.only(bottom: 88),
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
        ListTile(
          key: const ValueKey('yedek-kaydet'),
          leading: const Icon(Icons.save_alt_outlined),
          title: const Text(yedekKaydetBaslik),
          subtitle: const Text(yedekKaydetAltyazi),
          onTap: () => yedekle(context, ref, paylas: false),
        ),
        ListTile(
          key: const ValueKey('yedek-paylas'),
          leading: const Icon(Icons.share_outlined),
          title: const Text(yedekPaylasBaslik),
          subtitle: const Text(yedekPaylasAltyazi),
          onTap: () => yedekle(context, ref, paylas: true),
        ),
        ListTile(
          key: const ValueKey('geri-yukle'),
          leading: const Icon(Icons.restore_outlined),
          title: const Text(geriYukleBaslik),
          subtitle: const Text(geriYukleAltyazi),
          onTap: () => geriYukle(context, ref),
        ),
        ListTile(
          key: const ValueKey('dokum-aktar'),
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text(dokumAktarBaslik),
          subtitle: const Text(dokumAktarAltyazi),
          onTap: () => dokumRehberiAc(context),
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
        const GuncellemeBolumu(),
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Center(
            child: Text(
              // '+derleme' kısmı kullanıcıya gösterilmez.
              'Bütçe Takip ${uygulamaSurumu.split('+').first}',
              key: const ValueKey('surum-metni'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    ),
  );
}
