import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/para.dart';
import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import '../ikonlar.dart';

const hizliGirisCipSayisi = 6;

/// Hızlı giriş alt sayfasını açar. [duzenle] verilirse o işlemin değerleriyle düzenleme olur.
Future<void> hizliGirisAc(BuildContext context, {Transaction? duzenle}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HizliGirisSayfasi(duzenle: duzenle),
    );

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
  const HizliGirisSayfasi({super.key, this.duzenle});

  final Transaction? duzenle;

  @override
  ConsumerState<HizliGirisSayfasi> createState() => _HizliGirisState();
}

class _HizliGirisState extends ConsumerState<HizliGirisSayfasi> {
  late int _kurus;
  late bool _gelir;
  late DateTime _tarih;
  late final TextEditingController _not;
  int? _kategoriId;
  bool _tumu = false;
  bool _kaydediyor = false;

  Transaction? get _duzenle => widget.duzenle;

  @override
  void initState() {
    super.initState();
    final t = _duzenle;
    _kurus = t?.amountKurus ?? 0;
    _gelir = t?.isIncome ?? false;
    _tarih = t == null ? DateTime.now() : gunTarihi(t.day);
    _not = TextEditingController(text: t?.note ?? '');
    _kategoriId = t?.categoryId;
  }

  @override
  void dispose() {
    _not.dispose();
    super.dispose();
  }

  Future<void> _kaydet(int kategoriId) async {
    if (_kaydediyor) return;
    _kaydediyor = true;
    final db = ref.read(databaseProvider);
    final gun = gunAnahtari(_tarih);
    final t = _duzenle;
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
    if (mounted) Navigator.pop(context);
  }

  void _cipeDokun(Category c) {
    if (_duzenle != null) {
      setState(() => _kategoriId = c.id);
      return;
    }
    if (_kurus == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(onceTutarYaz)));
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

  Widget _cip(Category c) => ChoiceChip(
    key: ValueKey('cip-${c.id}'),
    avatar: Icon(kategoriSimgesi(c.icon), size: 18),
    label: Text(c.name),
    selected: _kategoriId == c.id,
    onSelected: (_) => _cipeDokun(c),
  );

  @override
  Widget build(BuildContext context) {
    final kategoriler = ref.watch(kategorilerProvider).value ?? const [];
    final son = ref.watch(sonIslemlerProvider).value ?? const [];
    final sirali = siraliKategoriler(
      kategoriler,
      son,
      _gelir,
      dahilId: _duzenle?.categoryId,
    );
    final ilk = sirali.take(hizliGirisCipSayisi).toList();
    final kalan = sirali.skip(hizliGirisCipSayisi).toList();
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                if (_tumu) for (final c in kalan) _cip(c),
              ],
            ),
            const SizedBox(height: 8),
            _tuslar(),
            ExpansionTile(
              key: const ValueKey('ayrinti'),
              title: const Text(ayrintiEtiket),
              initiallyExpanded: _duzenle != null,
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
                  }),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('not'),
                  controller: _not,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: notEtiket),
                ),
                ListTile(
                  key: const ValueKey('tarih'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(
                    DateFormat('d MMMM y, EEEE', 'tr_TR').format(_tarih),
                  ),
                  onTap: _tarihSec,
                ),
              ],
            ),
            if (_duzenle != null)
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

  Widget _tuslar() {
    Widget tus(Widget cocuk, String etiket, VoidCallback onPressed, Key key) =>
        Semantics(
          button: true,
          label: etiket,
          excludeSemantics: true,
          child: FilledButton.tonal(
            key: key,
            style: FilledButton.styleFrom(minimumSize: const Size(64, 56)),
            onPressed: onPressed,
            child: cocuk,
          ),
        );
    Widget rakam(int r) => tus(
      Text('$r', style: const TextStyle(fontSize: 22)),
      rakamEtiket(r),
      () => setState(() => _kurus = tusaBas(_kurus, r)),
      ValueKey('tus-$r'),
    );
    return Column(
      children: [
        for (final satir in const [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                for (final r in satir) ...[
                  Expanded(child: rakam(r)),
                  if (r % 3 != 0) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        Row(
          children: [
            const Expanded(child: SizedBox()),
            const SizedBox(width: 8),
            Expanded(child: rakam(0)),
            const SizedBox(width: 8),
            Expanded(
              child: tus(
                const Icon(Icons.backspace_outlined),
                geriTusuEtiket,
                () => setState(() => _kurus = tusSil(_kurus)),
                const ValueKey('tus-sil'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
