import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The upload key and its passwords are NOT in this project: SAYTV_KEY_PROPERTIES points to a key.properties file kept
// elsewhere (see store/release-checklist.md). Without it, a release build is signed with the debug key and Google Play will refuse it.
val keyPropertiesFile: File? = System.getenv("SAYTV_KEY_PROPERTIES")?.let { File(it) } ?: rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile != null && keyPropertiesFile.exists()) FileInputStream(keyPropertiesFile).use { load(it) }
}

android {
    namespace = "com.visswaverse.voiceremote"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.visswaverse.voiceremote"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // The version code and name come from `version:` in pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (!keyProperties.isEmpty) {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (!keyProperties.isEmpty) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
