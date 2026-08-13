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
gradle.beforeProject {
    val manifest = project.projectDir.resolve("src/main/AndroidManifest.xml")
    if (!manifest.isFile) return@beforeProject
    val text = manifest.readText()
    if (!text.contains(Regex("""\spackage="""))) return@beforeProject
    manifest.writeText(text.replace(Regex("""\s+package="[^"]+""""), ""))
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
