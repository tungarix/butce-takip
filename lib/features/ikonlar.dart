import 'package:flutter/material.dart';

// categories.icon bu listenin dizinidir; yeni simge yalnız sona eklenir.
const _kategoriSimgeleri = <IconData>[
  Icons.shopping_cart, // 0 Market
  Icons.directions_bus, // 1 Ulaşım
  Icons.bolt, // 2 Fatura
  Icons.home, // 3 Kira
  Icons.restaurant, // 4 Yemek
  Icons.medical_services, // 5 Sağlık
  Icons.movie, // 6 Eğlence
  Icons.subscriptions, // 7 Abonelik
  Icons.category, // 8 Diğer
  Icons.payments, // 9 Maaş
];

IconData kategoriSimgesi(int dizin) =>
    dizin >= 0 && dizin < _kategoriSimgeleri.length
    ? _kategoriSimgeleri[dizin]
    : Icons.category;
