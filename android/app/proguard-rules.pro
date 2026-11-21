# google_mlkit_text_recognition eklentisi Latin dışı tanıyıcı sınıflarına da başvurur; uygulama yalnız
# Latin modelini paketler (Ziraat dökümü). Eksik sınıflar R8'i durdurmasın.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ML Kit bileşenlerini yansımayla (manifest meta-data -> ComponentRegistrar) bulur; R8 bunları
# kaldırınca release'te tanıyıcı NullPointerException ile açılmıyordu.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
