import 'package:flutter/material.dart';

import '../../ui_metin.dart';
import 'kategoriler_ekrani.dart';

class AyarlarEkrani extends StatelessWidget {
  const AyarlarEkrani({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(sekmeAyarlar)),
    body: ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text(kategorilerBaslik),
          subtitle: const Text(kategorilerAltyazi),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const KategorilerEkrani()),
          ),
        ),
      ],
    ),
  );
}
