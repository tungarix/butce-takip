import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../akilli/tahmin.dart';
import '../../akilli/tekrar_tespit.dart';
import '../../core/butce.dart';
import '../../core/para.dart';
import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import '../ay_secici.dart';
import '../ayarlar/yedek_islemleri.dart';
import '../ayarlar/kategoriler_ekrani.dart';
import '../hizli_giris/hizli_giris.dart';
import '../ikonlar.dart';
import 'bakiye_sayfasi.dart';

class OzetEkrani extends ConsumerWidget {
  const OzetEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriler = ref.watch(kategorilerProvider);
    final giderler = ref.watch(ayGiderToplamlariProvider);
    final gelir = ref.watch(ayGelirToplamiProvider);
    final limitler = ref.watch(limitlerProvider);
    // Akıllı kartlar yardımcıdır: yüklenmemiş ya da okunamamışsa yok sayılır, Özet'i engellemez.
    final bugun = ref.watch(bugunProvider);
    final giderKayitlari =
        ref.watch(giderKayitlariProvider).value ?? const <GiderKaydi>[];
    final reddedilen =
        ref.watch(reddedilenTekrarlarProvider).value ?? const <String>{};
    final seciliAy = ref.watch(seciliAyProvider);

    Widget icerik() {
      if (kategoriler.hasError ||
          giderler.hasError ||
          gelir.hasError ||
          limitler.hasError) {
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
      return _OzetListesi(
        ozet: ozet,
        gelir: gelir.value!,
        kategoriler: adlar,
        bugun: bugun,
        seciliAy: seciliAy,
        giderKayitlari: giderKayitlari,
        reddedilen: reddedilen,
      );
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
  const _OzetListesi({
    required this.ozet,
    required this.gelir,
    required this.kategoriler,
    required this.bugun,
    required this.seciliAy,
    required this.giderKayitlari,
    required this.reddedilen,
  });

  final Ozet ozet;
  final int gelir;
  final Map<int, Category> kategoriler;
  final int bugun;
  final int seciliAy;
  final List<GiderKaydi> giderKayitlari;
  final Set<String> reddedilen;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    String ad(int id) => kategoriler[id]?.name ?? '?';
    final bos = ozet.harcanan == 0 && gelir == 0;
    final tekrarlar = tekrarOnerileri(
      giderKayitlari,
      bugun,
      reddedilen: reddedilen,
    );
    return ListView(
      // FAB son satırı kapatmasın.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      children: [
        const _YedekKarti(),
        const _BakiyeKarti(),
        const SizedBox(height: 8),
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
                      MaterialPageRoute<void>(
                        builder: (_) => const KategorilerEkrani(),
                      ),
                    ),
                    child: const Text(limitEkleEtiket),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Tahmin yalnız içinde bulunulan ay için; geçmiş ve gelecek ayda kart yok.
        if (seciliAy == bugun ~/ 100) ...[
          _TahminKarti(
            tahmin: ayTahmini(
              giderler: giderKayitlari,
              bugun: bugun,
              buAyHarcanan: ozet.harcanan,
              reddedilen: reddedilen,
            ),
            limitToplami: ozet.limitToplami,
          ),
          const SizedBox(height: 8),
        ],
        _Kart(anahtar: 'gelir', baslik: buAyGelir, tutar: paraYaz(gelir)),
        if (bos)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(bosAyMetni, textAlign: TextAlign.center),
          ),
        if (ozet.limitli.isNotEmpty) ...[
          _Baslik(limitlerBaslik),
          for (final s in ozet.limitli)
            _LimitSatiri(s, kategoriler[s.kategoriId]),
        ],
        if (ozet.limitsiz.isNotEmpty) ...[
          _Baslik(limitsizBaslik),
          for (final s in ozet.limitsiz)
            ListTile(
              key: ValueKey('limitsiz-${s.kategoriId}'),
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                kategoriSimgesi(kategoriler[s.kategoriId]?.icon ?? -1),
              ),
              title: Text(ad(s.kategoriId)),
              trailing: Text(
                paraYaz(s.harcanan),
                style: tema.textTheme.titleSmall,
              ),
            ),
        ],
        if (tekrarlar.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TekrarKarti(tekrarlar: tekrarlar, kategoriler: kategoriler),
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
              style:
                  (buyuk
                          ? tema.textTheme.headlineSmall
                          : tema.textTheme.titleLarge)
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
      LimitDurumu.uyari =>
        koyu ? Colors.orange.shade300 : Colors.orange.shade800,
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

class _TahminKarti extends StatelessWidget {
  const _TahminKarti({required this.tahmin, required this.limitToplami});

  final int? tahmin;
  final int? limitToplami;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final t = tahmin;
    final asim = t != null && limitToplami != null && t > limitToplami!;
    return Card(
      key: const ValueKey('tahmin-karti'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tahminBaslik, style: tema.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              t == null ? tahminYetersiz : tahminMetni(paraYaz(t)),
              key: const ValueKey('tahmin-metin'),
            ),
            if (asim)
              Text(
                tahminLimitFarki(paraYaz(t - limitToplami!)),
                key: const ValueKey('tahmin-fark'),
                style: tema.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// Otomatik kayıt yok: "Ekle" önceden doldurulmuş hızlı girişi açar, kullanıcı Kaydet'e basar.
class _TekrarKarti extends ConsumerWidget {
  const _TekrarKarti({required this.tekrarlar, required this.kategoriler});

  final List<TekrarGrubu> tekrarlar;
  final Map<int, Category> kategoriler;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    return Card(
      key: const ValueKey('tekrar-karti'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tekrarBaslik, style: tema.textTheme.labelLarge),
            for (final g in tekrarlar) ...[
              const SizedBox(height: 12),
              Text(
                g.not.isEmpty
                    ? (kategoriler[g.kategoriId]?.name ?? '?')
                    : g.not,
                style: tema.textTheme.titleSmall,
              ),
              Text(
                '${paraYaz(g.tutar)} · ${tekrarBeklenen(DateFormat('d MMMM', 'tr_TR').format(gunTarihi(g.beklenenGun)))}',
                style: tema.textTheme.bodySmall,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: ValueKey('tekrar-gosterme-${g.anahtar}'),
                    onPressed: () => ref
                        .read(databaseProvider)
                        .ayarYaz('$tekrarRedOnEki${g.anahtar}', '1'),
                    child: const Text(tekrarGosterme),
                  ),
                  FilledButton.tonal(
                    key: ValueKey('tekrar-ekle-${g.anahtar}'),
                    onPressed: () => hizliGirisAc(
                      context,
                      dolu: (
                        kurus: g.tutar,
                        kategoriId: g.kategoriId,
                        not: g.not,
                      ),
                    ),
                    child: const Text(tekrarEkleEtiket),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Yalnız Özet'te, 30 günden fazladır yedek alınmamışsa görünür. "Sonra" 7 gün erteler.
class _YedekKarti extends ConsumerWidget {
  const _YedekKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(yedekHatirlatmaProvider)) return const SizedBox.shrink();
    final db = ref.read(databaseProvider);
    return Card(
      key: const ValueKey('yedek-karti'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(yedekHatirlatmaMetni),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('yedek-sonra'),
                  onPressed: () => db.ayarYaz(
                    yedekErtelemeAnahtari,
                    '${gunEkle(ref.read(bugunProvider), 7)}',
                  ),
                  child: const Text(yedekSonraEtiket),
                ),
                FilledButton.tonal(
                  key: const ValueKey('yedek-yedekle'),
                  onPressed: () => yedekle(context, ref, paylas: false),
                  child: const Text(yedekKaydetBaslik),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ay seçiciden bağımsız toplam bakiye; dokununca bankadaki bakiyeye eşitleme penceresi açılır.
class _BakiyeKarti extends ConsumerWidget {
  const _BakiyeKarti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final bakiye = ref.watch(toplamBakiyeProvider);
    return Card(
      key: const ValueKey('bakiye-karti'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => bakiyeSayfasiAc(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          // Tutar kendi satırında: uzun tutar açıklamayı sıkıştırmasın.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(toplamBakiyeEtiket, style: tema.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                bakiye == null ? '' : paraYaz(bakiye),
                key: const ValueKey('ozet-bakiye'),
                style: tema.textTheme.headlineMedium?.copyWith(
                  color: bakiye != null && bakiye < 0
                      ? tema.colorScheme.error
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                toplamBakiyeAciklama,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
