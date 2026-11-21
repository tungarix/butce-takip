// Yapı Kredi "Hesap Hareketleri" PDF'i: metin parçalarının konumundan satır çıkarır.
// Parçaların akıştaki sırasına güvenilmez, yalnız x/y kullanılır.

import '../core/para.dart';
import 'dokum.dart';

const int _enCokSatir = 5000;

final _tarihRe = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$');
final _tutarRe = RegExp(r'^(-)?(\d{1,3}(?:\.\d{3})*|\d{1,15}),(\d{2}) TL$');

int? _kurus(String t, {required bool eksili}) {
  final m = _tutarRe.firstMatch(t.trim());
  if (m == null || (!eksili && m[1] != null)) return null;
  final v = int.parse('${m[2]!.replaceAll('.', '')}${m[3]}');
  return m[1] != null ? -v : v;
}

int? _gun(String t) {
  final m = _tarihRe.firstMatch(t);
  if (m == null) return null;
  final g = int.parse(m[1]!), a = int.parse(m[2]!), y = int.parse(m[3]!);
  if (y < 2000 || y > 2100) return null;
  final d = DateTime.utc(y, a, g);
  if (d.year != y || d.month != a || d.day != g) return null;
  return y * 10000 + a * 100 + g;
}

String _temizle(String s) =>
    s.replaceAll('�', '?').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Tanınmayan belgede null.
Dokum? yapiKrediOku(List<MetinParcasi> parcalar) {
  if (!parcalar.any((p) => p.t.contains('yapikredi.com.tr')) ||
      !parcalar.any((p) => p.t.trim() == 'Hesap Hareketleri')) {
    return null;
  }

  // Sütun başlıkları: "Tarih" ile aynı yatay çizgideki parçalar.
  final tarihBasliklari = parcalar.where((p) => p.t.trim() == 'Tarih').toList();
  if (tarihBasliklari.isEmpty) return null;
  final tb = tarihBasliklari.first;
  MetinParcasi? basliktan(bool Function(String) uygun) {
    for (final p in parcalar) {
      if ((p.y - tb.y).abs() < 2 && uygun(p.t.trim())) return p;
    }
    return null;
  }

  final aciklamaB = basliktan((t) => t.startsWith('A') && t.endsWith('klama'));
  final tutarB = basliktan((t) => t.contains('Tutar'));
  final bakiyeB = basliktan((t) => t == 'Bakiye');
  if (aciklamaB == null || tutarB == null || bakiyeB == null) return null;

  final aciklamaBas = aciklamaB.x - 5;
  final tutarBas = tutarB.x - 10;
  final bakiyeBas = (tutarB.x + bakiyeB.x) / 2;
  final basliklarY = tarihBasliklari.map((p) => p.y).toList();

  // Veri satırları ve bekleyen ("-") satırlar; ikisi de bant sınırı olur.
  final cap = parcalar
      .where(
        (p) =>
            p.x < aciklamaBas &&
            p.y > tb.y + 2 &&
            (p.t.trim() == '-' || _tarihRe.hasMatch(p.t.trim())),
      )
      .toList()
    ..sort((a, b) => a.y.compareTo(b.y));
  if (cap.isEmpty) return const Dokum(banka: 'Yapı Kredi', satirlar: []);

  // Bant sınırı: iki satırın üst y'sinin ortası (açıklama üstte dikey ortalı durabilir).
  final alt = <double>[
    for (var i = 0; i < cap.length; i++)
      i + 1 < cap.length ? (cap[i].y + cap[i + 1].y) / 2 : cap[i].y + 40,
  ];
  int bant(double y) {
    if (y <= tb.y + 2 || y > alt.last) return -1;
    for (var i = 0; i < alt.length; i++) {
      if (y <= alt[i]) return i;
    }
    return -1;
  }

  final aciklamalar = List.generate(cap.length, (_) => <MetinParcasi>[]);
  final tutarlar = List<String?>.filled(cap.length, null);
  final bakiyeler = List<String?>.filled(cap.length, null);
  for (final p in parcalar) {
    if (p.x < aciklamaBas || basliklarY.any((y) => (y - p.y).abs() < 2)) continue;
    final b = bant(p.y);
    if (b < 0) continue;
    if (p.x >= bakiyeBas) {
      bakiyeler[b] ??= p.t.trim();
    } else if (p.x >= tutarBas) {
      tutarlar[b] ??= p.t.trim();
    } else {
      aciklamalar[b].add(p);
    }
  }

  final satirlar = <DokumSatiri>[];
  var atlanan = 0;
  for (var i = 0; i < cap.length; i++) {
    if (cap[i].t.trim() == '-') continue; // Bekleyen İşlemler
    final gun = _gun(cap[i].t.trim());
    final t = tutarlar[i] == null ? null : _kurus(tutarlar[i]!, eksili: true);
    if (gun == null || t == null || t == 0 || t.abs() > paraUstSinirKurus) {
      atlanan++;
      continue;
    }
    if (satirlar.length >= _enCokSatir) {
      atlanan++;
      continue;
    }
    aciklamalar[i].sort((a, b) {
      final c = a.y.compareTo(b.y);
      return c != 0 ? c : a.x.compareTo(b.x);
    });
    satirlar.add(
      DokumSatiri(
        gun: gun,
        aciklama: _temizle(aciklamalar[i].map((p) => p.t).join(' ')),
        tutarKurus: t.abs(),
        gelir: t > 0,
        bakiyeKurus: bakiyeler[i] == null
            ? null
            : _kurus(bakiyeler[i]!, eksili: true),
      ),
    );
  }

  // Yeni hareket üstte: bakiye[i] = bakiye[i+1] + işaretli tutar[i].
  var tutarsiz = false;
  for (var i = 0; i + 1 < satirlar.length; i++) {
    final b = satirlar[i].bakiyeKurus, s = satirlar[i + 1].bakiyeKurus;
    if (b == null || s == null) continue;
    final t = satirlar[i].gelir ? satirlar[i].tutarKurus : -satirlar[i].tutarKurus;
    if (b != s + t) tutarsiz = true;
  }

  return Dokum(
    banka: 'Yapı Kredi',
    satirlar: satirlar,
    sonBakiyeKurus: satirlar.isEmpty ? null : satirlar.first.bakiyeKurus,
    atlanan: atlanan,
    tutarsiz: tutarsiz,
  );
}
