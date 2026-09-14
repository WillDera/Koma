# Keep host Kotlin that extensions / Dalvik load by reflection or ClassLoader.

# Serialization (extensions + host JSON bridges)
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.coroutines.** { *; }

# App + MethodChannel entry points
-keep class com.koma.koma.** { *; }
-keepclassmembers class com.koma.koma.** { *; }

# OkHttp / Okio / Jsoup (extension HTTP stack)
-keep class com.squareup.okhttp3.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class org.jsoup.** { *; }

# RxJava 1 (legacy CatalogueSource APIs)
-keep class io.reactivex.** { *; }
-keep class rx.** { *; }

# Mihon / Tachiyomi / Keiyoushi surfaces used by sideloaded extension DEX
-keep class mihon.** { *; }
-keep class eu.kanade.** { *; }
-keep class tachiyomi.** { *; }
-keep class keiyoushi.** { *; }
-keep class uy.kohesive.injekt.** { *; }

# Preferences UI for ConfigurableSource
-keep class androidx.preference.** { *; }
-keep class androidx.appcompat.** { *; }
-keep class androidx.work.** { *; }

# WebView (Cloudflare / runWebView / SourceWebViewActivity)
-keep class android.webkit.** { *; }
-keepclassmembers class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * extends android.webkit.WebChromeClient { *; }

-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class kotlin.Metadata { *; }
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

-dontwarn kotlinx.serialization.**
-dontwarn kotlinx.coroutines.**
-dontwarn okhttp3.**
-dontwarn okio.**
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
