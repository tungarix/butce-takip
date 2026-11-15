// İlk kurulumda yazılan hazır kategoriler ve anahtar kelimeler.
// Anahtar kelimeler notNormalize çıktısıyla birebir aynıdır (test kilitler).

typedef TohumKategori = ({String ad, int simge, bool gelir});

const tohumKategoriler = <TohumKategori>[
  (ad: 'Market', simge: 0, gelir: false),
  (ad: 'Ulaşım', simge: 1, gelir: false),
  (ad: 'Fatura', simge: 2, gelir: false),
  (ad: 'Kira', simge: 3, gelir: false),
  (ad: 'Yemek', simge: 4, gelir: false),
  (ad: 'Sağlık', simge: 5, gelir: false),
  (ad: 'Eğlence', simge: 6, gelir: false),
  (ad: 'Abonelik', simge: 7, gelir: false),
  (ad: 'Diğer', simge: 8, gelir: false),
  (ad: 'Maaş', simge: 9, gelir: true),
];

/// Kategori adı -> anahtar kelimeler.
const tohumAnahtarKelimeler = <String, List<String>>{
  'Market': [
    'migros',
    'bim',
    'a101',
    'sok',
    'carrefour',
    'manav',
    'kasap',
    'bakkal',
  ],
  'Ulaşım': [
    'shell',
    'opet',
    'benzin',
    'otobus',
    'taksi',
    'metro',
    'istanbulkart',
  ],
  'Fatura': ['elektrik', 'dogalgaz', 'internet', 'fatura'],
  'Kira': ['kira', 'aidat'],
  'Yemek': ['restoran', 'kafe', 'cafe', 'lokanta', 'yemeksepeti', 'doner'],
  'Sağlık': ['eczane', 'doktor', 'hastane'],
  'Eğlence': ['sinema', 'konser', 'steam'],
  'Abonelik': ['netflix', 'spotify', 'youtube', 'exxen', 'disney'],
  'Maaş': ['maas'],
};
