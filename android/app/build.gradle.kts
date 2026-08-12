plugins {
    id("com.android.application") version "8.11.1"
    id("dev.flutter.flutter-gradle-plugin")
    kotlin("android") version "2.4.10"
}

android {
    namespace = "com.koma.koma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        prefab = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (Java 8+ API desugaring).
        isCoreLibraryDesugaringEnabled = true
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
        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17"
                arguments += listOf("-DANDROID_STL=c++_shared")
            }
        }
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        create("koma") {
            storeFile = file("koma-debug.keystore")
            storePassword = "k0m@k0m@"
            keyAlias = "k0m@k0m@"
            keyPassword = "k0m@k0m@"
        }
    }

    buildTypes {
        debug {
            if (file("koma-debug.keystore").exists()) {
                signingConfig = signingConfigs.getByName("koma")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        getByName("profile") {
            if (file("koma-debug.keystore").exists()) {
                signingConfig = signingConfigs.getByName("koma")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
        release {
            if (file("koma-debug.keystore").exists()) {
                signingConfig = signingConfigs.getByName("koma")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            pickFirsts += listOf("**/libonnxruntime.so", "**/libc++_shared.so")
        }
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("org.jsoup:jsoup:1.17.2")
    implementation("com.squareup.okhttp3:okhttp:5.4.0")
    implementation("com.squareup.okhttp3:okhttp-brotli:5.4.0")
    implementation("com.squareup.okhttp3:okhttp-zstd:5.4.0")
    implementation("com.squareup.okio:okio:3.9.0")
    // Keiyoushi extensions are compiled against mihon's coroutines bundle (1.11.0).
    // Newer extensions use `BuildersKt.runBlockingK` (concurrent source set), which
    // does not exist before 1.10 — pinning below 1.11.0 causes NoSuchMethodError
    // when the Dalvik server calls extension headersBuilder/getMangaUpdate etc.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-guava:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json-okio:1.11.0")
    // RxJava 1 — source-api uses rx.Observable for deprecated fetch* methods
    implementation("io.reactivex:rxjava:1.3.8")
    // AndroidX Preference — needed by ConfigurableSource + prefs Activity
    implementation("androidx.preference:preference-ktx:1.2.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    // FileProvider + MediaStore helpers for gallery export / share
    implementation("androidx.core:core-ktx:1.15.0")
    // Keiyoushi extensions expect Injekt (dependency injection) at runtime
    implementation("com.github.mihonapp:injekt:91edab2317")
    // Piper TTS — ONNX Runtime (linked by koma_piper native lib).
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.22.0")
}
