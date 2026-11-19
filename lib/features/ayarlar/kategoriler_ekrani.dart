import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/para.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../platform/bildirimler.dart';
import '../../ui_metin.dart';
import '../alt_bosluk.dart';
import '../ikonlar.dart';
import '../tus_takimi.dart';

/// Kategori arşivlenir (yeni girişte görünmez, eski işlemlerde adı görünür) ya da silinir
/// (işlemleri 'Diğer'e taşınır).
class KategorilerEkrani extends ConsumerWidget {
  const KategorilerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kategoriler = ref.watch(kategorilerProvider);
    final limitler = ref.watch(limitlerProvider).value ?? const <int, int>{};
    final liste = kategoriler.value;

    Widget bolum(String baslik, String ekleEtiket, bool gelir) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  baslik,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                tooltip: ekleEtiket,
                icon: const Icon(Icons.add),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => KategoriDialog(gelir: gelir),
                ),
              ),
            ],
          ),
        ),
        for (final c in liste!.where((c) => c.isIncome == gelir))
          _KategoriSatiri(c, limitler[c.id]),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text(kategorilerBaslik)),
      body: kategoriler.hasError
          ? const Center(
              child: Text(veriYuklenemedi, textAlign: TextAlign.center),
            )
          : liste == null
          ? const SizedBox()
          : ListView(
              padding: EdgeInsets.only(bottom: altBosluk(context)),
              children: [
                bolum(giderKategorileri, giderKategorisiEkle, false),
                bolum(gelirKategorileri, gelirKategorisiEkle, true),
              ],
            ),
    );
  }
}

class _KategoriSatiri extends ConsumerWidget {
  const _KategoriSatiri(this.c, this.limit);

  final Category c;
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final soluk = c.archived ? tema.colorScheme.outline : null;
    final alt = [
      if (c.archived) arsivliEtiket,
      if (!c.isIncome) limit == null ? limitYok : limitSatiri(paraYaz(limit!)),
    ].join(' · ');
    return ListTile(
      key: ValueKey('kategori-${c.id}'),
      leading: Icon(kategoriSimgesi(c.icon), color: soluk),
      title: Text(c.name, style: TextStyle(color: soluk)),
      subtitle: alt.isEmpty ? null : Text(alt),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => KategoriDialog(gelir: c.isIncome, duzenle: c),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!c.isIncome)
            IconButton(
              key: ValueKey('limit-${c.id}'),
              tooltip: '${c.name}: $limitEtiket',
              icon: const Icon(Icons.speed),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => LimitSayfasi(kategori: c, mevcut: limit),
              ),
            ),
          IconButton(
            key: ValueKey('arsiv-${c.id}'),
            tooltip: c.archived
                ? '${c.name}: $arsivdenCikarEtiket'
                : '${c.name}: $arsivleEtiket',
            icon: Icon(
              c.archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(databaseProvider)
                    .kategoriArsivle(c.id, arsivli: !c.archived);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text(arsivHatasi)));
                }
              }
            },
          ),
          if (digerMi(c))
            // Silinemez: düğme yerine aynı genişlikte boşluk, simgeler aynı sütunda kalsın.
            const SizedBox(width: 48)
          else
            IconButton(
              key: ValueKey('sil-${c.id}'),
              tooltip: '${c.name}: $silEtiket',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _sil(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _sil(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final mesaj = ScaffoldMessenger.of(context);
    try {
      final sayi = await db.kategoriIslemSayisi(c.id);
      if (!context.mounted) return;
      final onay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(kategoriSilBaslik(c.name)),
          content: Text(kategoriSilGovde(sayi, digerKategoriAdi(c.isIncome))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(vazgecEtiket),
            ),
            TextButton(
              key: const ValueKey('sil-onay'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(silEtiket),
            ),
          ],
        ),
      );
      if (onay == true) await db.kategoriSil(c.id);
    } catch (_) {
      mesaj
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kategoriSilHatasi)));
    }
  }
}

/// Kategori ekleme ([duzenle] null) ya da ad ve simge değiştirme.
class KategoriDialog extends ConsumerStatefulWidget {
  const KategoriDialog({super.key, required this.gelir, this.duzenle});

  final bool gelir;
  final Category? duzenle;

  @override
  ConsumerState<KategoriDialog> createState() => _KategoriDialogState();
}

class _KategoriDialogState extends ConsumerState<KategoriDialog> {
  late final TextEditingController _ad;
  late int _simge;
  String? _hata;
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    _ad = TextEditingController(text: widget.duzenle?.name ?? '');
    _simge = widget.duzenle?.icon ?? 8;
  }

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_kaydediyor) return;
    _kaydediyor = true;
    final db = ref.read(databaseProvider);
    final d = widget.duzenle;
    try {
      if (d == null) {
        await db.kategoriEkle(ad: _ad.text, simge: _simge, gelir: widget.gelir);
      } else {
        await db.kategoriGuncelle(d.id, ad: _ad.text, simge: _simge);
      }
      if (mounted) Navigator.pop(context);
    } on KategoriAdiHatasi catch (e) {
      if (mounted) {
        setState(() => _hata = e.neden == AdHatasi.bos ? adBos : adAyni);
      }
    } catch (_) {
      if (mounted) setState(() => _hata = kaydedilemedi);
    } finally {
      _kaydediyor = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.duzenle != null
            ? kategoriDuzenleBaslik
            : widget.gelir
            ? gelirKategorisiEkle
            : giderKategorisiEkle,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('kategori-ad'),
              controller: _ad,
              autofocus: true,
              maxLength: 30,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: adEtiket,
                errorText: _hata,
              ),
              onChanged: (_) {
                if (_hata != null) setState(() => _hata = null);
              },
            ),
            const SizedBox(height: 8),
            Text(simgeEtiket, style: tema.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < kategoriSimgeSayisi; i++)
                  Semantics(
                    label: simgeSecEtiket(i),
                    selected: i == _simge,
                    button: true,
                    excludeSemantics: true,
                    child: IconButton.filledTonal(
                      key: ValueKey('simge-$i'),
                      isSelected: i == _simge,
                      icon: Icon(kategoriSimgesi(i)),
                      selectedIcon: Icon(kategoriSimgesi(i)),
                      style: i == _simge
                          ? IconButton.styleFrom(
                              backgroundColor: tema.colorScheme.primary,
                              foregroundColor: tema.colorScheme.onPrimary,
                            )
                          : null,
                      onPressed: () => setState(() => _simge = i),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(vazgecEtiket),
        ),
        FilledButton(
          key: const ValueKey('kategori-kaydet'),
          onPressed: _kaydet,
          child: const Text(kaydetEtiket),
        ),
      ],
    );
  }
}

/// Aylık limit girişi: hızlı girişteki aynı sağdan dolan tuş takımı.
class LimitSayfasi extends ConsumerStatefulWidget {
  const LimitSayfasi({super.key, required this.kategori, this.mevcut});

  final Category kategori;
  final int? mevcut;

  @override
  ConsumerState<LimitSayfasi> createState() => _LimitSayfasiState();
}

class _LimitSayfasiState extends ConsumerState<LimitSayfasi> {
  late int _kurus = widget.mevcut ?? 0;
  late final BildirimKapisi kapi = ref.read(bildirimProvider);
  String? _hata;

  Future<void> _calistir(Future<void> Function(AppDatabase db) islem) async {
    try {
      await islem(ref.read(databaseProvider));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _hata = kaydedilemedi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: altBosluk(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              limitBaslik(widget.kategori.name),
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium,
            ),
            Semantics(
              label: limitEtiket,
              value: paraYaz(_kurus),
              excludeSemantics: true,
              child: Text(
                paraYaz(_kurus),
                key: const ValueKey('limit-tutar'),
                textAlign: TextAlign.center,
                style: tema.textTheme.displayMedium?.copyWith(
                  color: _kurus == 0 ? tema.colorScheme.outline : null,
                ),
              ),
            ),
            if (_hata != null)
              Text(
                _hata!,
                textAlign: TextAlign.center,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            const SizedBox(height: 8),
            TusTakimi(
              onRakam: (r) => setState(() {
                _kurus = tusaBas(_kurus, r);
                _hata = null;
              }),
              onSil: () => setState(() => _kurus = tusSil(_kurus)),
            ),
            Row(
              children: [
                if (widget.mevcut != null)
                  TextButton(
                    key: const ValueKey('limit-kaldir'),
                    onPressed: () =>
                        _calistir((db) => db.limitKaldir(widget.kategori.id)),
                    child: const Text(limitKaldirEtiket),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('limit-kaydet'),
                  onPressed: _kurus > 0
                      ? () => _calistir((db) async {
                          await db.limitKoy(widget.kategori.id, _kurus);
                          // İzin ilk limit konduğunda istenir; reddedilirse Özet'teki çubuk yine uyarır.
                          try {
                            await izinIsteIlkKez(db, kapi);
                          } catch (_) {}
                        })
                      : null,
                  child: const Text(kaydetEtiket),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
