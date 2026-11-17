plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Production signing is opt-in. The QA workflow deliberately keeps using the
// debug key; production builds must provide all four EDUNIVORA_ANDROID_* values.
val releaseKeystorePath = providers.environmentVariable("EDUNIVORA_ANDROID_KEYSTORE_PATH").orNull
val releaseStorePassword = providers.environmentVariable("EDUNIVORA_ANDROID_STORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("EDUNIVORA_ANDROID_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("EDUNIVORA_ANDROID_KEY_PASSWORD").orNull
val releaseSigningValues = listOf(
    releaseKeystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
)
val hasAnyReleaseSigningValue = releaseSigningValues.any { !it.isNullOrBlank() }
val hasCompleteReleaseSigningValues = releaseSigningValues.all { !it.isNullOrBlank() }

if (hasAnyReleaseSigningValue && !hasCompleteReleaseSigningValues) {
    throw org.gradle.api.GradleException(
        "Android release signing is partially configured. Provide all four EDUNIVORA_ANDROID_* values.",
    )
}

val releaseKeystoreFile = releaseKeystorePath
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }

if (hasCompleteReleaseSigningValues && releaseKeystoreFile?.isFile != true) {
    throw org.gradle.api.GradleException(
        "EDUNIVORA_ANDROID_KEYSTORE_PATH does not point to an existing keystore file.",
    )
}

android {
    namespace = "com.arfatalkamli.academicos"
    compileSdk = flutter.compileSdkVersion
    // NDK references removed — this project does not use native C++ code.

    compileOptions {
        // Required by flutter_local_notifications for Java API desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.arfatalkamli.academicos"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasCompleteReleaseSigningValues) {
            create("productionRelease") {
                storeFile = releaseKeystoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Without owner-provided signing material this remains a QA-only
            // debug-signed artifact, never a Play Store/release deliverable.
            signingConfig = if (hasCompleteReleaseSigningValues) {
                signingConfigs.getByName("productionRelease")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // Required by flutter_local_notifications for Java API desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")
}

flutter {
    source = "../.."
}
