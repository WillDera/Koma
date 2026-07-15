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

    kotlinOptions {
        jvmTarget = "17"
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
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
}

