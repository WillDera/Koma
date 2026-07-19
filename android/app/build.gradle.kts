plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    kotlin("android")
}

android {
    namespace = "com.stashreader.stashreader"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.stashreader.stashreader"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("stashreader") {
            storeFile = file("stashreader-debug.keystore")
            storePassword = "stashreader"
            keyAlias = "stashreader"
            keyPassword = "stashreader"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("stashreader")
        }
        release {
            signingConfig = signingConfigs.getByName("stashreader")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jsoup:jsoup:1.17.2")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    implementation("com.squareup.okio:okio:3.9.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json-okio:1.6.3")
    // RxJava 1 — source-api uses rx.Observable for deprecated fetch* methods
    implementation("io.reactivex:rxjava:1.3.8")
    // AndroidX Preference — needed by ConfigurableSource
    implementation("androidx.preference:preference-ktx:1.2.1")
    // Keiyoushi extensions expect Injekt (dependency injection) at runtime
    implementation("com.github.mihonapp:injekt:91edab2317")
}
