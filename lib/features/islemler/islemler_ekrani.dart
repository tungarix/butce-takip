import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/para.dart';
import '../../core/tarih.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../ui_metin.dart';
import '../ay_secici.dart';
import '../hizli_giris/hizli_giris.dart';
import '../ikonlar.dart';

class IslemlerEkrani extends ConsumerStatefulWidget {
  const IslemlerEkrani({super.key});

  @override
  ConsumerState<IslemlerEkrani> createState() => _IslemlerEkraniState();
}

class _IslemlerEkraniState extends ConsumerState<IslemlerEkrani> {
  // Kaydırılıp silinen satır, veritabanı akışı güncellenene dek ağaçtan çıkmış olmalı.
  final _gizli = <int>{};

  Future<void> _sil(Transaction t) async {
    final db = ref.read(databaseProvider);
    final mesaj = ScaffoldMessenger.of(context);
    setState(() => _gizli.add(t.id));
    await db.islemSil(t.id);
    mesaj.clearSnackBars();
    mesaj.showSnackBar(
      SnackBar(
        content: const Text(islemSilindi),
        action: SnackBarAction(
          label: geriAlEtiket,
          onPressed: () async {
            await db.islemGeriYukle(t);
            if (mounted) setState(() => _gizli.remove(t.id));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final akis = ref.watch(ayIslemleriProvider);
    final islemler = akis.value;
    final kategoriler = {
      for (final c
          in ref.watch(kategorilerProvider).value ?? const <Category>[])
        c.id: c,
    };
    final liste = islemler?.where((t) => !_gizli.contains(t.id)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AySecici(),
            Expanded(
              child: akis.hasError
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          veriYuklenemedi,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : liste == null
                  ? const SizedBox()
                  : liste.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(bosAyMetni, textAlign: TextAlign.center),
                      ),
                    )
                  : _Liste(liste, kategoriler, _sil),
            ),
          ],
        ),
      ),
    );
  }
}

class _Liste extends StatelessWidget {
  const _Liste(this.islemler, this.kategoriler, this.onSil);

  final List<Transaction> islemler;
  final Map<int, Category> kategoriler;
  final Future<void> Function(Transaction) onSil;

  @override
  Widget build(BuildContext context) {
    // Gün başlığı ve satırlar tek düz liste; islemler gün sırasına göre geliyor.
    final gider = <int, int>{};
    for (final t in islemler) {
      if (!t.isIncome) gider[t.day] = (gider[t.day] ?? 0) + t.amountKurus;
    }
    final ogeler = <Object>[];
    int? son;
    for (final t in islemler) {
      if (t.day != son) ogeler.add(t.day);
      son = t.day;
      ogeler.add(t);
    }
    return ListView.builder(
      // FAB son satırı kapatmasın.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: ogeler.length,
      itemBuilder: (context, i) {
        final o = ogeler[i];
        if (o is int) return _GunBasligi(o, gider[o] ?? 0);
        final t = o as Transaction;
        return _Satir(t, kategoriler[t.categoryId], onSil);
      },
    );
  }
}

class _GunBasligi extends StatelessWidget {
  const _GunBasligi(this.gun, this.giderKurus);

  final int gun;
  final int giderKurus;

  @override
  Widget build(BuildContext context) {
    final stil = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('d MMMM EEEE', 'tr_TR').format(gunTarihi(gun)),
              style: stil,
            ),
          ),
          if (giderKurus > 0) Text(paraYaz(giderKurus), style: stil),
        ],
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir(this.t, this.kategori, this.onSil);

  final Transaction t;
  final Category? kategori;
  final Future<void> Function(Transaction) onSil;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final yesil = tema.brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade700;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: silEtiket): () => onSil(t),
      },
      child: Dismissible(
        key: ValueKey('islem-${t.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: tema.colorScheme.errorContainer,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: Icon(Icons.delete, color: tema.colorScheme.onErrorContainer),
        ),
        onDismissed: (_) => onSil(t),
        child: ListTile(
          leading: Icon(kategoriSimgesi(kategori?.icon ?? -1)),
          title: Text(kategori?.name ?? '?'),
          subtitle: t.note.isEmpty ? null : Text(t.note),
          trailing: Text(
            t.isIncome ? '+${paraYaz(t.amountKurus)}' : paraYaz(t.amountKurus),
            style: tema.textTheme.titleSmall?.copyWith(
              color: t.isIncome ? yesil : null,
            ),
          ),
          onTap: () => hizliGirisAc(context, duzenle: t),
        ),
      ),
    );
  }
}
