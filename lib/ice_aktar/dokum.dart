// Banka dökümü modeli. Saf Dart: Flutter ve drift içe aktarılmaz.

class DokumSatiri {
  const DokumSatiri({
    required this.gun,
    required this.aciklama,
    required this.tutarKurus,
    required this.gelir,
    this.bakiyeKurus,
  });

  /// yyyymmdd
  final int gun;
  final String aciklama;

  /// Her zaman > 0; yön [gelir] ile belli.
  final int tutarKurus;
  final bool gelir;
  final int? bakiyeKurus;

  @override
  String toString() =>
      'DokumSatiri($gun, $aciklama, ${gelir ? '+' : '-'}$tutarKurus, $bakiyeKurus)';
}

class Dokum {
  const Dokum({
    required this.banka,
    required this.satirlar,
    this.sonBakiyeKurus,
    this.atlanan = 0,
    this.tutarsiz = false,
  });

  final String banka;
  final List<DokumSatiri> satirlar;

  /// En yeni satırın bakiyesi.
  final int? sonBakiyeKurus;

  /// Doğrulamadan geçmeyip atlanan satır sayısı.
  final int atlanan;

  /// Ardışık bakiyeler tutarlarla uyuşmuyorsa true (arayüzde uyarı için).
  final bool tutarsiz;
}

class MetinParcasi {
  const MetinParcasi(this.x, this.y, this.w, this.h, this.t);

  /// Sol-üst köken, PDF noktası.
  final double x, y, w, h;
  final String t;
}

class DokumHatasi implements Exception {
  const DokumHatasi(this.mesaj);
  final String mesaj;

  @override
  String toString() => mesaj;
}
