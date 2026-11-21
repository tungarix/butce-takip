import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../akilli/kategori_onerici.dart';
import '../../akilli/normalize.dart';
import '../../core/butce.dart';
import '../../core/para.dart';
import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ice_aktar/dokum.dart';
import '../../ice_aktar/oku.dart';
import '../../platform/bildirimler.dart';
import '../../platform/kopru.dart';
import '../../ui_metin.dart';
import '../alt_bosluk.dart';
import '../ikonlar.dart';

/// Ayarlar: PDF seç, oku, önizlemeyi aç.
Future<void> dokumSec(BuildContext context) async {
  final mesaj = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final dosya = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (dosya == null) return;
    // 5 MB'tan büyük dosya belleğe hiç alınmaz.
    if ((await dosya.length() ?? 0) > 5 * 1024 * 1024) {
      throw const DokumHatasi(dokumOkunamadi);
    }
    await dokumAc(nav, await dosya.readAsBytes());
  } on DokumHatasi catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
  } catch (_) {
    mesaj.showSnackBar(const SnackBar(content: Text(dokumOkunamadi)));
  }
}

/// Ayarlar: önce kısa "nasıl yapılır" alt sayfası, "PDF seç" dosya seçiciyi açar.
Future<void> dokumRehberiAc(BuildContext context) async {
  final sec = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + altBosluk(ctx)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dokumRehberBaslik, style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 12),
          const Text(dokumRehberMetin),
          const SizedBox(height: 12),
          const Text(dokumRehberBankalar),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('dokum-rehber-kapat'),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(dokumRehberKapat),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('dokum-rehber-sec'),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(dokumRehberSec),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (sec == true && context.mounted) await dokumSec(context);
}

/// "Paylaş" ile gelen PDF varsa okur, geçici dosyayı siler, önizlemeyi açar.
Future<void> paylasilaniAc(BuildContext context, Kopru? kopru) async {
  if (kopru == null) return;
  final mesaj = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  try {
    final yol = await kopru.paylasilanDosya();
    if (yol == null) return;
    final dosya = File(yol);
    final Uint8List bayt;
    try {
      bayt = await dosya.readAsBytes();
    } finally {
      try {
        await dosya.delete();
      } catch (_) {}
    }
    await dokumAc(nav, bayt);
  } on DokumHatasi catch (e) {
    mesaj.showSnackBar(SnackBar(content: Text(e.mesaj)));
  } catch (_) {
    mesaj.showSnackBar(const SnackBar(content: Text(dokumOkunamadi)));
  }
}

/// Baytı okur ve önizlemeyi açar. Okunamazsa [DokumHatasi] fırlatır; veri değişmez.
Future<void> dokumAc(NavigatorState nav, Uint8List bayt) async {
  final dokum = await dokumOku(bayt);
  await nav.push<void>(
    MaterialPageRoute(builder: (_) => OnizlemeEkrani(dokum: dokum)),
  );
}

/// Satırları tek transaction'da yazar; sonra etkilenen (kategori, ay) için aşım uyarısını BİR kez
/// değerlendirir (satır başına değil). Bildirim hatası kaydı başarısız göstermez.
Future<int> iceAktarKaydet(
  AppDatabase db,
  BildirimKapisi kapi,
  List<IceAktarSatiri> satirlar,
) async {
  final once = <(int, int), int>{};
  for (final s in satirlar.where((s) => !s.gelir)) {
    final k = (s.kategoriId, s.gun ~/ 100);
    once[k] ??= await db.ayKategoriGideri(k.$1, k.$2);
  }
  final n = await db.iceAktar(satirlar);
  try {
    for (final e in once.entries) {
      await asimKontrol(
        db,
        kapi,
        kategoriId: e.key.$1,
        gun: e.key.$2 * 100 + 1,
        once: e.value,
      );
    }
  } catch (_) {
    // Kayıt yapıldı; bildirim hatası kaydı başarısız göstermesin.
  }
  return n;
}

/// Türe uyan, arşivli olmayan kategoriler.
List<Category> uygunKategoriler(List<Category> hepsi, bool gelir) => [
  for (final c in hepsi)
    if (c.isIncome == gelir && !c.archived) c,
];

class OnizlemeEkrani extends ConsumerStatefulWidget {
  const OnizlemeEkrani({super.key, required this.dokum});

  final Dokum dokum;

  @override
  ConsumerState<OnizlemeEkrani> createState() => _OnizlemeState();
}

class _Satir {
  _Satir(this.kategoriId, this.etiket, this.isaretli);
  int kategoriId;
  final String? etiket; // işaretsiz gelme gerekçesi
  bool isaretli;
}

class _OnizlemeState extends ConsumerState<OnizlemeEkrani> {
  List<_Satir>? _satirlar;
  bool _kaydediyor = false;

  List<DokumSatiri> get _dokum => widget.dokum.satirlar;

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  Future<void> _hazirla() async {
    try {
      final db = ref.read(databaseProvider);
      final kategoriler = await db.select(db.categories).get();
      final varMi = await db.zatenVar(_dokum);
      final sozcukler = {for (final s in _dokum) ...notSozcukleri(s.aciklama)};
      final hits = [
        for (final k in await db.anahtarSatirlari(sozcukler.toList()))
          (keyword: k.keyword, categoryId: k.categoryId, hits: k.hits),
      ];
      final satirlar = <_Satir>[];
      for (var i = 0; i < _dokum.length; i++) {
        final s = _dokum[i];
        final uygun = uygunKategoriler(kategoriler, s.gelir);
        final oneri = kategoriOner(notSozcukleri(s.aciklama), hits, [
          for (final c in uygun) c.id,
        ]);
        final diger = uygun.where(digerMi).firstOrNull ?? uygun.first;
        final kendi = notNormalize(s.aciklama).contains('kendi hesab');
        final etiket = varMi[i]
            ? dokumZatenVar
            : (kendi ? dokumKendiHesap : null);
        // OCR'da tutarlar doğrulanamadıysa hiçbir satır kendiliğinden işaretli gelmez.
        final guvenilmez = widget.dokum.ocr && widget.dokum.tutarsiz;
        satirlar.add(
          _Satir(oneri ?? diger.id, etiket, etiket == null && !guvenilmez),
        );
      }
      if (mounted) setState(() => _satirlar = satirlar);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(dokumOkunamadi)));
      Navigator.pop(context);
    }
  }

  int get _secili => _satirlar?.where((s) => s.isaretli).length ?? 0;

  Future<void> _kategoriSec(int i) async {
    final kategoriler = uygunKategoriler(
      ref.read(kategorilerProvider).value ?? const [],
      _dokum[i].gelir,
    );
    final id = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: EdgeInsets.only(bottom: altBosluk(ctx)),
        children: [
          ListTile(
            title: Text(
              dokumKategoriSec,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          for (final c in kategoriler)
            ListTile(
              key: ValueKey('dokum-kat-${c.id}'),
              leading: Icon(kategoriSimgesi(c.icon)),
              title: Text(c.name),
              selected: c.id == _satirlar![i].kategoriId,
              onTap: () => Navigator.pop(ctx, c.id),
            ),
        ],
      ),
    );
    if (id != null) setState(() => _satirlar![i].kategoriId = id);
  }

  Future<void> _ekle() async {
    if (_kaydediyor) return;
    setState(() => _kaydediyor = true);
    final db = ref.read(databaseProvider);
    final mesaj = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final n = await iceAktarKaydet(db, ref.read(bildirimProvider), [
        for (var i = 0; i < _dokum.length; i++)
          if (_satirlar![i].isaretli)
            (
              gun: _dokum[i].gun,
              not: _dokum[i].aciklama,
              tutarKurus: _dokum[i].tutarKurus,
              gelir: _dokum[i].gelir,
              kategoriId: _satirlar![i].kategoriId,
            ),
      ]);
      final banka = widget.dokum.sonBakiyeKurus;
      try {
        final guvenilmez = widget.dokum.ocr && widget.dokum.tutarsiz;
        if (banka != null && mounted && !guvenilmez) {
          await _bakiyeSor(db, banka);
        }
      } catch (_) {
        // İşlemler yazıldı; eşitleme başarısızsa kullanıcı Özet'ten elle yapabilir.
      }
      nav.pop();
      mesaj.showSnackBar(SnackBar(content: Text(dokumEklendi(n))));
    } catch (_) {
      if (mounted) setState(() => _kaydediyor = false);
      mesaj.showSnackBar(const SnackBar(content: Text(kaydedilemedi)));
    }
  }

  Future<void> _bakiyeSor(AppDatabase db, int banka) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(dokumBakiyeSorusu(paraYaz(banka))),
        actions: [
          TextButton(
            key: const ValueKey('dokum-bakiye-hayir'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(dokumBakiyeHayir),
          ),
          FilledButton(
            key: const ValueKey('dokum-bakiye-evet'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(dokumBakiyeEvet),
          ),
        ],
      ),
    );
    if (evet != true) return;
    final t = await db.tumToplamlar();
    await db.acilisBakiyeYaz(bankaBakiyesindenAcilis(banka, t.gelir, t.gider));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yesil = tema.brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;
    final kategoriler = {
      for (final c
          in ref.watch(kategorilerProvider).value ?? const <Category>[])
        c.id: c,
    };
    final satirlar = _satirlar;
    final ocrTutarsiz = widget.dokum.ocr && widget.dokum.tutarsiz;
    final uyari = widget.dokum.atlanan > 0 || widget.dokum.tutarsiz;
    return Scaffold(
      appBar: AppBar(
        title: Text(dokumBaslik(widget.dokum.banka, _dokum.length)),
      ),
      body: satirlar == null
          ? const SizedBox()
          : Column(
              children: [
                if (widget.dokum.ocr)
                  Material(
                    color: tema.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        dokumOcrBilgi,
                        key: const ValueKey('dokum-ocr-bilgi'),
                        style: TextStyle(
                          color: tema.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                if (uyari)
                  Material(
                    color: tema.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        ocrTutarsiz ? dokumOcrTutarsiz : dokumUyari,
                        key: const ValueKey('dokum-uyari'),
                        style: TextStyle(
                          color: tema.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: satirlar.length,
                    itemBuilder: (_, i) {
                      final d = _dokum[i];
                      final s = satirlar[i];
                      final kat = kategoriler[s.kategoriId];
                      return ListTile(
                        key: ValueKey('dokum-satir-$i'),
                        leading: Checkbox(
                          key: ValueKey('dokum-isaret-$i'),
                          value: s.isaretli,
                          onChanged: (v) =>
                              setState(() => s.isaretli = v ?? false),
                        ),
                        title: Text(d.aciklama),
                        subtitle: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              DateFormat(
                                'd MMMM y',
                                'tr_TR',
                              ).format(gunTarihi(d.gun)),
                            ),
                            if (s.etiket != null)
                              Text(
                                s.etiket!,
                                style: TextStyle(
                                  color: tema.colorScheme.tertiary,
                                ),
                              ),
                            ActionChip(
                              key: ValueKey('dokum-kat-cip-$i'),
                              avatar: Icon(
                                kategoriSimgesi(kat?.icon ?? -1),
                                size: 18,
                              ),
                              label: Text(kat?.name ?? '?'),
                              onPressed: () => _kategoriSec(i),
                            ),
                          ],
                        ),
                        trailing: Text(
                          d.gelir
                              ? '+${paraYaz(d.tutarKurus)}'
                              : '-${paraYaz(d.tutarKurus)}',
                          style: tema.textTheme.titleSmall?.copyWith(
                            color: d.gelir ? yesil : tema.colorScheme.error,
                          ),
                        ),
                        onTap: () => setState(() => s.isaretli = !s.isaretli),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: satirlar == null
          ? null
          : Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + altBosluk(context)),
              child: FilledButton(
                key: const ValueKey('dokum-ekle'),
                onPressed: _secili == 0 || _kaydediyor ? null : _ekle,
                child: Text(dokumEkleEtiket(_secili)),
              ),
            ),
    );
  }
}
