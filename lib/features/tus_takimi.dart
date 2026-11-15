import 'package:flutter/material.dart';

import '../ui_metin.dart';

/// Sağdan dolan tutar tuş takımı (hızlı giriş ve limit girişi ortak kullanır).
class TusTakimi extends StatelessWidget {
  const TusTakimi({super.key, required this.onRakam, required this.onSil});

  final void Function(int rakam) onRakam;
  final VoidCallback onSil;

  Widget _tus(Widget cocuk, String etiket, VoidCallback onPressed, Key key) =>
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

  Widget _rakam(int r) => _tus(
    Text('$r', style: const TextStyle(fontSize: 22)),
    rakamEtiket(r),
    () => onRakam(r),
    ValueKey('tus-$r'),
  );

  @override
  Widget build(BuildContext context) => Column(
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
                Expanded(child: _rakam(r)),
                if (r % 3 != 0) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      Row(
        children: [
          const Expanded(child: SizedBox()),
          const SizedBox(width: 8),
          Expanded(child: _rakam(0)),
          const SizedBox(width: 8),
          Expanded(
            child: _tus(
              const Icon(Icons.backspace_outlined),
              geriTusuEtiket,
              onSil,
              const ValueKey('tus-sil'),
            ),
          ),
        ],
      ),
    ],
  );
}
