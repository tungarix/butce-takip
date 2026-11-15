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
