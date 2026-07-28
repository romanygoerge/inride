

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// 1. Android plugins compileSdkVersion & namespace setup (must run BEFORE evaluationDependsOn)
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library") || plugins.hasPlugin("com.android.application")) {
            val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            if (android != null) {
                // Safe check: Only raise compileSdkVersion if it is lower than 34 (to avoid breaking newer plugins like sqflite)
                val currentSdk = android.compileSdkVersion
                var sdkInt = 0
                if (currentSdk != null) {
                    val sdkStr = currentSdk.toString().replace("android-", "").trim()
                    sdkInt = sdkStr.toIntOrNull() ?: 0
                }
                if (sdkInt > 0 && sdkInt < 34) {
                    android.compileSdkVersion(34)
                }
                
                // Inject namespace if missing
                if (android.namespace == null) {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val manifestContent = manifestFile.readText()
                        val packageRegex = """package=["']([^"']+)["']""".toRegex()
                        val matchResult = packageRegex.find(manifestContent)
                        if (matchResult != null) {
                            android.namespace = matchResult.groupValues[1]
                        }
                    }
                }
            }
        }
    }
}

// 2. Build directory layout configuration
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// 3. Application dependency evaluation
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
