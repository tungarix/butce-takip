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
  Icons.school, // 10
  Icons.checkroom, // 11
  Icons.pets, // 12
  Icons.card_giftcard, // 13
  Icons.flight, // 14
  Icons.fitness_center, // 15
  Icons.local_cafe, // 16
  Icons.phone_android, // 17
  Icons.savings, // 18
  Icons.work, // 19
];

const kategoriSimgeSayisi = 20;

IconData kategoriSimgesi(int dizin) =>
    dizin >= 0 && dizin < _kategoriSimgeleri.length
    ? _kategoriSimgeleri[dizin]
    : Icons.category;
