plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Mapbox public token lives in the project-root .env so that iOS, Dart and
// Android all read a single source of truth. Resolution order:
//   -PMAPBOX_PUBLIC_TOKEN  >  MAPBOX_PUBLIC_TOKEN env var  >  .env file
fun readDotEnv(): Map<String, String> {
    val file = rootProject.file("../.env")
    if (!file.exists()) return emptyMap()
    return file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { line ->
            val key = line.substringBefore("=").trim()
            var value = line.substringAfter("=").trim()
            if (value.length >= 2 && value.startsWith("\"") && value.endsWith("\"")) {
                value = value.substring(1, value.length - 1)
            }
            key to value
        }
}

val mapboxPublicToken: String =
    (project.findProperty("MAPBOX_PUBLIC_TOKEN") as String?)
        ?: System.getenv("MAPBOX_PUBLIC_TOKEN")
        ?: readDotEnv()["MAPBOX_PUBLIC_TOKEN"]
        ?: ""

require(mapboxPublicToken.startsWith("pk.")) {
    "Mapbox public token missing. Copy .env.example to .env and set " +
        "MAPBOX_PUBLIC_TOKEN=pk.your_token_here, or pass " +
        "-PMAPBOX_PUBLIC_TOKEN=pk.your_token_here to the Gradle build. " +
        "Without it the Android app renders a blank map."
}

android {
    namespace = "com.oaunavigator.oau_navigator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.oaunavigator.oau_navigator"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] = mapboxPublicToken
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
