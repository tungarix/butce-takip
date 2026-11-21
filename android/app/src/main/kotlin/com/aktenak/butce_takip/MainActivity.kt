package com.aktenak.butce_takip

import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Dart köprüsü (ek paket yok): yalnız uygulama içi güncelleme.
 *  - agTuru: 'wifi' (ücretsiz) | 'mobil' (kotalı) | 'yok',
 *  - kurulumIzniVar / kurulumIzniAc: "bilinmeyen uygulamaları yükle" izni,
 *  - apkKur: uygulamanın önbellek klasöründeki APK'yı PackageInstaller oturumuyla kurar. Yalnız bu paket adlı ve
 *    daha yüksek versionCode'lu APK kabul edilir; son söz Android'in imza denetimidir (başka anahtarla
 *    imzalı APK bunun üstüne kurulamaz).
 *  - kurulumSonucu (Kotlin -> Dart): oturum sonucu.
 * Paylaş hedefi (yalnız application/pdf, ACTION_SEND, content://):
 *  - paylasilanDosya: bekleyen paylaşımın geçici dosya yolunu bir kez döndürür ve temizler; paylaşım 5 MB'ı
 *    aştıysa bir kez 'buyuk' hatası verir.
 *  - paylasimGeldi (Kotlin -> Dart): uygulama açıkken yeni paylaşım geldi.
 */
class MainActivity : FlutterActivity() {
    private var kanal: MethodChannel? = null

    // Paylaşımdan gelip Dart'ın henüz almadığı dosya (yol) ya da boyut hatası.
    private var bekleyenYol: String? = null
    private var bekleyenBuyuk = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        paylasimiAl(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (paylasimiAl(intent)) kanal?.invokeMethod("paylasimGeldi", null)
    }

    /** Paylaşılan PDF'i en çok 5 MB okuyup cacheDir'e yazar; paylaşım niyeti ise true. Kalıcı URI izni alınmaz. */
    private fun paylasimiAl(niyet: Intent?): Boolean {
        if (niyet?.action != Intent.ACTION_SEND || niyet.type != "application/pdf") return false
        // Son kullanılanlardan yeniden açılış eski paylaşımı tekrar getirir; yok say.
        if (niyet.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return false
        @Suppress("DEPRECATION")
        val uri: Uri? = if (Build.VERSION.SDK_INT >= 33) niyet.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else niyet.getParcelableExtra(Intent.EXTRA_STREAM)
        if (uri == null || uri.scheme != "content") return false
        val gecici = File(cacheDir, "paylasilan.tmp")
        try {
            val girdi = contentResolver.openInputStream(uri) ?: return false
            girdi.use { g ->
                gecici.outputStream().use { c ->
                    val tampon = ByteArray(8192)
                    var toplam = 0L
                    while (true) {
                        val n = g.read(tampon)
                        if (n < 0) break
                        toplam += n
                        if (toplam > ENBUYUK_PAYLASIM) throw IOException("buyuk")
                        c.write(tampon, 0, n)
                    }
                }
            }
            val hedef = File(cacheDir, "paylasilan.pdf")
            gecici.copyTo(hedef, overwrite = true)
            gecici.delete()
            bekleyenYol = hedef.path
            bekleyenBuyuk = false
        } catch (e: Exception) {
            gecici.delete()
            bekleyenYol = null
            bekleyenBuyuk = e.message == "buyuk"
            if (!bekleyenBuyuk) return false
        }
        return true
    }

    // Yalnız KENDİ dinleyicimizi kaldır: ikinci bir MainActivity örneği onu değiştirmiş olabilir.
    private var benimDinleyici: ((Int, String?) -> Unit)? = null

    override fun onDestroy() {
        if (KurulumAlici.sonucDinleyici === benimDinleyici) KurulumAlici.sonucDinleyici = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val dinleyici: (Int, String?) -> Unit = { durum, mesaj ->
            runOnUiThread { kanal?.invokeMethod("kurulumSonucu", mapOf("durum" to durum, "mesaj" to mesaj)) }
        }
        benimDinleyici = dinleyici
        KurulumAlici.sonucDinleyici = dinleyici
        kanal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aktenak.butce_takip/kopru").also { k ->
            k.setMethodCallHandler { cagri, sonuc ->
                when (cagri.method) {
                    "agTuru" -> sonuc.success(agTuru())
                    "paylasilanDosya" -> {
                        val yol = bekleyenYol
                        val buyuk = bekleyenBuyuk
                        bekleyenYol = null
                        bekleyenBuyuk = false
                        if (buyuk) sonuc.error("buyuk", "Dosya 5 MB'tan büyük", null) else sonuc.success(yol)
                    }
                    "kurulumIzniVar" -> sonuc.success(Build.VERSION.SDK_INT < 26 || packageManager.canRequestPackageInstalls())
                    "kurulumIzniAc" -> {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        sonuc.success(null)
                    }
                    "apkKur" -> {
                        // Büyük APK'nın kopyası + fsync + SHA-256'sı ana iş parçacığında çalışmamalı (ANR).
                        val yol = cagri.argument<String>("yol")
                        val ozet = cagri.argument<String>("ozet")
                        Thread { apkKur(yol, ozet, sonuc) }.start()
                    }
                    else -> sonuc.notImplemented()
                }
            }
        }
    }

    private fun agTuru(): String {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        if (cm.activeNetwork == null) return "yok"
        return if (cm.isActiveNetworkMetered) "mobil" else "wifi"
    }

    private fun apkKur(yol: String?, ozet: String?, sonuc: MethodChannel.Result) {
        var oturumNo = -1
        var commitEdildi = false
        try {
            require(yol != null && ozet != null && ozet.length == 64) { "yol ya da özet yok" }
            val dosya = File(yol).canonicalFile
            val klasor = cacheDir.canonicalFile
            require(dosya.path.startsWith(klasor.path + File.separator) && dosya.isFile && dosya.name.endsWith(".apk")) { "APK uygulamanın geçici klasöründe değil" }
            val pm = packageManager
            val yeni = pm.getPackageArchiveInfo(dosya.path, 0) ?: throw IllegalStateException("APK okunamadı")
            require(yeni.packageName == packageName) { "paket adı farklı" }
            val mevcut = pm.getPackageInfo(packageName, 0)
            fun kod(p: android.content.pm.PackageInfo): Long =
                if (Build.VERSION.SDK_INT >= 28) p.longVersionCode else @Suppress("DEPRECATION") p.versionCode.toLong()
            require(kod(yeni) > kod(mevcut)) { "sürüm kodu daha yüksek değil" }

            val kurucu = pm.packageInstaller
            val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
            params.setAppPackageName(packageName)
            val id = kurucu.createSession(params)
            oturumNo = id
            kurucu.openSession(id).use { oturum ->
                // Hash exactly the bytes handed to the installer; a mismatch abandons the session pre-commit.
                val md = java.security.MessageDigest.getInstance("SHA-256")
                java.security.DigestInputStream(dosya.inputStream(), md).use { girdi ->
                    oturum.openWrite("butce-takip.apk", 0, dosya.length()).use { cikti ->
                        girdi.copyTo(cikti)
                        oturum.fsync(cikti)
                    }
                }
                val gercek = md.digest().joinToString("") { "%02x".format(it) }
                require(gercek == ozet.lowercase()) { "SHA-256 özeti tutmuyor" }
                val niyet = Intent(this, KurulumAlici::class.java)
                val bayrak = PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
                oturum.commit(PendingIntent.getBroadcast(this, id, niyet, bayrak).intentSender)
                commitEdildi = true
            }
            runOnUiThread { sonuc.success(null) }
        } catch (e: Exception) {
            // After commit the session may sit in the user's confirm dialog: abandon only on pre-commit failure.
            if (oturumNo >= 0 && !commitEdildi) try { packageManager.packageInstaller.abandonSession(oturumNo) } catch (_: Exception) {}
            runOnUiThread { sonuc.error("kurulum", e.message ?: e.javaClass.simpleName, null) }
        }
    }

    private companion object {
        const val ENBUYUK_PAYLASIM = 5L * 1024 * 1024
    }
}
