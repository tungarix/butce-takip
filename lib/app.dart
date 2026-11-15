import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/ayarlar/ayarlar_ekrani.dart';
import 'features/islemler/islemler_ekrani.dart';
import 'features/ozet/ozet_ekrani.dart';
import 'ui_metin.dart';

ThemeData _tema(Brightness b) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: b),
  useMaterial3: true,
);

class ButceTakipApp extends StatelessWidget {
  const ButceTakipApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: uygulamaAdi,
    theme: _tema(Brightness.light),
    darkTheme: _tema(Brightness.dark),
    themeMode: ThemeMode.system,
    locale: const Locale('tr', 'TR'),
    supportedLocales: const [Locale('tr', 'TR')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const Kabuk(),
  );
}

class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sekme = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _sekme,
      children: const [OzetEkrani(), IslemlerEkrani(), AyarlarEkrani()],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _sekme,
      onDestinationSelected: (i) => setState(() => _sekme = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.pie_chart_outline),
          selectedIcon: Icon(Icons.pie_chart),
          label: sekmeOzet,
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: sekmeIslemler,
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: sekmeAyarlar,
        ),
      ],
    ),
  );
}
