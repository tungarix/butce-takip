# Bütçe Takip (Smart Budget Tracker): Android planı

Durum: plan, kod yok (2026-11-15). Ad geçici.

## Sabit kararlar

- Flutter, `habit-tracker-mobil` ile aynı yığın: drift 2.34 + drift_flutter, flutter_riverpod 3, intl,
  share_plus, file_picker, flutter_local_notifications. İskelet, `release.yml`, `ci.yml`,
  `guvenlik-kapisi.yml` ve imza ayarı oradan kopyalanır.
- Tamamen çevrimdışı: INTERNET izni yok, hesap yok, sunucu yok. Dağıtım GitHub Release'te imzalı APK.
- Arayüz Türkçe, para birimi TL, tema sistemi izler.
- "Akıllı" kısım cihaz içinde ve kural tabanlı. Model, bulut, banka bağlantısı yok.

## v1 kapsamı

1. Gelir/gider ekleme, düzenleme, silme (silmede "Geri al").
2. Kategoriler: 10 hazır, eklenir, yeniden adlandırılır, arşivlenir (silinmez).
3. Kategori başına aylık limit ve ilerleme çubuğu.
4. Özet: bu ay harcanan, kalan, ay sonu tahmini.
5. Akıllı: kategori önerisi, tekrarlayan işlem önerisi, ay sonu tahmini, bütçe aşım bildirimi.
6. JSON yedek ve geri yükleme.

### Bilinçli olarak dışarıda

| Ne | Neden | Ne zaman |
|---|---|---|
| Banka SMS/bildirim okuma | Hassas izin, her bankanın biçimi ayrı, sürekli bakım | v2: SMS metnini "Paylaş" ile uygulamaya gönderme (izin istemez) |
| Tekrarlayanı otomatik kaydetme | Kural tablosu, ay sonu ve çift kayıt kenar durumları | v1.1 |
| Toplam (kategorisiz) limit, aya özel limit | v1'de kategori limitlerinin toplamı yeter | v1.1 |
| Ana ekran widget'ı, pasta grafik, arama, CSV | Çekirdek iş değil | v1.1 |
| Maaş gününe göre ay başlangıcı | Ay anahtarı tek fonksiyonda durur, sonra eklenir | v1.1 |
| Çoklu hesap, döviz, taksit, kilit, senkron | Kapsam dışı | belirsiz |

## Ekranlar

`NavigationBar` ile 3 sekme, `Navigator.push`, router paketi yok.

- **Özet**: ay seçici, "Bu ay kalan", tahmin kartı, kategori çubukları, "tekrarlayan olabilir" kartı.
- **İşlemler**: güne göre gruplu liste, kaydırarak sil + geri al, dokununca düzenle.
- **Ayarlar**: kategoriler ve limitler, yedekle / geri yükle, bildirim aç/kapat.
- **Hızlı giriş** (alt sayfa, her sekmede `+`): tuş takımı açık gelir, altında en sık 6 kategori çipi.
  Çipe dokunmak seçer ve kaydeder. Not, tarih, gelir anahtarı katlı durur. Hedef: 5 saniyenin altı.

Dil suçlayıcı olmaz ("Market bütçesinin %90'ı doldu"), seri/streak yok, boş gün ceza değil.

## Veri modeli (drift, şema sürümü 1)

- **categories**: `id`, `name` (unique), `icon` (int), `isIncome`, `sortOrder`, `archived`
- **transactions**: `id`, `amountKurus` (int, `CHECK > 0`), `isIncome`, `categoryId` (FK), `note`,
  `noteNorm`, `day` (int `yyyymmdd`, yerel takvim günü), `createdAt` (epoch ms).
  İndeks: `(day)`, `(categoryId, day)`, `(noteNorm)`
- **budgets**: `categoryId` (PK, FK), `monthlyLimitKurus`
- **keyword_hits**: `keyword`, `categoryId`, `hits` (PK ikili). Tohum sözlük de buraya yazılır.
- **settings**: `key`, `value` (bildirim tercihi, `alert_<catId>_<yyyymm>_<80|100>`, reddedilen öneriler)

Kurallar:
- Para her yerde kuruş `int`, `double` yok. Yüzde `spent * 100 ~/ limit`.
- Gün UTC'ye çevrilmez; `day` yerel tarihten üretilir. Ay anahtarı `core/tarih.dart` içinde tek fonksiyon.
- `PRAGMA foreign_keys = ON` `beforeOpen`'da. Tohum veri `onCreate`'te.
- İlk sürümden itibaren `drift_schemas/` dökümü ve göç testi.

## Akıllı özellikler

**Normalize** (`akilli/normalize.dart`): Dart'ın `toLowerCase`'i yerel ayar almaz. Önce `İ→i`, `I→ı`
elle, sonra küçült, sonra `ışğüöç → isguoc`, rakam ve noktalama at, sözcüklere böl.

**Kategori önerisi**: notun her sözcüğü `keyword_hits`'te aranır, kategori başına `hits` toplanır,
en yüksek olan çiplerin başına gelir. Sessiz atama yok. Kaydederken seçilen kategori için her
sözcüğe `hits + 1`. Tohum: migros, bim, a101, şok → Market; shell, opet → Ulaşım; netflix, spotify →
Abonelik; eczane → Sağlık vb.

**Tekrarlayan önerisi**: Özet açılınca son 120 günün giderleri `noteNorm`'a göre gruplanır
(not boşsa kategori + tutar). En az 3 kayıt, ardışık gün farklarının medyanı 28-32 ya da 6-8,
tutar medyandan en çok %10 sapıyorsa grup tekrarlayandır. Beklenen güne 3 gün kala kart çıkar;
"Ekle" önceden doldurulmuş girişi açar, "Gösterme" kalıcı reddeder.

**Ay sonu tahmini**: `buAyHarcanan + kalanGün × (son 14 günün gideri / 14)`, artı henüz
gerçekleşmemiş tekrarlayanlar (çift sayılmasın diye 14 günlük ortalamadan düşülür). Ayın ilk 5
gününde "Henüz yeterli veri yok".

**Aşım bildirimi**: işlem kaydedilince kategori toplamı %80 ve %100 eşiğini geçtiyse yerel bildirim,
ay başına eşik başına bir kez. Zamanlanmış iş yok. Bildirim izni reddedilirse uyarı Özet'te görünür.

## Klasör yapısı

```
lib/
  main.dart, app.dart, ui_metin.dart
  core/       para.dart, tarih.dart
  data/       database/ (tables, database), providers.dart, yedek.dart
  akilli/     normalize.dart, kategori_onerici.dart, tekrar_tespit.dart, tahmin.dart, uyari.dart
  features/   ozet/, islemler/, ayarlar/, hizli_giris/
  platform/   bildirimler.dart
test/         core, akilli, data (bellek içi drift), göç, yedek, hızlı giriş widget testi
drift_schemas/
.github/workflows/
```

`core/` ve `akilli/` saf Dart: arayüz ve veritabanı içe aktarmaz.

## Aşamalar

| # | İş | Bitti ölçütü |
|---|---|---|
| 1 | İskelet: proje, tema, drift şeması, tohum, `para.dart`, `tarih.dart` | Emülatörde açılıyor; para ve tarih testleri yeşil |
| 2 | Hızlı giriş + işlem listesi | Ekle, düzenle, sil, geri al; kapat-aç sonrası veri duruyor; giriş 5 sn altı |
| 3 | Kategoriler, limitler, Özet | Elle girilen veriyle çubuk yüzdeleri doğru |
| 4 | Akıllı: normalize, öneri, tahmin, aşım bildirimi, en son tekrar tespiti | Her birinin birim testi yeşil; emülatörde bildirim geliyor |
| 5 | Yedek / geri yükle | Dışa aktar, veriyi sil, içe aktar: toplamlar birebir aynı; bozuk dosya hiçbir şeyi değiştirmiyor |
| 6 | Yayın: imzalı APK, Actions, v0.1.0 taslak release | Release APK'sı gerçek telefona kuruluyor, kısayoldan açılıp işlem ekleniyor |

## Test

- **Para**: sağdan dolan girişin kuruşa çevrimi, biçimleme (`1.234,50 ₺`), 0, 1 kuruş, üst sınır.
- **Tarih**: ay sınırları 28/29/30/31, yıl geçişi, gece 23:59 ve 00:01 girişleri.
- **Normalize**: `İ/I/ı/i` ve tüm Türkçe harfler.
- **Akıllı**: sabit tarihlerle öneri, tespit (2 kayıt önermez, 3 kayıt önerir), tahmin.
- **Veri**: bellek içi drift ile ay toplamı ve eşik sorguları; `sum(kategori) == genel toplam`.
- **Göç**: `drift_dev schema dump` + `verifyMigrations`.
- **Yedek**: gidiş-dönüş eşitliği; eksik alan ve daha yeni `schemaVersion` reddedilir.
- **Elle**: her aşama sonunda emülatörde, yayından önce gerçek cihazda.

## Riskler ve açık noktalar

- **Veri tek kopya**: uygulama silinirse gider. 30 günde bir Özet'te "yedek al" hatırlatması.
  Geri yüklemeden önce mevcut `.sqlite` kopyalanır.
- **`allowBackup`**: Android otomatik yedeğinin yan yüklenen APK'da nasıl davrandığı bilinmiyor.
  Aşama 6'da gerçek cihazda denenip karar verilecek.
- **İmza anahtarı**: kaybolursa güncelleme zinciri kopar (Dosya Dolabı'nda yaşandı). İlk günden
  CI secret + ayrı yedek.
- **Derleme**: flutter_local_notifications için core library desugaring ve R8 kuralları
  `habit-tracker-mobil/android/app/build.gradle.kts`'ten alınır; `tr_TR` için
  `initializeDateFormatting` çağrılır.
- **Az veride tahmin yanıltır**: ilk 5 gün gösterilmez, sonrasında "bu hızla" diye sunulur.

## Açık kararlar

1. Uygulamanın adı ve GitHub repo adı.
2. Kullanıcı sen misin, başkası mı? Başkasıysa banka SMS'i beklentisi baştan konuşulmalı.
3. Maaş gününe göre ay başlangıcı v1'e girsin mi (şu an v1.1)?
