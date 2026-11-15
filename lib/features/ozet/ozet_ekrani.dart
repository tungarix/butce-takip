import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/butce.dart';
import '../../core/para.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import '../ay_secici.dart';
import '../ayarlar/kategoriler_ekrani.dart';
import '../ikonlar.dart';

class OzetEkrani extends ConsumerWidget {
  const OzetEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriler = ref.watch(kategorilerProvider);
    final giderler = ref.watch(ayGiderToplamlariProvider);
    final gelir = ref.watch(ayGelirToplamiProvider);
    final limitler = ref.watch(limitlerProvider);

    Widget icerik() {
      if (kategoriler.hasError || giderler.hasError || gelir.hasError || limitler.hasError) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(veriYuklenemedi, textAlign: TextAlign.center),
          ),
        );
      }
      if (kategoriler.value == null ||
          giderler.value == null ||
          gelir.value == null ||
          limitler.value == null) {
        return const SizedBox();
      }
      final adlar = {for (final c in kategoriler.value!) c.id: c};
      final ozet = ozetHesapla(
        giderler: giderler.value!,
        limitler: limitler.value!,
        limitGecerli: {
          for (final c in kategoriler.value!)
            if (!c.isIncome && !c.archived) c.id,
        },
      );
      return _OzetListesi(ozet: ozet, gelir: gelir.value!, kategoriler: adlar);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AySecici(),
            Expanded(child: icerik()),
          ],
        ),
      ),
    );
  }
}

class _OzetListesi extends StatelessWidget {
  const _OzetListesi({required this.ozet, required this.gelir, required this.kategoriler});

  final Ozet ozet;
  final int gelir;
  final Map<int, Category> kategoriler;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    String ad(int id) => kategoriler[id]?.name ?? '?';
    final bos = ozet.harcanan == 0 && gelir == 0;
    return ListView(
      // FAB son satırı kapatmasın.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        _Kart(
          anahtar: 'harcanan',
          baslik: buAyHarcanan,
          tutar: paraYaz(ozet.harcanan),
          buyuk: true,
        ),
        const SizedBox(height: 8),
        if (ozet.kalan != null)
          _Kart(
            anahtar: 'kalan',
            baslik: kalanEtiket,
            tutar: paraYaz(ozet.kalan!),
            aciklama: kalanAciklama,
            tutarRengi: ozet.kalan! < 0 ? tema.colorScheme.error : null,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(limitCagrisi),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    key: const ValueKey('limit-ekle'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const KategorilerEkrani()),
                    ),
                    child: const Text(limitEkleEtiket),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        _Kart(anahtar: 'gelir', baslik: buAyGelir, tutar: paraYaz(gelir)),
        if (bos)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(bosAyMetni, textAlign: TextAlign.center),
          ),
        if (ozet.limitli.isNotEmpty) ...[
          _Baslik(limitlerBaslik),
          for (final s in ozet.limitli) _LimitSatiri(s, kategoriler[s.kategoriId]),
        ],
        if (ozet.limitsiz.isNotEmpty) ...[
          _Baslik(limitsizBaslik),
          for (final s in ozet.limitsiz)
            ListTile(
              key: ValueKey('limitsiz-${s.kategoriId}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(kategoriSimgesi(kategoriler[s.kategoriId]?.icon ?? -1)),
              title: Text(ad(s.kategoriId)),
              trailing: Text(paraYaz(s.harcanan), style: tema.textTheme.titleSmall),
            ),
        ],
      ],
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);

  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
    child: Text(metin, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Kart extends StatelessWidget {
  const _Kart({
    required this.anahtar,
    required this.baslik,
    required this.tutar,
    this.aciklama,
    this.buyuk = false,
    this.tutarRengi,
  });

  final String anahtar;
  final String baslik;
  final String tutar;
  final String? aciklama;
  final bool buyuk;
  final Color? tutarRengi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslik, style: tema.textTheme.labelLarge),
                  if (aciklama != null)
                    Text(aciklama!, style: tema.textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              tutar,
              key: ValueKey('ozet-$anahtar'),
              style: (buyuk ? tema.textTheme.headlineSmall : tema.textTheme.titleLarge)
                  ?.copyWith(color: tutarRengi),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitSatiri extends StatelessWidget {
  const _LimitSatiri(this.s, this.kategori);

  final LimitSatiri s;
  final Category? kategori;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final ad = kategori?.name ?? '?';
    final koyu = tema.brightness == Brightness.dark;
    final renk = switch (s.durum) {
      LimitDurumu.normal => tema.colorScheme.primary,
      LimitDurumu.uyari => koyu ? Colors.orange.shade300 : Colors.orange.shade800,
      LimitDurumu.asim => tema.colorScheme.error,
    };
    return Padding(
      key: ValueKey('limitli-${s.kategoriId}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(kategoriSimgesi(kategori?.icon ?? -1), size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(ad)),
              Text(
                yuzdeEtiket(s.yuzde),
                key: ValueKey('yuzde-${s.kategoriId}'),
                style: tema.textTheme.titleSmall?.copyWith(color: renk),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (s.yuzde / 100).clamp(0.0, 1.0),
            color: renk,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 4),
          Text(
            '${paraYaz(s.harcanan)} / ${paraYaz(s.limit)}',
            style: tema.textTheme.bodySmall,
          ),
          if (s.durum != LimitDurumu.normal)
            Text(limitDurumMetni(ad, s.yuzde), style: tema.textTheme.bodySmall),
        ],
      ),
    );
  }
}
