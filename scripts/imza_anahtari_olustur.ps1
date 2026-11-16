# Bütçe Takip (Android) sürüm imza anahtarını BİR KEZ oluşturur ve GitHub secret'larına yükler.
#
# - Anahtar depo DIŞINA yazılır: Belgeler\butce-takip-imza\butce-surum.jks (alias: butce).
#   Aynı klasör ikinci yedeğe de kopyalanır: D:\Yedek-Imza-Anahtarlari (sürücü yoksa uyarı verilir,
#   o zaman klasörü elle başka bir yere kopyala). Anahtar kaybolursa sonraki sürümler eskisinin
#   üstüne kurulamaz (hep aynı anahtar kullanılmalı).
# - Parola rastgele üretilir ve komut satırında görünmez (keytool: -storepass:env, gh: stdin).
#   Düz metin parola dosyası YAZILMAZ. Parolanın kurtarma kopyası, yalnız bu Windows kullanıcısının
#   çözebileceği DPAPI ile şifreli sifre.dpapi dosyasındadır (başka kullanıcı/makinede çözülmez).
# - Ekrana yalnız sertifikanın SHA-256 parmak izi basılır (gizli değil).
#
# Kullanım (depo kökünde, gh oturumu açıkken):
#   powershell -ExecutionPolicy Bypass -File scripts\imza_anahtari_olustur.ps1

param(
    [string]$Klasor = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'butce-takip-imza'),
    [string]$Yedek = 'D:\Yedek-Imza-Anahtarlari',
    [string]$Repo = 'tungarix/butce-takip'
)
$ErrorActionPreference = 'Stop'

$anahtar = Join-Path $Klasor 'butce-surum.jks'
if (Test-Path $anahtar) {
    throw "Anahtar zaten var: $anahtar. Üzerine yazılmaz; yeni anahtar eski APK'larla uyumsuz olur."
}

# keytool: önce PATH, sonra JAVA_HOME, sonra bilinen JDK/Android Studio klasörleri.
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool -and $env:JAVA_HOME) {
    $aday = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
    if (Test-Path $aday) { $keytool = $aday }
}
if (-not $keytool) {
    # PATH'teki java çoğu zaman Oracle'ın javapath kısayolu; keytool JDK'nın bin'inde.
    $keytool = Get-ChildItem 'C:\Program Files\Java', 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Android\Android Studio\jbr' `
        -Recurse -Depth 3 -Filter keytool.exe -ErrorAction SilentlyContinue |
        Select-Object -Last 1 -ExpandProperty FullName
}
if (-not $keytool -or -not (Test-Path $keytool)) { throw 'keytool bulunamadı (Java ile gelir).' }

New-Item -ItemType Directory -Force $Klasor | Out-Null

# 32 karakter rastgele parola (harf + rakam; keytool argümanında kaçış gerektirmez).
$harfler = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$bayt = New-Object byte[] 32
$rng.GetBytes($bayt)
$sifre = -join ($bayt | ForEach-Object { $harfler[$_ % $harfler.Length] })

# Parola komut satırında görünmesin: keytool ortam değişkeninden okur (-storepass:env).
$env:BUTCE_ANAHTAR_PAROLA = $sifre

# keytool ve gh bilgi satırlarını stderr'e yazar; Windows PowerShell 5.1 bunu Stop
# altında hata sayıp betiği keserdi. Buradan sonra yalnız çıkış kodlarına bakılır.
$ErrorActionPreference = 'Continue'
& $keytool -genkeypair -keystore $anahtar -storetype PKCS12 -alias butce `
    -keyalg RSA -keysize 4096 -validity 10000 `
    -storepass:env BUTCE_ANAHTAR_PAROLA -keypass:env BUTCE_ANAHTAR_PAROLA `
    -dname 'CN=Aktenak Butce Takip, O=Aktenak, C=TR' 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'keytool anahtarı oluşturamadı.' }

# DPAPI: düz metin değil; yalnız bu kullanıcı bu makinede çözebilir.
ConvertTo-SecureString $sifre -AsPlainText -Force | ConvertFrom-SecureString |
    Set-Content -Path (Join-Path $Klasor 'sifre.dpapi') -Encoding ascii

@"
Bütçe Takip (Android) sürüm imza anahtarı ($(Get-Date -Format yyyy-MM-dd))
Dosya: butce-surum.jks. Alias: butce. Parola düz metin olarak hiçbir yerde yok.
Kurtarma: sifre.dpapi yalnız bu Windows kullanıcısı bu makinede çözebilir:
  [pscredential]::new('x', (Get-Content sifre.dpapi | ConvertTo-SecureString)).GetNetworkCredential().Password
GitHub secret'ları: BUTCE_KEYSTORE_BASE64, BUTCE_KEYSTORE_PASSWORD ($Repo).
Bu klasörü yedekle. Kaybolursa sonraki APK'lar eskisinin üstüne kurulmaz.
"@ | Set-Content -Path (Join-Path $Klasor 'BENIOKU.txt') -Encoding utf8

# Secret'lar stdin'den gider (komut satırında görünmez). PowerShell pipe'ı sona satır sonu
# eklerdi; bu yüzden süreç doğrudan açılıp baytlar sonsuz satırsız yazılır.
function Set-GhSecret([string]$Ad, [string]$Deger) {
    $psi = New-Object Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Command gh).Source
    $psi.Arguments = "secret set $Ad -R $Repo"
    $psi.RedirectStandardInput = $true
    $psi.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Write($Deger)
    $p.StandardInput.Close()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "Secret yüklenemedi: $Ad (gh auth status?)." }
}
Set-GhSecret 'BUTCE_KEYSTORE_BASE64' ([Convert]::ToBase64String([IO.File]::ReadAllBytes($anahtar)))
Set-GhSecret 'BUTCE_KEYSTORE_PASSWORD' $sifre

# İkinci yedek: sürücü yoksa yalnız uyarı (anahtar ve secret'lar zaten hazır).
if (Test-Path (Split-Path $Yedek -Qualifier)) {
    New-Item -ItemType Directory -Force $Yedek | Out-Null
    Copy-Item -Path $Klasor -Destination $Yedek -Recurse -Force
    Write-Host "İkinci yedek: $Yedek"
} else {
    Write-Warning "İkinci yedek alınamadı: '$Yedek' sürücüsü yok. $Klasor klasörünü elle başka bir yere kopyala."
}

Write-Host "Tamam. Anahtar klasörü: $Klasor"
Write-Host 'Sertifika parmak izi:'
& $keytool -list -v -keystore $anahtar -storepass:env BUTCE_ANAHTAR_PAROLA -alias butce 2>$null |
    Select-String 'SHA256:'
Remove-Item Env:BUTCE_ANAHTAR_PAROLA
$sifre = $null
