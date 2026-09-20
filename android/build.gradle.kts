allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") }
    }
}

// AGP 8.11 rejects `package=""` in plugin AndroidManifest.xml. Pub-cache on CI
// is fresh every run, so patch before any subproject is configured — the
// older plugins.withId hook ran too late for :flutter_native_splash.
// Also bump home_widget's hardcoded JVM 1.8 → 17 (Kotlin 2.4 inline needs it).
gradle.beforeProject {
    val manifest = project.projectDir.resolve("src/main/AndroidManifest.xml")
    if (manifest.isFile) {
        val text = manifest.readText()
        if (text.contains(Regex("""\spackage="""))) {
            manifest.writeText(text.replace(Regex("""\s+package="[^"]+""""), ""))
        }
    }
    if (project.name == "home_widget") {
        val buildGradle = project.projectDir.resolve("build.gradle")
        if (buildGradle.isFile) {
            val text = buildGradle.readText()
            val patched = text
                .replace("JavaVersion.VERSION_1_8", "JavaVersion.VERSION_17")
                .replace("jvmTarget = \"1.8\"", "jvmTarget = \"17\"")
            if (patched != text) {
                buildGradle.writeText(patched)
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// home_widget depends on androidx.glance:1.+ which resolves to 1.3.0-alpha02
// (needs compileSdk 37 + AGP 9.1). Our RemoteViews Continue widget does not
// use Glance UI — pin the last stable that works with AGP 8.11 / SDK 36.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.glance") {
                useVersion("1.1.1")
                because(
                    "Avoid glance 1.3.0-alpha (compileSdk 37 / AGP 9.1); " +
                        "Koma widgets use RemoteViews via home_widget",
                )
            }
        }
    }
}

// Older Flutter plugins still use buildscript { classpath "kotlin-gradle-plugin" }
// with a pinned 1.x/2.2.x. Force 2.4.10 so they can read kotlin-stdlib 2.4 metadata
// pulled in by the app (coroutines / serialization).
subprojects {
    buildscript {
        configurations.named("classpath").configure {
            resolutionStrategy.eachDependency {
                if (requested.group == "org.jetbrains.kotlin" &&
                    requested.name == "kotlin-gradle-plugin"
                ) {
                    useVersion("2.4.10")
                    because("Align plugin Kotlin compilers with app stdlib 2.4.10")
                }
            }
        }
    }
}

// AGP 8.x requires every Android module to declare a `namespace`.
// Some older Flutter plugins (e.g. flutter_native_splash 2.2.16) don't,
// so we patch them. Using `plugins.withId` (rather than afterEvaluate)
// fires the callback when the Android Library plugin is applied —
// before AGP validates the namespace — and works even though the
// subprojects blocks above have already evaluated the projects.
allprojects {
    plugins.withId("com.android.library") {
        // Set a fallback namespace for plugins that don't declare one.
        extensions.findByName("android")?.let { ext ->
            val getter = ext.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val currentNamespace = getter?.invoke(ext) as? String
            if (currentNamespace.isNullOrEmpty()) {
                val setter = ext.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1
                }
                val fallback = "com.koma.${project.name.replace('-', '_')}"
                setter?.invoke(ext, fallback)
            }
        }
    }
    // Same patch for the app module (com.android.application).
    plugins.withId("com.android.application") {
        extensions.findByName("android")?.let { ext ->
            val getter = ext.javaClass.methods.firstOrNull { it.name == "getNamespace" }
            val currentNamespace = getter?.invoke(ext) as? String
            if (currentNamespace.isNullOrEmpty()) {
                val setter = ext.javaClass.methods.firstOrNull {
                    it.name == "setNamespace" && it.parameterCount == 1
                }
                val fallback = "com.koma.${project.name.replace('-', '_')}"
                setter?.invoke(ext, fallback)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
