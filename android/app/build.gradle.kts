plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseStoreFilePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orNull
val releaseStorePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orNull

val releaseSigningConfigured = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

val qaReleaseRequested = providers.gradleProperty("qaRelease")
    .map(String::toBoolean)
    .getOrElse(false)

val isReleaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (isReleaseBuildRequested && !qaReleaseRequested) {
    require(releaseSigningConfigured) {
        "Production release signing is not configured. For a non-production QA build, " +
            "set ORG_GRADLE_PROJECT_qaRelease=true. Never use a QA key for production."
    }
    require(file(requireNotNull(releaseStoreFilePath)).isFile) {
        "Production Android keystore file was not found at ANDROID_KEYSTORE_PATH."
    }
}

if (isReleaseBuildRequested && qaReleaseRequested) {
    require(!releaseSigningConfigured) {
        "QA release mode must not receive production signing credentials."
    }
}

android {
    namespace = "com.arfatalkamli.academicos"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

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
        if (releaseSigningConfigured) {
            create("productionRelease") {
                storeFile = file(requireNotNull(releaseStoreFilePath))
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            // R8 and resource shrinking are enabled for the production artifact.
            // Flutter/plugin consumer rules remain active; runtime acceptance is required.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            // QA Release uses Android's debug keystore only when explicitly requested.
            // Production Release continues to require the dedicated production keystore.
            signingConfig = when {
                qaReleaseRequested -> signingConfigs.getByName("debug")
                releaseSigningConfigured -> signingConfigs.getByName("productionRelease")
                else -> null
            }
        }
    }
}

dependencies {
    // Required by flutter_local_notifications for Java API desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.browser:browser:1.8.0")
}

flutter {
    source = "../.."
}
