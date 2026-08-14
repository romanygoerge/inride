import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// -----------------------------------------------------------------------------
// Secure Release Signing Configuration
// Loads credentials from `key.properties` or CI environment variables securely.
// Never commits secrets to version control.
// -----------------------------------------------------------------------------
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

fun getSigningProperty(key: String, envKey: String): String? {
    return keystoreProperties.getProperty(key)?.trim() ?: System.getenv(envKey)?.trim()
}

val storeFilePath = getSigningProperty("storeFile", "ANDROID_KEYSTORE_PATH")
val storePasswordVal = getSigningProperty("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val keyAliasVal = getSigningProperty("keyAlias", "ANDROID_KEY_ALIAS")
val keyPasswordVal = getSigningProperty("keyPassword", "ANDROID_KEY_PASSWORD")

val hasReleaseSigning = !storeFilePath.isNullOrBlank() &&
    !storePasswordVal.isNullOrBlank() &&
    !keyAliasVal.isNullOrBlank() &&
    !keyPasswordVal.isNullOrBlank()

android {
    namespace = "com.inride.inride_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.1.13356709"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.inride.inride_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                val keyFile = File(storeFilePath!!)
                storeFile = if (keyFile.isAbsolute) keyFile else rootProject.file(storeFilePath)
                storePassword = storePasswordVal
                keyAlias = keyAliasVal
                keyPassword = keyPasswordVal
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
