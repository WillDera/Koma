# Keep host Kotlin that extensions / Dalvik load by reflection or ClassLoader.
# Sideloaded Keiyoushi APKs do not ship kotlin-stdlib — they resolve
# kotlin.text.Regex etc. through the host ClassLoader. R8 must not shrink or
# rename those symbols (Mihon parity: -keep class kotlin.**).

# Kotlin stdlib + coroutines + serialization (extensions + host JSON bridges)
-keep,allowoptimization class kotlin.** { public protected *; }
-keep,allowoptimization class kotlin.Metadata { *; }
-keep,allowoptimization class kotlinx.coroutines.** { public protected *; }
-keepclassmembers class kotlinx.coroutines.** { *; }
-keep,allowoptimization class kotlinx.serialization.** { public protected *; }
-keepclassmembers class kotlinx.serialization.** { *; }
-keepattributes *Annotation*, InnerClasses, Signature, EnclosingMethod
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# App + MethodChannel entry points
-keep class com.koma.koma.** { *; }
-keepclassmembers class com.koma.koma.** { *; }

# OkHttp / Okio / Jsoup (extension HTTP stack)
-keep,allowoptimization class com.squareup.okhttp3.** { public protected *; }
-keep,allowoptimization class okhttp3.** { public protected *; }
-keep,allowoptimization class okio.** { public protected *; }
-keep,allowoptimization class org.jsoup.** { public protected *; }

# okhttp-zstd JNI looks up these by name from libzstd-kmp.so
# (FindClass "com.squareup.zstd.ZstdCompressor" / GetFieldID
# inputBytesProcessed, outputBytesProcessed). If R8 strips or renames
# them, ART aborts: "No pending exception expected: ClassNotFoundException"
# on zstd Content-Encoding (Explore search / some Keiyoushi sources).
-keep,includedescriptorclasses class com.squareup.zstd.** { *; }
-keepclassmembers class com.squareup.zstd.** { *; }
-keepclassmembers class com.squareup.zstd.ZstdCompressor {
    int inputBytesProcessed;
    int outputBytesProcessed;
}
-keepclassmembers class com.squareup.zstd.ZstdDecompressor {
    int inputBytesProcessed;
    int outputBytesProcessed;
}
-keep class com.squareup.zstd.JniZstdKt { *; }
-keep class com.squareup.zstd.JniZstdCompressor { *; }
-keep class com.squareup.zstd.JniZstdDecompressor { *; }
-keep class com.koma.koma.ZstdJniKeep { *; }

# RxJava 1 (legacy CatalogueSource APIs)
-keep,allowoptimization class io.reactivex.** { public protected *; }
-keep,allowoptimization class rx.** { public protected *; }

# Mihon / Tachiyomi / Keiyoushi surfaces used by sideloaded extension DEX
-keep class mihon.** { *; }
-keep class eu.kanade.** { *; }
-keep class tachiyomi.** { *; }
-keep class keiyoushi.** { *; }
-keep,allowoptimization class uy.kohesive.injekt.** { public protected *; }

# Preferences UI for ConfigurableSource
-keep,allowoptimization class androidx.preference.** { public protected *; }
-keep class androidx.appcompat.** { *; }
-keep class androidx.work.** { *; }

# WebView (Cloudflare / runWebView / SourceWebViewActivity)
-keep class android.webkit.** { *; }
-keepclassmembers class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * extends android.webkit.WebChromeClient { *; }

-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class javax.inject.** { *; }
-keep class dagger.** { *; }
-keepclassmembers,allowobfuscation class * {
    @javax.inject.Inject <init>(...);
}

# Flutter Rust Bridge / JNI / community plugins
-keep class com.flutter_rust_bridge.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keep class io.flutter.plugins.** { *; }
# Do NOT -keep io.flutter.embedding.** — that retains
# PlayStoreDeferredComponentManager / FlutterPlayStoreSplitApplication, which
# reference Play Core split-install APIs we do not ship. R8 full mode then
# fails on those missing classes during minifyReleaseWithR8.
-keepclasseswithmembernames class * {
    native <methods>;
}

# PathClassLoader / reflection used when loading extension APKs
-keep class dalvik.system.PathClassLoader { *; }
-keep class dalvik.system.DexClassLoader { *; }
-keep class eu.kanade.tachiyomi.util.system.ChildFirstPathClassLoader { *; }

-dontwarn kotlin.**
-dontwarn kotlinx.serialization.**
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn com.squareup.zstd.**
-dontwarn org.jsoup.**
-dontwarn io.reactivex.**
-dontwarn rx.**
-dontwarn com.flutter_rust_bridge.**
-dontwarn uy.kohesive.injekt.**
-dontwarn keiyoushi.**
-dontwarn eu.kanade.**
-dontwarn tachiyomi.**
-dontwarn mihon.**
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# Flutter embedding references Play Core for optional deferred components.
# We do not use dynamic feature modules — suppress R8 missing-class errors.
-dontwarn com.google.android.play.core.**
