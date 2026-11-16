import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../akilli/kategori_onerici.dart';
import '../../akilli/normalize.dart';
import '../../core/para.dart';
import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../platform/bildirimler.dart';
import '../../ui_metin.dart';
import '../alt_bosluk.dart';
import '../ikonlar.dart';
import '../tus_takimi.dart';

const hizliGirisCipSayisi = 6;

/// Hızlı giriş alt sayfasını açar. [duzenle] verilirse o işlemin değerleriyle düzenleme olur.
/// [dolu] verilirse yeni işlem bu değerlerle önceden doldurulmuş açılır; kullanıcı Kaydet'e basmadan kayıt olmaz.
Future<void> hizliGirisAc(
  BuildContext context, {
  Transaction? duzenle,
  OnDoldurma? dolu,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => HizliGirisSayfasi(duzenle: duzenle, dolu: dolu),
);

typedef OnDoldurma = ({int kurus, int kategoriId, String not});

/// Çip sırası: son işlemlerdeki kullanım sayısı (çoktan aza), eşitlikte sortOrder.
/// Arşivliler hariç; [dahilId] (düzenlenen işlemin kategorisi) arşivli olsa da kalır.
List<Category> siraliKategoriler(
  List<Category> kategoriler,
  List<Transaction> sonIslemler,
  bool gelir, {
  int? dahilId,
}) {
  final sayi = <int, int>{};
  for (final t in sonIslemler) {
    sayi[t.categoryId] = (sayi[t.categoryId] ?? 0) + 1;
  }
  return kategoriler
      .where((c) => c.isIncome == gelir && (!c.archived || c.id == dahilId))
      .toList()
    ..sort((a, b) {
      final f = (sayi[b.id] ?? 0).compareTo(sayi[a.id] ?? 0);
      return f != 0 ? f : a.sortOrder.compareTo(b.sortOrder);
    });
}

class HizliGirisSayfasi extends ConsumerStatefulWidget {
  const HizliGirisSayfasi({super.key, this.duzenle, this.dolu});

  final Transaction? duzenle;
  final OnDoldurma? dolu;

  @override
  ConsumerState<HizliGirisSayfasi> createState() => _HizliGirisState();
}

class _HizliGirisState extends ConsumerState<HizliGirisSayfasi> {
  late int _kurus;
  late bool _gelir;
  late DateTime _tarih;
  late final TextEditingController _not;
  int? _kategoriId;
  // Not yazıldıkça (kısa gecikmeyle) hesaplanan önerilen kategori; asla kendiliğinden seçilmez.
  int? _oneri;
  Timer? _oneriZamani;
  int _oneriNo = 0;
  bool _tumu = false;
  bool _kaydediyor = false;
  // Alt sayfanın içinde, tutarın altında kısa süre görünen hata metni.
  String? _mesaj;
  Timer? _mesajZamani;

  Transaction? get _duzenle => widget.duzenle;

  /// Düzenleme ve önceden doldurulmuş giriş: çipe dokunmak kaydetmez, Kaydet düğmesi vardır.
  bool get _butonlu => _duzenle != null || widget.dolu != null;

  @override
  void initState() {
    super.initState();
    final t = _duzenle;
    final d = widget.dolu;
    _kurus = t?.amountKurus ?? d?.kurus ?? 0;
    _gelir = t?.isIncome ?? false;
    _tarih = t == null ? DateTime.now() : gunTarihi(t.day);
    _not = TextEditingController(text: t?.note ?? d?.not ?? '');
    _kategoriId = t?.categoryId ?? d?.kategoriId;
  }

  @override
  void dispose() {
    _mesajZamani?.cancel();
    _oneriZamani?.cancel();
    _not.dispose();
    super.dispose();
  }

  void _mesajGoster(String mesaj) {
    _mesajZamani?.cancel();
    setState(() => _mesaj = mesaj);
    _mesajZamani = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _mesaj = null);
    });
  }

  void _oneriyiPlanla() {
    _oneriZamani?.cancel();
    _oneriZamani = Timer(const Duration(milliseconds: 250), _oneriyiHesapla);
  }

  Future<void> _oneriyiHesapla() async {
    final no = ++_oneriNo;
    final sozcukler = notSozcukleri(_not.text);
    int? bulunan;
    if (sozcukler.isNotEmpty) {
      try {
        final satirlar = await ref
            .read(databaseProvider)
            .anahtarSatirlari(sozcukler);
        if (!mounted || no != _oneriNo) return;
        bulunan = kategoriOner(
          sozcukler,
          [
            for (final k in satirlar)
              (keyword: k.keyword, categoryId: k.categoryId, hits: k.hits),
          ],
          [for (final c in _siraliCipler()) c.id],
        );
      } catch (_) {
        // Öneri yardımcıdır; okunamazsa öneri çıkmaz.
      }
    }
    if (mounted && no == _oneriNo) setState(() => _oneri = bulunan);
  }

  /// Çip sırası; arşivli kategori (düzenlenen işlemin kendisi hariç) ve türü uymayan yoktur.
  List<Category> _siraliCipler() => siraliKategoriler(
    ref.read(kategorilerProvider).value ?? const [],
    ref.read(sonIslemlerProvider).value ?? const [],
    _gelir,
    dahilId: _duzenle?.categoryId,
  ).where((c) => !c.archived).toList();

  Future<void> _kaydet(int kategoriId) async {
    if (_kaydediyor) return;
    _kaydediyor = true;
    try {
      final db = ref.read(databaseProvider);
      final bildirim = ref.read(bildirimProvider);
      final gun = gunAnahtari(_tarih);
      final t = _duzenle;
      // Aşım bildirimi için kaydın düşeceği (kategori, ay) kovasının yazmadan önceki toplamı.
      final once = _gelir
          ? 0
          : await db.ayKategoriGideri(kategoriId, gun ~/ 100);
      if (t == null) {
        await db.islemEkle(
          tutarKurus: _kurus,
          gelir: _gelir,
          kategoriId: kategoriId,
          not: _not.text,
          gun: gun,
        );
      } else {
        await db.islemGuncelle(
          t.id,
          tutarKurus: _kurus,
          gelir: _gelir,
          kategoriId: kategoriId,
          not: _not.text,
          gun: gun,
        );
      }
      if (!_gelir) {
        try {
          await asimKontrol(
            db,
            bildirim,
            kategoriId: kategoriId,
            gun: gun,
            once: once,
          );
        } catch (_) {
          // Kayıt yapıldı; bildirim hatası kaydı başarısız göstermesin.
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) _mesajGoster(kaydedilemedi);
    } finally {
      _kaydediyor = false;
    }
  }

  void _cipeDokun(Category c) {
    if (_butonlu) {
      setState(() => _kategoriId = c.id);
      return;
    }
    if (_kurus == 0) {
      _mesajGoster(onceTutarYaz);
      return;
    }
    setState(() => _kategoriId = c.id);
    _kaydet(c.id);
  }

  Future<void> _tarihSec() async {
    final secilen = await showDatePicker(
      context: context,
      initialDate: _tarih,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (secilen != null) setState(() => _tarih = secilen);
  }

  Widget _cip(Category c) {
    final onerilen = c.id == _oneri;
    return ChoiceChip(
      key: ValueKey('cip-${c.id}'),
      // Öneri yalnız renkle değil simgeyle ve ekran okuyucu etiketiyle de belli olur.
      avatar: Icon(
        onerilen ? Icons.auto_awesome : kategoriSimgesi(c.icon),
        size: 18,
      ),
      label: Text(c.name, semanticsLabel: cipSemantigi(c.name, onerilen)),
      selected: _kategoriId == c.id,
      onSelected: (_) => _cipeDokun(c),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kategoriler = ref.watch(kategorilerProvider).value ?? const [];
    final son = ref.watch(sonIslemlerProvider).value ?? const [];
    var sirali = siraliKategoriler(
      kategoriler,
      son,
      _gelir,
      dahilId: _duzenle?.categoryId ?? widget.dolu?.kategoriId,
    );
    final oneri = sirali.where((c) => c.id == _oneri && !c.archived);
    if (oneri.isNotEmpty) {
      sirali = [oneri.first, ...sirali.where((c) => c.id != _oneri)];
    }
    final ilk = sirali.take(hizliGirisCipSayisi).toList();
    final kalan = sirali.skip(hizliGirisCipSayisi).toList();
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: altBosluk(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_butonlu)
              Text(
                _duzenle != null ? islemDuzenleBaslik : tekrarIslemiBaslik,
                textAlign: TextAlign.center,
                style: tema.textTheme.titleMedium,
              ),
            Semantics(
              label: tutarEtiket,
              value: paraYaz(_kurus),
              excludeSemantics: true,
              child: Text(
                paraYaz(_kurus),
                key: const ValueKey('tutar'),
                textAlign: TextAlign.center,
                style: tema.textTheme.displayMedium?.copyWith(
                  color: _kurus == 0 ? tema.colorScheme.outline : null,
                ),
              ),
            ),
            if (_mesaj != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _mesaj!,
                  key: const ValueKey('mesaj'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in ilk) _cip(c),
                if (kalan.isNotEmpty)
                  ActionChip(
                    key: const ValueKey('cip-tumu'),
                    label: Text(tumuEtiket),
                    avatar: Icon(
                      _tumu ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _tumu = !_tumu),
                  ),
                if (_tumu)
                  for (final c in kalan) _cip(c),
              ],
            ),
            const SizedBox(height: 8),
            TusTakimi(
              onRakam: (r) => setState(() {
                _kurus = tusaBas(_kurus, r);
                _mesaj = null;
              }),
              onSil: () => setState(() => _kurus = tusSil(_kurus)),
            ),
            ExpansionTile(
              key: const ValueKey('ayrinti'),
              title: const Text(ayrintiEtiket),
              initiallyExpanded: _butonlu,
              shape: const Border(),
              collapsedShape: const Border(),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text(giderEtiket)),
                    ButtonSegment(value: true, label: Text(gelirEtiket)),
                  ],
                  selected: {_gelir},
                  onSelectionChanged: (s) => setState(() {
                    _gelir = s.first;
                    _kategoriId = null;
                    _oneri = null;
                    _oneriyiPlanla();
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('not'),
                  controller: _not,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: notEtiket),
                  onChanged: (_) => _oneriyiPlanla(),
                ),
                ListTile(
                  key: const ValueKey('tarih'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: const Text(tarihEtiket),
                  subtitle: Text(
                    DateFormat('d MMMM y, EEEE', 'tr_TR').format(_tarih),
                  ),
                  onTap: _tarihSec,
                ),
              ],
            ),
            if (_butonlu)
              FilledButton(
                key: const ValueKey('kaydet'),
                onPressed: _kurus > 0 && _kategoriId != null
                    ? () => _kaydet(_kategoriId!)
                    : null,
                child: const Text(kaydetEtiket),
              ),
          ],
        ),
      ),
    );
  }
}
