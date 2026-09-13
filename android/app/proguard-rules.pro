-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }
-keep class com.koma.koma.** { *; }
-keepclassmembers class com.koma.koma.** { *; }
-keep class com.squareup.okhttp3.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class org.jsoup.** { *; }
-keep class io.reactivex.** { *; }
-keep class rx.** { *; }
-keep class mihon.** { *; }
-keep class eu.kanade.** { *; }
-keep class androidx.preference.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class kotlin.Metadata { *; }
-keep class javax.inject.** { *; }
-keep class dagger.** { *; }
-keepclassmembers,allowobfuscation class * {
    @javax.inject.Inject <init>(...);
}
# Flutter Rust Bridge / JNI entry points
-keep class com.flutter_rust_bridge.** { *; }
-keep class dev.fluttercommunity.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}
-dontwarn kotlinx.serialization.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.jsoup.**
-dontwarn io.reactivex.**
-dontwarn rx.**
-dontwarn com.flutter_rust_bridge.**
