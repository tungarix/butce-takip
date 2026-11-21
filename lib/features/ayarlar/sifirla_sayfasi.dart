import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../platform/yedek_dosyasi.dart';
import '../../ui_metin.dart';
import '../alt_bosluk.dart';
import 'guncelleme_bolumu.dart';
import 'yedek_islemleri.dart';

Future<void> sifirlaSayfasiAc(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SifirlaSayfasi(),
    );

class SifirlaSayfasi extends ConsumerStatefulWidget {
  const SifirlaSayfasi({super.key});

  @override
  ConsumerState<SifirlaSayfasi> createState() => _SifirlaSayfasiState();
}

class _SifirlaSayfasiState extends ConsumerState<SifirlaSayfasi> {
  bool _hepsi = false;

  Future<void> _sifirla() async {
    final mesaj = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final db = ref.read(databaseProvider);
    final dosya = ref.read(yedekDosyasiProvider);
    final kap = ProviderScope.containerOf(context, listen: false);
    void soyle(String m) => mesaj.showSnackBar(SnackBar(content: Text(m)));

    final int sayi;
    try {
      sayi = await db.islemSayisi();
    } catch (_) {
      soyle(sifirlamaBasarisiz);
      return;
    }
    if (!mounted) return;
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(sifirlaBaslik),
        content: Text(sifirlaOnayMetni(sayi, _hepsi)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(vazgecEtiket),
          ),
          FilledButton(
            key: const ValueKey('sifirla-onay'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(sifirlaEtiket),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      final yol = await dosya.kopyaYolu();
      if (yol == null) throw const SifirlamaKopyasiHatasi();
      // Geri yükleme kopyasının yanına, ayrı adla (o kopyanın üstüne yazılmasın).
      final kopya =
          '${File(yol).parent.path}${Platform.pathSeparator}'
          'butce_takip_sifirlama_oncesi.sqlite';
      await (_hepsi
          ? db.herSeyiSifirla(kopyaYolu: kopya)
          : db.islemleriSifirla(kopyaYolu: kopya));
    } on SifirlamaKopyasiHatasi {
      soyle(sifirlamaKopyasiHatasi);
      return;
    } catch (_) {
      soyle(sifirlamaBasarisiz);
      return;
    }
    // Silme bitti: bundan sonrası başarısız olsa da kullanıcıya "değişmedi" denmez. Sayfa bu arada
    // kapatıldıysa başka bir rota kapatılmasın; container sayfadan bağımsız tazelenir.
    soyle(sifirlandi);
    try {
      kap.invalidate(guncelleyiciProvider);
    } catch (_) {}
    if (mounted) nav.pop();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.only(bottom: altBosluk(context)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            sifirlaBaslik,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        RadioGroup<bool>(
          groupValue: _hepsi,
          onChanged: (v) => setState(() => _hepsi = v ?? false),
          child: const Column(
            children: [
              RadioListTile<bool>(
                key: ValueKey('sifirla-islemler'),
                value: false,
                title: Text(sifirlaSadeceIslemler),
                subtitle: Text(sifirlaSadeceIslemlerAlt),
              ),
              RadioListTile<bool>(
                key: ValueKey('sifirla-hepsi'),
                value: true,
                title: Text(sifirlaHepsi),
                subtitle: Text(sifirlaHepsiAlt),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            sifirlaYedekOnerisi,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('sifirla-yedek'),
              onPressed: () => yedekle(context, ref, paylas: false),
              child: const Text(sifirlaYedekDugmesi),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('sifirla-dugme'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: _sifirla,
              child: const Text(sifirlaEtiket),
            ),
          ),
        ),
      ],
    ),
  );
}
