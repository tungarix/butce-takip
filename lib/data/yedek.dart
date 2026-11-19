import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart'
    show BooleanExpressionOperators, StringExpressionOperators;

import '../core/para.dart';
import '../core/tarih.dart';
import 'database/database.dart';

const yedekUygulamaAdi = 'butce-takip';

/// Doğrulama ya da uygulama hatası; [mesaj] kullanıcıya olduğu gibi gösterilir.
class YedekHatasi implements Exception {
  const YedekHatasi(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}

// 2000-01-01 ve 2100-01-01 (epoch ms, UTC).
const _enErkenOlusturuldu = 946684800000;
const _enGecOlusturuldu = 4102444800000;
// Büyük kimlik SQLite AUTOINCREMENT sayacını tavana kilitler; 2^53 makul sınır.
const _enBuyukId = 9007199254740992;
const _enBuyukSayac = 1000000000;

// Güncelleyicinin cihaza özel ayarları (update_check, update_record, update_wifi_only):
// yedeğe yazılmaz, geri yüklemede yedekten alınmaz, cihazdakiler korunur.
const _cihazaOzelOnek = 'update_';

typedef Satir = Map<String, Object?>;

/// Doğrulanmış yedek. Doğrulama dışında kurulmamalı; testler dışında kurucu çağrılmaz.
class Yedek {
  const Yedek({
    required this.schemaVersion,
    required this.olusturuldu,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.keywordHits,
    required this.settings,
  });

  final int schemaVersion;
  final int olusturuldu; // epoch ms
  final List<Satir> categories;
  final List<Satir> transactions;
  final List<Satir> budgets;
  final List<Satir> keywordHits;
  final List<Satir> settings;
}

/// Tüm tabloları tek JSON'a yazar. Tutarlar kuruş int.
Future<String> yedekOlustur(AppDatabase db, {int? simdi}) async {
  final kategoriler = await db.select(db.categories).get();
  final islemler = await db.select(db.transactions).get();
  final limitler = await db.select(db.budgets).get();
  final sozcukler = await db.select(db.keywordHits).get();
  final ayarlar = await db.select(db.settings).get();
  List<Object?> sat(List<dynamic> l) => [for (final r in l) r.toJson()];
  return jsonEncode({
    'uygulama': yedekUygulamaAdi,
    'schemaVersion': db.schemaVersion,
    'olusturuldu': simdi ?? DateTime.now().millisecondsSinceEpoch,
    'categories': sat(kategoriler),
    'transactions': sat(islemler),
    'budgets': sat(limitler),
    'keyword_hits': sat(sozcukler),
    'settings': sat([
      for (final a in ayarlar)
        if (!a.key.startsWith(_cihazaOzelOnek)) a,
    ]),
  });
}

/// Metni TAMAMEN doğrular; herhangi bir sorunda [YedekHatasi] fırlatır. Veritabanına dokunmaz.
Yedek yedekDogrula(String metin, {required int guncelSurum}) {
  final Object? kok;
  try {
    kok = jsonDecode(metin);
  } on FormatException {
    throw const YedekHatasi('Dosya geçerli bir yedek değil (JSON okunamadı).');
  }
  if (kok is! Map<String, Object?>) {
    throw const YedekHatasi('Dosya geçerli bir yedek değil.');
  }
  if (kok['uygulama'] != yedekUygulamaAdi) {
    throw const YedekHatasi('Bu dosya Bütçe Takip yedeği değil.');
  }
  final surum = kok['schemaVersion'];
  if (surum is! int || surum < 1) {
    throw const YedekHatasi('Yedeğin sürüm bilgisi eksik ya da bozuk.');
  }
  if (surum > guncelSurum) {
    throw const YedekHatasi(
      'Bu yedek uygulamanın daha yeni bir sürümüyle alınmış. '
      'Önce uygulamayı güncelle, sonra tekrar dene.',
    );
  }
  final olusturuldu = _tamsayi(kok, 'olusturuldu', 'yedek');
  if (olusturuldu < _enErkenOlusturuldu || olusturuldu > _enGecOlusturuldu) {
    throw const YedekHatasi('Yedeğin oluşturulma tarihi geçersiz.');
  }

  final kategoriler = _liste(kok, 'categories');
  final kategoriIdleri = <int>{};
  final adlar = <String>{};
  for (final r in kategoriler) {
    const t = 'categories';
    if (!kategoriIdleri.add(_kimlik(r, 'id', t))) {
      throw const YedekHatasi('Yedekte aynı numaralı iki kategori var.');
    }
    final ad = _yazi(r, 'name', t);
    if (ad.trim().isEmpty) {
      throw const YedekHatasi('Yedekte adı boş kategori var.');
    }
    if (!adlar.add(ad)) {
      throw YedekHatasi('Yedekte "$ad" adlı birden fazla kategori var.');
    }
    _tamsayi(r, 'icon', t);
    _mantiksal(r, 'isIncome', t);
    _tamsayi(r, 'sortOrder', t);
    _mantiksal(r, 'archived', t);
  }

  void kategoriVar(Satir r, String t) {
    if (!kategoriIdleri.contains(_tamsayi(r, 'categoryId', t))) {
      throw YedekHatasi('$t: olmayan bir kategoriye bağlı kayıt var.');
    }
  }

  final islemler = _liste(kok, 'transactions');
  final islemIdleri = <int>{};
  for (final r in islemler) {
    const t = 'transactions';
    if (!islemIdleri.add(_kimlik(r, 'id', t))) {
      throw const YedekHatasi('Yedekte aynı numaralı iki işlem var.');
    }
    final tutar = _tamsayi(r, 'amountKurus', t);
    if (tutar <= 0) {
      throw const YedekHatasi('Yedekte tutarı sıfır ya da eksi bir işlem var.');
    }
    if (tutar > paraUstSinirKurus) {
      throw const YedekHatasi('Yedekte tutarı çok büyük bir işlem var.');
    }
    _mantiksal(r, 'isIncome', t);
    kategoriVar(r, t);
    _yazi(r, 'note', t);
    _yazi(r, 'noteNorm', t);
    if (!_gecerliGun(_tamsayi(r, 'day', t))) {
      throw const YedekHatasi('Yedekte geçersiz tarihli bir işlem var.');
    }
    _tamsayi(r, 'createdAt', t);
  }

  final limitler = _liste(kok, 'budgets');
  final limitKategorileri = <int>{};
  for (final r in limitler) {
    const t = 'budgets';
    kategoriVar(r, t);
    if (!limitKategorileri.add(r['categoryId']! as int)) {
      throw const YedekHatasi('Yedekte bir kategori için iki limit var.');
    }
    final limit = _tamsayi(r, 'monthlyLimitKurus', t);
    if (limit <= 0) {
      throw const YedekHatasi('Yedekte sıfır ya da eksi bir limit var.');
    }
    if (limit > paraUstSinirKurus) {
      throw const YedekHatasi('Yedekte çok büyük bir limit var.');
    }
  }

  final sozcukler = _liste(kok, 'keyword_hits');
  final sozcukCiftleri = <String>{};
  for (final r in sozcukler) {
    const t = 'keyword_hits';
    kategoriVar(r, t);
    final k = _yazi(r, 'keyword', t);
    if (!sozcukCiftleri.add('${r['categoryId']}|$k')) {
      throw const YedekHatasi('Yedekte yinelenen anahtar sözcük kaydı var.');
    }
    final sayac = _tamsayi(r, 'hits', t);
    if (sayac < 0) {
      throw const YedekHatasi('Yedekte eksi sayaçlı anahtar sözcük var.');
    }
    if (sayac > _enBuyukSayac) {
      throw const YedekHatasi('Yedekte sayacı çok büyük anahtar sözcük var.');
    }
  }

  final ayarlar = _liste(kok, 'settings');
  final ayarAnahtarlari = <String>{};
  for (final r in ayarlar) {
    const t = 'settings';
    if (!ayarAnahtarlari.add(_yazi(r, 'key', t))) {
      throw const YedekHatasi('Yedekte yinelenen ayar var.');
    }
    _yazi(r, 'value', t);
  }

  return Yedek(
    schemaVersion: surum,
    olusturuldu: olusturuldu,
    categories: kategoriler,
    transactions: islemler,
    budgets: limitler,
    keywordHits: sozcukler,
    settings: ayarlar,
  );
}

/// Mevcut veriyi siler, yedeği yazar; hepsi tek transaction'da, hata olursa eski veri durur.
/// [kopyaYolu] verilirse uygulamadan önce veritabanının bir kopyası oraya alınır (üstüne yazar);
/// kopya alınamazsa geri yükleme hiç başlamaz.
Future<void> yedegiUygula(AppDatabase db, Yedek y, {String? kopyaYolu}) async {
  if (kopyaYolu != null) {
    try {
      final f = File(kopyaYolu);
      if (f.existsSync()) f.deleteSync();
      // VACUUM INTO tutarlı bir anlık görüntü verir; transaction dışında çalışmalı.
      await db.customStatement('VACUUM INTO ?', [kopyaYolu]);
    } catch (_) {
      throw const YedekHatasi(
        'Mevcut verilerin kopyası alınamadı, geri yükleme yapılmadı.',
      );
    }
  }
  await db.transaction(() async {
    await db.delete(db.transactions).go();
    await db.delete(db.budgets).go();
    await db.delete(db.keywordHits).go();
    await db.delete(db.categories).go();
    await (db.delete(
      db.settings,
    )..where((s) => s.key.like('update\\_%', escapeChar: '\\').not())).go();
    await db.batch((b) {
      b.insertAll(db.categories, [
        for (final r in y.categories) Category.fromJson(r),
      ]);
      b.insertAll(db.transactions, [
        for (final r in y.transactions) Transaction.fromJson(r),
      ]);
      b.insertAll(db.budgets, [for (final r in y.budgets) Budget.fromJson(r)]);
      b.insertAll(db.keywordHits, [
        for (final r in y.keywordHits) KeywordHit.fromJson(r),
      ]);
      b.insertAll(db.settings, [
        for (final r in y.settings)
          if (!(r['key']! as String).startsWith(_cihazaOzelOnek))
            Setting.fromJson(r),
      ]);
    });
  });
}

/// Son yedek (yoksa ilk işlem) üzerinden 30 günden fazla geçtiyse ve ertelenmemişse true.
/// [bugun] ve [ertelemeGunu] yyyymmdd; [sonYedekMs] ve [ilkIslemMs] epoch ms.
bool yedekHatirlatilsin({
  required int islemSayisi,
  required int bugun,
  int? sonYedekMs,
  int? ilkIslemMs,
  int? ertelemeGunu,
}) {
  if (islemSayisi < 1) return false;
  if (ertelemeGunu != null && bugun < ertelemeGunu) return false;
  final ref = sonYedekMs ?? ilkIslemMs;
  if (ref == null) return false;
  final refGun = gunAnahtari(DateTime.fromMillisecondsSinceEpoch(ref));
  return gunFarki(refGun, bugun) > 30;
}

bool _gecerliGun(int g) {
  final y = g ~/ 10000, a = g ~/ 100 % 100, d = g % 100;
  return y >= 1900 &&
      y <= 2999 &&
      a >= 1 &&
      a <= 12 &&
      d >= 1 &&
      d <= ayGunSayisi(y, a);
}

List<Satir> _liste(Map<String, Object?> kok, String ad) {
  final v = kok[ad];
  if (v is! List) throw YedekHatasi('Yedekte "$ad" bölümü eksik.');
  return [
    for (final r in v)
      r is Map<String, Object?>
          ? r
          : throw YedekHatasi('Yedekte "$ad" bölümü bozuk.'),
  ];
}

int _tamsayi(Map<String, Object?> r, String alan, String bolum) {
  final v = r[alan];
  if (v is int) return v;
  throw YedekHatasi('Yedekte $bolum.$alan alanı eksik ya da tam sayı değil.');
}

int _kimlik(Map<String, Object?> r, String alan, String bolum) {
  final v = _tamsayi(r, alan, bolum);
  if (v < 1 || v > _enBuyukId) {
    throw YedekHatasi('Yedekte $bolum.$alan numarası geçersiz.');
  }
  return v;
}

String _yazi(Map<String, Object?> r, String alan, String bolum) {
  final v = r[alan];
  if (v is String) return v;
  throw YedekHatasi('Yedekte $bolum.$alan alanı eksik ya da metin değil.');
}

bool _mantiksal(Map<String, Object?> r, String alan, String bolum) {
  final v = r[alan];
  if (v is bool) return v;
  throw YedekHatasi('Yedekte $bolum.$alan alanı eksik ya da evet/hayır değil.');
}
