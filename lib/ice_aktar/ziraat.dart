// Ziraat Bankası "Hesap Hareketleri": OCR kelime kutularının konumundan satır çıkarır.
// Ölçekten bağımsız: boyutlar kelime yüksekliği medyanından ve başlık kelimelerinden türer.
// Güvenlik ağı: bakiye zinciri ve Borç/Alacak toplamları tutmazsa Dokum.tutarsiz = true.

import '../core/para.dart';
import 'dokum.dart';

const int _enCokSatir = 5000;

final _tarihRe = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');
final _tarihBenzeriRe = RegExp(
  r'^\S{2}\.\S{2}\.\S{4}$',
); // OCR'ın bozduğu tarih de satır sayılır
final _tutarRe = RegExp(r'^(-)?(\d{1,3}(?:\.\d{3})*|\d{1,15}),(\d{2})$');

String _kucuk(String t) => t.replaceAll('İ', 'i').toLowerCase().trim();

double _oy(MetinParcasi p) => p.y + p.h / 2;
double _ox(MetinParcasi p) => p.x + p.w / 2;

int? _kurus(String t) {
  var temiz = t.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp('[–−—]'), '-');
  // OCR kuruş virgülünü nokta okuyabiliyor ('983.26'); tutarlar hep 2 kuruş basamaklı ve
  // virgüllü yazıldığından virgülsüz '.dd' sonu kuruştur. Yanlış okumayı zincir/toplam yakalar.
  if (!temiz.contains(',')) {
    temiz = temiz.replaceFirstMapped(RegExp(r'\.(\d{2})$'), (m) => ',${m[1]}');
  }
  final m = _tutarRe.firstMatch(temiz);
  if (m == null) return null;
  final v = int.tryParse('${m[2]!.replaceAll('.', '')}${m[3]}');
  if (v == null) return null;
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

/// Kelimeleri x sırasıyla boşluksuz birleştirir (bölünmüş tutar kelimeleri için).
String _birlestir(Iterable<MetinParcasi> kelimeler) =>
    (kelimeler.toList()..sort((a, b) => a.x.compareTo(b.x)))
        .map((p) => p.t.trim())
        .join();

/// Tanınmayan belgede null.
Dokum? ziraatOku(List<MetinParcasi> kelimeler) {
  if (!kelimeler.any((p) => _kucuk(p.t).contains('ziraat'))) return null;

  final yukseklikler = [
    for (final p in kelimeler)
      if (p.h > 0) p.h,
  ]..sort();
  if (yukseklikler.isEmpty) return null;
  final medH = yukseklikler[yukseklikler.length ~/ 2];
  final tol = medH * 1.1; // yarım satır: satır aralığı ~2.2 kelime yüksekliği

  // Başlık satırı: aynı yatay çizgide "Tutar" ve "Bakiye".
  MetinParcasi? tutarB, bakiyeB;
  for (final t in kelimeler.where((p) => _kucuk(p.t) == 'tutar')) {
    for (final b in kelimeler.where((p) => _kucuk(p.t) == 'bakiye')) {
      if ((_oy(t) - _oy(b)).abs() <= medH &&
          (tutarB == null || t.y < tutarB.y)) {
        tutarB = t;
        bakiyeB = b;
      }
    }
  }
  if (tutarB == null || bakiyeB == null) return null;
  final baslikY = _oy(tutarB);
  final baslik =
      kelimeler.where((p) => (_oy(p) - baslikY).abs() <= medH).toList()
        ..sort((a, b) => a.x.compareTo(b.x));

  // Açıklama başlığı: "Fiş No"dan sonraki ilk başlık (OCR "Açıklama"yı bozabilir); yoksa Tutar'dan önceki.
  final noIdx = baslik.indexWhere((p) => _kucuk(p.t) == 'no');
  final tutarIdx = baslik.indexOf(tutarB);
  final aciklamaIdx = noIdx >= 0 && noIdx + 1 < tutarIdx
      ? noIdx + 1
      : tutarIdx - 1;
  if (aciklamaIdx < 1) return null;
  final aciklamaB = baslik[aciklamaIdx];

  final aciklamaBas = aciklamaB.x - medH;
  final tutarBas = tutarB.x - tutarB.w;
  final bakiyeBas = (tutarB.x + tutarB.w + bakiyeB.x) / 2;

  final altta = kelimeler.where((p) => _oy(p) > baslikY + tol).toList();
  final capalar =
      altta
          .where(
            (p) => p.x < aciklamaBas && _tarihBenzeriRe.hasMatch(p.t.trim()),
          )
          .toList()
        ..sort((a, b) => _oy(a).compareTo(_oy(b)));
  if (capalar.isEmpty) {
    return const Dokum(banka: 'Ziraat Bankası', satirlar: [], ocr: true);
  }

  // Her kelime, dikey merkezi yarım satır içindeki en yakın çapanın satırına girer.
  int satirNo(MetinParcasi p) {
    var en = -1;
    var fark = tol;
    for (var i = 0; i < capalar.length; i++) {
      final f = (_oy(p) - _oy(capalar[i])).abs();
      if (f <= fark) {
        fark = f;
        en = i;
      }
    }
    return en;
  }

  final aciklamalar = List.generate(capalar.length, (_) => <MetinParcasi>[]);
  final tutarlar = List.generate(capalar.length, (_) => <MetinParcasi>[]);
  final bakiyeler = List.generate(capalar.length, (_) => <MetinParcasi>[]);
  for (final p in altta) {
    final i = satirNo(p);
    if (i < 0 || p.x < aciklamaBas) continue; // Tarih ve Fiş No sütunları
    final x = _ox(p);
    if (x >= bakiyeBas) {
      bakiyeler[i].add(p);
    } else if (x >= tutarBas) {
      tutarlar[i].add(p);
    } else {
      aciklamalar[i].add(p);
    }
  }

  final satirlar = <DokumSatiri>[];
  var atlanan = 0;
  var bakiyeBilinmiyor = false;
  for (var i = 0; i < capalar.length; i++) {
    final gun = _gun(capalar[i].t.trim());
    final t = _kurus(_birlestir(tutarlar[i]));
    if (gun == null ||
        t == null ||
        t == 0 ||
        t.abs() > paraUstSinirKurus ||
        satirlar.length >= _enCokSatir) {
      atlanan++;
      continue;
    }
    final b = _kurus(_birlestir(bakiyeler[i]));
    if (b == null) bakiyeBilinmiyor = true;
    satirlar.add(
      DokumSatiri(
        gun: gun,
        aciklama: (aciklamalar[i].toList()..sort((a, b) => a.x.compareTo(b.x)))
            .map((p) => p.t.trim())
            .join(' '),
        tutarKurus: t.abs(),
        gelir: t > 0,
        bakiyeKurus: b,
      ),
    );
  }

  // (a) Yeni hareket üstte: bakiye[i] = bakiye[i+1] + işaretli tutar[i]; okunamayan bakiye doğrulanamaz.
  var tutarsiz = bakiyeBilinmiyor;
  for (var i = 0; i + 1 < satirlar.length; i++) {
    final b = satirlar[i].bakiyeKurus, s = satirlar[i + 1].bakiyeKurus;
    if (b == null || s == null) continue;
    final t = satirlar[i].gelir
        ? satirlar[i].tutarKurus
        : -satirlar[i].tutarKurus;
    if (b != s + t) tutarsiz = true;
  }

  // (b) Borç: / Alacak: satırlarının tutarı toplamlarla aynı olmalı (satır atlanmadıysa).
  if (atlanan == 0) {
    int? toplam(bool Function(String) etiket) {
      for (final e in altta.where(
        (p) => p.x < tutarBas && etiket(_kucuk(p.t)),
      )) {
        final v = _kurus(
          _birlestir(
            altta.where(
              (p) =>
                  (_oy(p) - _oy(e)).abs() <= tol &&
                  _ox(p) >= tutarBas &&
                  _ox(p) < bakiyeBas,
            ),
          ),
        );
        return v?.abs();
      }
      return null;
    }

    final borc = toplam((t) => RegExp(r'^bor.{0,2}:?$').hasMatch(t));
    final alacak = toplam((t) => t.startsWith('alacak'));
    final gider = satirlar
        .where((s) => !s.gelir)
        .fold(0, (a, s) => a + s.tutarKurus);
    final gelir = satirlar
        .where((s) => s.gelir)
        .fold(0, (a, s) => a + s.tutarKurus);
    // Etiket hiç okunmadıysa yalnız o türden satır yoksa sorun sayılmaz.
    if ((borc ?? 0) != gider || (alacak ?? 0) != gelir) tutarsiz = true;
  }

  return Dokum(
    banka: 'Ziraat Bankası',
    satirlar: satirlar,
    sonBakiyeKurus: satirlar.isEmpty ? null : satirlar.first.bakiyeKurus,
    atlanan: atlanan,
    // Atlanan satır varsa toplam denetimi yapılamaz; görüntüden okunan dökümde güvenilmez say.
    tutarsiz: tutarsiz || atlanan > 0,
    ocr: true,
  );
}
