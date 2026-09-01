plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun dotEnvValue(key: String): String? {
    val envFile = rootProject.file("../.env")
    if (!envFile.exists()) return null
    return envFile.readLines()
        .map { it.trim() }
        .firstOrNull { it.startsWith("$key=") }
        ?.substringAfter("=")
        ?.trim()
        ?.takeIf { it.isNotEmpty() }
}

val androidOauthClientId = dotEnvValue("GOOGLE_OAUTH_CLIENT_ID_ANDROID")
val appAuthRedirectScheme: String =
    androidOauthClientId
        ?.takeIf { it.endsWith(".apps.googleusercontent.com") }
        ?.removeSuffix(".apps.googleusercontent.com")
        ?.let { "com.googleusercontent.apps.$it" }
        ?: error(
            "GOOGLE_OAUTH_CLIENT_ID_ANDROID missing or invalid in repo-root .env. " +
                "AppAuth PKCE requires redirect scheme " +
                "com.googleusercontent.apps.<android-client-prefix>. " +
                "Copy .env from a known-good local tree (never commit it), then rebuild. " +
                "Silent package-name fallback is forbidden — it breaks Drive consent return.",
        )

android {
    namespace = "com.akrmcodes.daftar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.akrmcodes.daftar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders.putAll(
            mapOf("appAuthRedirectScheme" to appAuthRedirectScheme),
        )
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
