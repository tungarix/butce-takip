/// Arayüz metinleri (Türkçe).
const uygulamaAdi = 'Bütçe Takip';
const sekmeOzet = 'Özet';
const sekmeIslemler = 'İşlemler';
const sekmeAyarlar = 'Ayarlar';
const veriYuklenemedi = 'Veriler yüklenemedi. Uygulamayı kapatıp yeniden açmayı dene.';

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
const limitCagrisi = 'Kategorilere aylık limit koyarsan burada ne kadarının kaldığını görürsün.';
const limitEkleEtiket = 'Limit ekle';
const limitlerBaslik = 'Kategori limitleri';
const limitsizBaslik = 'Limitsiz harcamalar';
String limitDurumMetni(String ad, int yuzde) =>
    yuzde >= 100 ? '$ad bütçesi doldu (%$yuzde)' : '$ad bütçesi %$yuzde doldu';
String yuzdeEtiket(int yuzde) => '%$yuzde';
