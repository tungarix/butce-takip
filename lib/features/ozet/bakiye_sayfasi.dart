import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/butce.dart';
import '../../core/para.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import '../alt_bosluk.dart';
import '../tus_takimi.dart';

/// "Bankadaki bakiyen kaç?": farkı açılış bakiyesine yazar, işlem eklemez.
Future<void> bakiyeSayfasiAc(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _BakiyeSayfasi(),
    );

class _BakiyeSayfasi extends ConsumerStatefulWidget {
  const _BakiyeSayfasi();

  @override
  ConsumerState<_BakiyeSayfasi> createState() => _BakiyeState();
}

class _BakiyeState extends ConsumerState<_BakiyeSayfasi> {
  int _kurus = 0;
  bool _eksi = false;
  String? _hata;

  Future<void> _yaz(Future<void> Function() yazma) async {
    try {
      await yazma();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _hata = kaydedilemedi);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final db = ref.read(databaseProvider);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + altBosluk(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(bankaBakiyeBaslik, style: tema.textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text(bakiyeArtiEtiket)),
              ButtonSegment(value: true, label: Text(bakiyeEksiEtiket)),
            ],
            selected: {_eksi},
            onSelectionChanged: (s) => setState(() => _eksi = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            paraYaz(_eksi ? -_kurus : _kurus),
            key: const ValueKey('bakiye-giris'),
            textAlign: TextAlign.center,
            style: tema.textTheme.headlineMedium?.copyWith(
              color: _eksi && _kurus > 0 ? tema.colorScheme.error : null,
            ),
          ),
          if (_hata != null)
            Text(
              _hata!,
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          const SizedBox(height: 12),
          TusTakimi(
            onRakam: (r) => setState(() => _kurus = tusaBas(_kurus, r)),
            onSil: () => setState(() => _kurus = tusSil(_kurus)),
          ),
          const SizedBox(height: 8),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: const ValueKey('bakiye-sifirla'),
                onPressed: () => _yaz(() => db.acilisBakiyeYaz(0)),
                child: const Text(bakiyeSifirlaEtiket),
              ),
              TextButton(
                key: const ValueKey('bakiye-vazgec'),
                onPressed: () => Navigator.pop(context),
                child: const Text(vazgecEtiket),
              ),
              FilledButton(
                key: const ValueKey('bakiye-kaydet'),
                onPressed: () => _yaz(() async {
                  final t = await db.tumToplamlar();
                  await db.acilisBakiyeYaz(
                    bankaBakiyesindenAcilis(
                      _eksi ? -_kurus : _kurus,
                      t.gelir,
                      t.gider,
                    ),
                  );
                }),
                child: const Text(kaydetEtiket),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
