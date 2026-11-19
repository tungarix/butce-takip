// Ayarlar'daki Güncellemeler bölümü + ilk açılışta bir kez sorma.
// Platform köprüsü yoksa (testler, Android dışı) bölüm gizlenir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../platform/guncelleme/ag.dart';
import '../../platform/guncelleme/akis.dart';
import '../../platform/guncelleme/guncelleyici.dart';
import '../../platform/guncelleme/kur.dart';
import '../../platform/kopru.dart';
import '../../surum.dart';
import '../../ui_metin.dart';

/// Kurulum köprüsü yoksa null.
final guncelleyiciProvider = FutureProvider<Guncelleyici?>((ref) async {
  if (ref.watch(kopruProvider) == null) return null;
  return guncelleyiciKur(
    ref.watch(databaseProvider),
    uygulamaSurumu.split('+').first,
  );
});

/// İlk açılış: güncelleme denetimi bir kez sorulur (yanıtlanana dek ağ isteği yok),
/// sonra günlük denetim çalışır.
Future<void> guncellemeIlkAcilis(BuildContext context, WidgetRef ref) async {
  final g = await ref.read(guncelleyiciProvider.future);
  if (g == null || !context.mounted) return;
  if (g.denetim == null) {
    final evet = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text(guncellemeIlkBaslik),
        content: const Text(guncellemeIlkGovde),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(guncellemeIlkHayir),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(guncellemeIlkEvet),
          ),
        ],
      ),
    );
    await g.denetimYaz(evet ?? false);
  }
  await g.otomatikAdim();
}

class GuncellemeBolumu extends ConsumerStatefulWidget {
  const GuncellemeBolumu({super.key});

  @override
  ConsumerState<GuncellemeBolumu> createState() => _GuncellemeBolumuState();
}

class _GuncellemeBolumuState extends ConsumerState<GuncellemeBolumu> {
  String? _durum; // transient status / error line
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    // Without this a cancelled / failed install (signature mismatch...) would leave the
    // "install dialog opened" line on screen forever.
    ref.read(kopruProvider)?.kurulumSonucuDinle(_kurulumSonucu);
  }

  void _kurulumSonucu(int durum, String? mesaj) {
    if (!mounted || durum == 0) return;
    setState(() => _durum = guncellemeKurulumSonucu(durum));
  }

  Future<void> _calis(Future<void> Function() gorev) async {
    setState(() => _mesgul = true);
    try {
      await gorev();
    } on GuncellemeHatasi catch (e) {
      _durum = guncellemeHata(e.kod);
    } catch (_) {
      _durum = guncellemeHata('bilinmiyor');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<bool> _mobilSor() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(guncellemeMobilBaslik),
          content: const Text(guncellemeMobilGovde),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(vazgecEtiket),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(guncellemeMobilEvet),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(guncelleyiciProvider).value;
    final kopru = ref.watch(kopruProvider);
    if (g == null || kopru == null) return const SizedBox.shrink();
    final teklif = g.teklif;
    final satir =
        _durum ??
        (g.hataKodu != null
            ? guncellemeHata(g.hataKodu!)
            : teklif != null
            ? guncellemeHazir(teklif.surum)
            : g.sonDenetim != null
            ? guncellemeGuncel
            : guncellemeHic);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            header: true,
            child: Text(
              guncellemeBaslik,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(guncellemeDenetle),
                subtitle: const Text(guncellemeDenetleAciklama),
                value: g.denetim == true,
                onChanged: _mesgul
                    ? null
                    : (v) => _calis(() => g.denetimYaz(v)),
              ),
              SwitchListTile(
                title: const Text(guncellemeYalnizWifi),
                value: g.ayarlar.yalnizWifi,
                onChanged: _mesgul
                    ? null
                    : (v) => _calis(() => g.ayarlar.yalnizWifiYaz(v)),
              ),
              ListTile(
                title: Text(_mesgul ? guncellemeDenetleniyor : satir),
                trailing: TextButton(
                  onPressed: _mesgul
                      ? null
                      : () => _calis(() async {
                          _durum = null;
                          await g.denetle();
                        }),
                  child: const Text(guncellemeSimdiDenetle),
                ),
              ),
              if (teklif != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _mesgul
                          ? null
                          : () => _calis(() async {
                              _durum = guncellemeIndiriliyor;
                              await guncellemeKur(
                                g,
                                kopru,
                                teklif,
                                mobilOnayi: _mobilSor,
                              );
                              _durum = guncellemeKurulumAcildi;
                            }),
                      child: const Text(guncellemeIndirKur),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
