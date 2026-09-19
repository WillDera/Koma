pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    // Flutter plugins often apply Kotlin without a version and pick up an older
    // compiler (e.g. 2.2) while the app resolves kotlin-stdlib 2.4.x → metadata
    // mismatch during CI release builds. Pin every Kotlin plugin request.
    resolutionStrategy {
        eachPlugin {
            if (requested.id.namespace == "org.jetbrains.kotlin" ||
                requested.id.id.startsWith("org.jetbrains.kotlin")
            ) {
                useVersion("2.4.10")
            }
        }
    }
}

plugins {
    id("com.android.application") version "8.11.1" apply false
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")
