import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.example.visit_gondar"
    compileSdk = flutter.compileSdkVersion
    // NDK intentionally not set: no native C++ in this app, and the
    // multi-GB NDK download kept failing on low disk. Without it the
    // engine .so files are packaged unstripped (slightly larger APK).

    compileOptions {
        // Needed by flutter_local_notifications (phone notifications).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.visitgondar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")
                ?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
            // Sign with ALL schemes so the APK installs on every phone,
            // old and new. v2-only was failing to install on some devices.
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            // Use the real release key when android/key.properties exists
            // (it is git-ignored). On a fresh clone without it, fall back
            // to the debug key so `flutter build apk --release` still works
            // for testing. Phones may then need the old app uninstalled
            // first, because the signature is different.
            signingConfig =
                if (keystoreProperties.getProperty("storeFile") != null)
                    signingConfigs.getByName("release")
                else
                    signingConfigs.getByName("debug")
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
