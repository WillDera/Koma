plugins {
    id("com.android.application") version "8.11.1"
    id("dev.flutter.flutter-gradle-plugin")
    kotlin("android") version "2.2.20"
}

android {
    namespace = "com.koma.koma"
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
        applicationId = "com.koma.koma"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("koma") {
            storeFile = file("koma-debug.keystore")
            storePassword = "stashreader"
            keyAlias = "stashreader"
            keyPassword = "stashreader"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("koma")
        }
        release {
            signingConfig = signingConfigs.getByName("koma")
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "META-INF/versions/9/OSGI-INF/MANIFEST.MF",
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jsoup:jsoup:1.17.2")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    implementation("com.squareup.okhttp3:okhttp-brotli:5.4.0")
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
