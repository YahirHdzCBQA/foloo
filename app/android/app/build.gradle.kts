plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningEnvironment =
    mapOf(
        "keystorePath" to System.getenv("FOLOO_ANDROID_KEYSTORE_PATH"),
        "storePassword" to System.getenv("FOLOO_ANDROID_KEYSTORE_PASSWORD"),
        "keyAlias" to System.getenv("FOLOO_ANDROID_KEY_ALIAS"),
        "keyPassword" to System.getenv("FOLOO_ANDROID_KEY_PASSWORD"),
    )
val releaseSigningConfigured =
    releaseSigningEnvironment.values.all { !it.isNullOrBlank() }
val releaseBuildRequested =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val disableReleaseR8ForOcrQa =
    System.getenv("FOLOO_ANDROID_DISABLE_R8_FOR_OCR_QA")
        ?.equals("true", ignoreCase = true) == true

if (releaseBuildRequested && !releaseSigningConfigured) {
    throw GradleException(
        "Android Release signing requires FOLOO_ANDROID_KEYSTORE_PATH, " +
            "FOLOO_ANDROID_KEYSTORE_PASSWORD, FOLOO_ANDROID_KEY_ALIAS, and " +
            "FOLOO_ANDROID_KEY_PASSWORD.",
    )
}

val releaseKeystore =
    releaseSigningEnvironment["keystorePath"]?.takeIf { it.isNotBlank() }?.let(::file)
if (releaseBuildRequested && releaseKeystore?.isFile != true) {
    throw GradleException(
        "FOLOO_ANDROID_KEYSTORE_PATH must reference an existing Release keystore.",
    )
}

android {
    namespace = "com.foloo.foloo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.foloo.foloo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // RNF-03: Foloo supports Android 10 and newer.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = releaseSigningEnvironment.getValue("storePassword")
                keyAlias = releaseSigningEnvironment.getValue("keyAlias")
                keyPassword = releaseSigningEnvironment.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // STORE-03E: this opt-in switch isolates R8 in a signed physical QA
            // build. Normal Release builds remain minified and resource-shrunk.
            isMinifyEnabled = !disableReleaseR8ForOcrQa
            isShrinkResources = !disableReleaseR8ForOcrQa
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
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
