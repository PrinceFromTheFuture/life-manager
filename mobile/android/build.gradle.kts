allprojects {
    repositories {
        google()
        mavenCentral()
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

// Pin every plugin's compileSdk to the one platform we know is actually
// installed and resolvable, in both directions.
//
// Flutter plugins pin their own compileSdk, and one that disagrees with what
// is on disk fails the whole build with an error naming the plugin rather
// than anything in this project — as geocoding_android did at API 33, lagging
// behind. flutter_secure_storage went the other way and asks for 37, which
// the SDK manager installs as a fractional API level ("android-37.0", not
// "android-37" — Android's newer versioning decouples API level from
// platform number) that this Gradle hash string can never resolve. Pinning
// everyone to the same known-good integer level avoids both failure modes
// every time a dependency is added or bumps its own pin.
//
// compileSdk only decides which APIs are visible at build time. Each plugin's
// minSdk and targetSdk are untouched, so device support and runtime behaviour
// are unaffected.
//
// **Order matters.** This has to register before the `evaluationDependsOn`
// block below, which forces subprojects to evaluate — registering an
// `afterEvaluate` on an already-evaluated project is an error.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.gradle.BaseExtension) {
            val current = android.compileSdkVersion
                ?.substringAfter("android-")
                ?.toIntOrNull()
            if (current != null && current != 36) {
                android.compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
