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

// Raise any plugin still compiling against an older SDK up to ours.
//
// Flutter plugins pin their own compileSdk, and one lagging behind fails the
// whole build with an error naming the plugin rather than anything in this
// project — as geocoding_android did at API 33. This keeps that from being a
// recurring papercut every time a dependency is added.
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
            if (current != null && current < 36) {
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
