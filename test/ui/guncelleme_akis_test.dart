// The user-facing update flow: Wi-Fi rule, install permission, digest re-check
// before the installer, and the Settings section / first-launch consent wiring.
// No real network or installer.
import 'dart:io';
import 'dart:typed_data';

import 'package:butce_takip/data/database/database.dart';
import 'package:butce_takip/data/providers.dart';
import 'package:butce_takip/features/ayarlar/guncelleme_bolumu.dart';
import 'package:butce_takip/features/ayarlar/ayarlar_ekrani.dart';
import 'package:butce_takip/platform/guncelleme/ag.dart';
import 'package:butce_takip/platform/guncelleme/akis.dart';
import 'package:butce_takip/platform/guncelleme/ayarlar.dart';
import 'package:butce_takip/platform/guncelleme/guncelleyici.dart';
import 'package:butce_takip/platform/guncelleme/saf.dart';
import 'package:butce_takip/platform/guncelleme/sha256.dart';
import 'package:butce_takip/platform/kopru.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

const _depo = 'tungarix/butce-takip';
final _apk = Uint8List.fromList(List.generate(2000, (i) => (i * 7 + 3) % 256));
String _hash(List<int> b) => onaltilik((Sha256Akis()..ekle(b)).bitir());

final _yayin = Yayin(
  surum: '0.4.0',
  apkUrl:
      'https://github.com/$_depo/releases/download/v0.4.0/Butce-Takip-0.4.0.apk',
  apkBoyut: _apk.length,
  ozetUrl: 'https://github.com/$_depo/releases/download/v0.4.0/SHA256SUMS.txt',
  sayfaUrl: 'https://github.com/$_depo/releases/tag/v0.4.0',
);

class _SahteAg extends Ag {
  _SahteAg({this.sonuc = 'yok'}) : super(surum: '0.0.1');
  final String sonuc;
  int sorgu = 0;

  @override
  Future<SonYayinSonucu> sonYayin([String? etag]) async {
    sorgu++;
    return sonuc == 'yeni' ? ('yeni', _yayin, 'e1') : ('yok', null, null);
  }

  @override
  Future<String> metinIndir(String url) async =>
      '${_hash(_apk)}  ${_yayin.apkAdi}\n';

  @override
  Future<String> indir(
    String url,
    File hedef,
    int beklenenBoyut, {
    void Function(int)? ilerleme,
  }) async {
    await hedef.writeAsBytes(_apk);
    return _hash(_apk);
  }
}

/// Writes different bytes than the digest it reports: the download check
/// passes, so only the pre-install re-hash can catch it.
class _DegisenAg extends _SahteAg {
  @override
  Future<String> indir(
    String url,
    File hedef,
    int beklenenBoyut, {
    void Function(int)? ilerleme,
  }) async {
    await hedef.writeAsBytes([..._apk]..[0] ^= 0xff);
    return _hash(_apk);
  }
}

class _SahteKopru implements Kopru {
  _SahteKopru({this.tur = 'wifi', this.izin = true});
  String tur;
  bool izin;
  int izinAcildi = 0;
  void Function(int, String?)? sonuc;
  final kurulan = <(String, String)>[];

  @override
  Future<String> agTuru() async => tur;
  @override
  Future<bool> kurulumIzniVar() async => izin;
  @override
  Future<void> kurulumIzniAc() async => izinAcildi++;
  @override
  Future<void> apkKur(String yol, String ozet) async =>
      kurulan.add((yol, ozet));
  @override
  void kurulumSonucuDinle(void Function(int, String?) f) => sonuc = f;
}

Future<String?> _kos(
  Guncelleyici g,
  _SahteKopru k, {
  bool mobilEvet = false,
}) async {
  try {
    await guncellemeKur(g, k, _yayin, mobilOnayi: () async => mobilEvet);
    return null;
  } on GuncellemeHatasi catch (e) {
    return e.kod;
  }
}

Future<void> kisaBekle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The settings list is lazy: scroll the target into the built range first.
Future<void> dokun(WidgetTester tester, String metin) async {
  await tester.scrollUntilVisible(find.text(metin), 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(find.text(metin));
  await tester.pump();
  await tester.tap(find.text(metin));
  await kisaBekle(tester);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('guncelleme_akis'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<Guncelleyici> yap({Ag? ag}) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return Guncelleyici(
      ayarlar: await GuncellemeAyarlari.yukle(db),
      klasor: tmp,
      surum: '0.0.1',
      ag: ag ?? _SahteAg(),
    );
  }

  group('guncellemeKur', () {
    test('Wi-Fi + permission: installer gets the verified digest', () async {
      final k = _SahteKopru();
      expect(await _kos(await yap(), k), isNull);
      expect(k.kurulan.single.$2, _hash(_apk));
    });

    test('metered network, Wi-Fi only: declined consent downloads nothing',
        () async {
      final k = _SahteKopru(tur: 'mobil');
      expect(await _kos(await yap(), k), 'wifi_gerek');
      expect(k.kurulan, isEmpty);
      expect(tmp.listSync(), isEmpty);
    });

    test('metered network + consent proceeds; offline never does', () async {
      final k = _SahteKopru(tur: 'mobil');
      expect(await _kos(await yap(), k, mobilEvet: true), isNull);
      expect(await _kos(await yap(), _SahteKopru(tur: 'yok')), 'ag_yok');
    });

    test('no install permission: opens system screen, downloads nothing',
        () async {
      final k = _SahteKopru(izin: false);
      expect(await _kos(await yap(), k), 'izin_yok');
      expect(k.izinAcildi, 1);
      expect(k.kurulan, isEmpty);
      expect(tmp.listSync(), isEmpty);
    });

    test('file swapped after the download check is rejected and deleted',
        () async {
      final k = _SahteKopru();
      expect(await _kos(await yap(ag: _DegisenAg()), k), 'ozet_uyusmuyor');
      expect(k.kurulan, isEmpty);
      expect(tmp.listSync(), isEmpty);
    });
  });

  group('arayüz', () {
    Future<(_SahteKopru, Guncelleyici)> kur(
      WidgetTester tester,
      Widget ev, {
      Ag? ag,
    }) async {
      telefonBoyutu(tester);
      final db = await bellekDb(tester);
      final k = _SahteKopru();
      final g = Guncelleyici(
        ayarlar: await GuncellemeAyarlari.yukle(db),
        klasor: tmp,
        surum: '0.0.1',
        ag: ag ?? _SahteAg(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            kopruProvider.overrideWithValue(k),
            guncelleyiciProvider.overrideWith((ref) async => g),
          ],
          child: MaterialApp(home: ev),
        ),
      );
      await kisaBekle(tester);
      return (k, g);
    }

    uiTest('settings: toggles persist, "check now" offers the update',
        (tester) async {
      final (_, g) = await kur(
        tester,
        const AyarlarEkrani(),
        ag: _SahteAg(sonuc: 'yeni'),
      );
      expect(g.denetim, isNull);
      await dokun(tester, guncellemeDenetle);
      expect(g.denetim, isTrue);
      await dokun(tester, guncellemeYalnizWifi);
      expect(g.ayarlar.yalnizWifi, isFalse);
      expect(find.text(guncellemeIndirKur), findsNothing);
      await dokun(tester, guncellemeSimdiDenetle);
      expect(find.text(guncellemeHazir('0.4.0')), findsOneWidget);
      expect(find.text(guncellemeIndirKur), findsOneWidget);
    });

    uiTest('"download and install" hands the verified APK to the installer',
        (tester) async {
      final (k, _) = await kur(
        tester,
        const AyarlarEkrani(),
        ag: _SahteAg(sonuc: 'yeni'),
      );
      await dokun(tester, guncellemeSimdiDenetle);
      expect(find.text(guncellemeIndirKur), findsOneWidget);
      await tester.ensureVisible(find.text(guncellemeIndirKur));
      await tester.pump();
      await tester.tap(find.text(guncellemeIndirKur));
      // Real file I/O: give it wall-clock time outside the fake-async zone.
      for (var i = 0; i < 20 && k.kurulan.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await kisaBekle(tester);
      expect(k.kurulan.length, 1);
      expect(find.text(guncellemeKurulumAcildi), findsOneWidget);
    });

    uiTest('installer failure replaces the "install dialog opened" line',
        (tester) async {
      final (k, _) = await kur(
        tester,
        const AyarlarEkrani(),
        ag: _SahteAg(sonuc: 'yeni'),
      );
      await dokun(tester, guncellemeSimdiDenetle);
      await tester.ensureVisible(find.text(guncellemeIndirKur));
      await tester.pump();
      await tester.tap(find.text(guncellemeIndirKur));
      for (var i = 0; i < 20 && k.kurulan.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
      await kisaBekle(tester);
      expect(find.text(guncellemeKurulumAcildi), findsOneWidget);
      expect(k.sonuc, isNotNull, reason: 'bölüm kurulum sonucunu dinlemeli');
      k.sonuc!(7, 'INSTALL_FAILED_UPDATE_INCOMPATIBLE');
      await kisaBekle(tester);
      expect(find.text(guncellemeKurulumAcildi), findsNothing);
      expect(find.text(guncellemeKurulumSonucu(7)), findsOneWidget);
    });

    uiTest('first launch: asks once, "No" means no network at all',
        (tester) async {
      final ag = _SahteAg();
      final (_, g) = await kur(
        tester,
        Consumer(
          builder: (c, ref, _) => TextButton(
            onPressed: () => guncellemeIlkAcilis(c, ref),
            child: const Text('ac'),
          ),
        ),
        ag: ag,
      );
      await tester.tap(find.text('ac'));
      await kisaBekle(tester);
      expect(find.text(guncellemeIlkBaslik), findsOneWidget);
      expect(ag.sorgu, 0);
      await tester.tap(find.text(guncellemeIlkHayir));
      await kisaBekle(tester);
      expect(g.denetim, isFalse);
      expect(ag.sorgu, 0);
      await tester.tap(find.text('ac'));
      await kisaBekle(tester);
      expect(find.text(guncellemeIlkBaslik), findsNothing);
    });
  });
}
