/// Arayüz metinleri (Türkçe).
const uygulamaAdi = 'Bütçe Takip';
const sekmeOzet = 'Özet';
const sekmeIslemler = 'İşlemler';
const sekmeAyarlar = 'Ayarlar';
const veriYuklenemedi =
    'Veriler yüklenemedi. Uygulamayı kapatıp yeniden açmayı dene.';

// Hızlı giriş
const islemEkleEtiket = 'İşlem ekle';
const islemDuzenleBaslik = 'İşlemi düzenle';
const tutarEtiket = 'Tutar';
const tumuEtiket = 'Tümü';
const ayrintiEtiket = 'Ayrıntı';
const notEtiket = 'Not';
const tarihEtiket = 'Tarih';
const giderEtiket = 'Gider';
const gelirEtiket = 'Gelir';
const kaydetEtiket = 'Kaydet';
const geriTusuEtiket = 'Son rakamı sil';
const onceTutarYaz = 'Önce tutarı gir';
String rakamEtiket(int r) => '$r rakamı';

// İşlemler
const oncekiAyEtiket = 'Önceki ay';
const sonrakiAyEtiket = 'Sonraki ay';
const bosAyMetni = 'Bu ay henüz işlem yok. + ile ekleyebilirsin.';
const islemSilindi = 'İşlem silindi';
const geriAlEtiket = 'Geri al';
const silEtiket = 'Sil';
const kaydedilemedi = 'Kaydedilemedi. Tekrar dene.';

// Kategoriler ve limitler
const kategorilerBaslik = 'Kategoriler ve limitler';
const kategorilerAltyazi = 'Ekle, yeniden adlandır, arşivle, aylık limit koy';
const giderKategorileri = 'Gider kategorileri';
const gelirKategorileri = 'Gelir kategorileri';
const giderKategorisiEkle = 'Gider kategorisi ekle';
const gelirKategorisiEkle = 'Gelir kategorisi ekle';
const kategoriDuzenleBaslik = 'Kategoriyi düzenle';
const adEtiket = 'Ad';
const simgeEtiket = 'Simge';
const vazgecEtiket = 'Vazgeç';
const arsivleEtiket = 'Arşivle';
const arsivdenCikarEtiket = 'Arşivden çıkar';
const arsivliEtiket = 'Arşivli';
const limitEtiket = 'Aylık limit';
const limitYok = 'Limit yok';
const limitKaldirEtiket = 'Limiti kaldır';
const adBos = 'Kategori adı boş olamaz.';
const adAyni = 'Bu adda bir kategori zaten var.';
const adAyrilmis = 'Bu ad ayrılmış.';
String limitSatiri(String tutar) => 'Aylık limit: $tutar';
String limitBaslik(String ad) => '$ad: aylık limit';
String simgeSecEtiket(int i) => 'Simge ${i + 1}';

// Özet
const buAyHarcanan = 'Bu ay harcanan';
const buAyGelir = 'Bu ay gelir';
const kalanEtiket = 'Kalan';
const kalanAciklama = 'Limitli kategorilerde';
const limitCagrisi =
    'Kategorilere aylık limit koyarsan burada ne kadarının kaldığını görürsün.';
const limitEkleEtiket = 'Limit ekle';
const limitlerBaslik = 'Kategori limitleri';
const limitsizBaslik = 'Limitsiz harcamalar';
String limitDurumMetni(String ad, int yuzde) =>
    yuzde >= 100 ? '$ad bütçesi doldu (%$yuzde)' : '$ad bütçesi %$yuzde doldu';
String yuzdeEtiket(int yuzde) => '%$yuzde';

// Toplam bakiye
const toplamBakiyeEtiket = 'Toplam bakiye';
const toplamBakiyeAciklama =
    'Tüm gelirler eksi tüm giderler, başlangıç bakiyesiyle';
const bankaBakiyeBaslik = 'Bankadaki bakiyen kaç?';
const bakiyeArtiEtiket = 'Artı';
const bakiyeEksiEtiket = 'Eksi';
const bakiyeSifirlaEtiket = 'Sıfırla';

// Akıllı özellikler
const oneriliEtiket = 'önerilen';
String cipSemantigi(String ad, bool onerilen) =>
    onerilen ? '$ad, $oneriliEtiket' : ad;
const tekrarBaslik = 'Tekrarlayan olabilir';
const tekrarEkleEtiket = 'Ekle';
const tekrarGosterme = 'Gösterme';
const tekrarIslemiBaslik = 'Tekrarlayan işlemi ekle';
String tekrarBeklenen(String tarih) => 'Beklenen: $tarih';
const tahminBaslik = 'Ay sonu tahmini';
const tahminYetersiz = 'Henüz yeterli veri yok';
String tahminMetni(String tutar) =>
    'Bu hızla ay sonunda yaklaşık $tutar harcarsın';
String tahminLimitFarki(String fark) =>
    'Aylık limit toplamının $fark üzerinde.';
const arsivHatasi = 'Arşiv durumu değişmedi. Tekrar dene.';
const bildirimAnahtariBaslik = 'Bütçe bildirimleri';
const bildirimAnahtariAltyazi = 'Kategori limiti %80 ve %100 dolunca haber ver';
String uyariMetni(String ad, int esik) => esik >= 100
    ? '$ad bütçesi doldu (%$esik)'
    : "$ad bütçesinin %$esik'i doldu";

// Yedek
const yedekKaydetBaslik = 'Dosyaya kaydet';
const yedekKaydetAltyazi = 'Yedeği telefonda seçtiğin bir konuma kaydet';
const yedekPaylasBaslik = 'Paylaş';
const yedekPaylasAltyazi = 'Yedeği başka bir uygulamayla paylaş';
const geriYukleBaslik = 'Geri yükle';
const geriYukleAltyazi = 'Bir yedek dosyasından verileri geri getir';
const yedekHatirlatmaMetni =
    'Verilerin yalnız bu telefonda. Yedek almak ister misin?';
const yedekSonraEtiket = 'Sonra';
const yedekOkunamadi = 'Yedek dosyası okunamadı ya da bozuk.';
const yedekHatasi = 'Yedek alınamadı. Tekrar dene.';
const dosyaOkunamadi = 'Dosya okunamadı. Başka bir dosya seçmeyi dene.';
const geriYuklemeBaslik = 'Geri yüklensin mi?';
const geriYukleOnayEtiket = 'Geri yükle';
String yedekOzeti(int islem, int kategori, String tarih) =>
    'Bu yedekte $islem işlem, $kategori kategori var, tarihi $tarih. '
    'Mevcut verilerin yerine geçecek.';
const geriYuklendi = 'Yedek geri yüklendi.';
const geriYuklemeBasarisiz =
    'Geri yükleme yapılamadı, mevcut verilerin değişmedi.';

// Kategori silme.
String kategoriSilBaslik(String ad) => '$ad silinsin mi?';
String kategoriSilGovde(int islemSayisi, String hedefAd) => islemSayisi == 0
    ? 'Bu geri alınamaz.'
    : "İçindeki $islemSayisi işlem $hedefAd'e taşınacak. Bu geri alınamaz.";
const geriAlHatasi = 'İşlem geri alınamadı. Tekrar dene.';
const kategoriSilHatasi = 'Kategori silinemedi. Tekrar dene.';
String kategoriSilAdCakismasi(String hedefAd, bool gelir) {
  final diger = gelir ? 'gider' : 'gelir'; // adı kullanan karşı tür
  return 'Silme hedefi "$hedefAd" adı $diger kategorilerinde kullanılıyor. '
      "Önce $diger kategorilerindeki $hedefAd'in adını değiştir.";
}

// Güncellemeler.
const guncellemeBaslik = 'Güncellemeler';
const guncellemeDenetle = 'Güncellemeleri denetle';
const guncellemeDenetleAciklama =
    "Günde en çok bir kez GitHub'a sorar. Kapalıyken internet kullanılmaz.";
const guncellemeYalnizWifi = "Yalnız Wi-Fi'da indir";
const guncellemeSimdiDenetle = 'Şimdi denetle';
const guncellemeDenetleniyor = 'Denetleniyor...';
const guncellemeGuncel = 'Uygulama güncel.';
const guncellemeHic = 'Henüz denetlenmedi.';
String guncellemeHazir(String s) => 'Yeni sürüm hazır: $s';
const guncellemeIndirKur = 'İndir ve kur';
const guncellemeIndiriliyor = 'İndiriliyor ve doğrulanıyor...';
const guncellemeKurulumAcildi =
    "Doğrulandı. Android'in kurulum penceresinde onayla.";

/// PackageInstaller durum kodu (başarı olan 0 hiç gelmez).
String guncellemeKurulumSonucu(int durum) => switch (durum) {
  3 => 'Kurulum iptal edildi.',
  6 => 'Telefonda yeterli yer yok, kurulmadı.',
  7 => 'Yeni sürümün imzası kurulu uygulamayla uyuşmuyor, kurulmadı.',
  _ => 'Kurulum tamamlanamadı (kod $durum).',
};
const guncellemeIlkBaslik = 'Güncellemeler denetlensin mi?';
const guncellemeIlkGovde =
    "Uygulama günde en çok bir kez GitHub'a bağlanıp yeni sürüm olup "
    'olmadığına bakabilir. Kişisel veri gönderilmez, verilerin telefondan '
    "çıkmaz. İndirme yalnız Wi-Fi'da yapılır. İstersen Ayarlar'dan "
    'değiştirebilirsin.';
const guncellemeIlkHayir = 'Hayır';
const guncellemeIlkEvet = 'Evet, denetle';
const guncellemeMobilBaslik = 'Mobil veriyle indirilsin mi?';
const guncellemeMobilGovde =
    "Şu an Wi-Fi'da değilsin. Güncelleme dosyası büyük olabilir.";
const guncellemeMobilEvet = 'Mobil veriyle indir';
String guncellemeHata(String kod) => switch (kod) {
  'ag_yok' => 'İnternet bağlantısı yok.',
  'wifi_gerek' => "İndirme Wi-Fi'ı bekliyor.",
  'izin_yok' => 'Bu uygulamaya kurulum izni ver, sonra geri dönüp tekrar dene.',
  'depo_dolu' => 'Telefonda yeterli yer yok, güncelleme indirilemedi.',
  'ozet_uyusmuyor' ||
  'ozet_bulunamadi' => 'İndirilen dosya doğrulanamadı, kurulmadı.',
  'ag_hatasi' || 'limit' => 'İndirme tamamlanamadı, sonra tekrar dene.',
  _ => 'Güncelleme yapılamadı ($kod).',
};
