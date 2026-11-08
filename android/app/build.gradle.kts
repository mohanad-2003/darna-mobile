import java.net.URI
import java.net.URISyntaxException
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which is git-ignored and never committed:
//   storeFile=<path to the upload keystore, relative to android/app or absolute>
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
// Without it a release build stops (see verifyReleaseConfig below); it is never signed with the debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val releaseSigningKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningKeys = releaseSigningKeys.filter { keystoreProperties.getProperty(it).isNullOrBlank() }
val hasReleaseSigning = missingSigningKeys.isEmpty()

android {
    namespace = "com.example.darna"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The store identity of the app: it cannot change once published on Google Play. The code
        // package (namespace above, MainActivity) is a separate thing and may stay as it is.
        applicationId = "com.darna.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

/** The API_BASE_URL the Flutter tool passed with --dart-define (the last definition wins, as in Dart). */
fun releaseApiBaseUrl(): String? {
    val encoded = project.findProperty("dart-defines")?.toString() ?: return null
    return encoded.split(",").filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
        .lastOrNull { it.startsWith("API_BASE_URL=") }
        ?.removePrefix("API_BASE_URL=")?.trim()
}

/** Why [url] cannot be used in a release build, or null. Mirrors AppConfig.validate in lib/core/config.dart. */
fun releaseApiBaseUrlProblem(url: String?): String? {
    if (url.isNullOrBlank()) {
        return "API_BASE_URL is not set. Pass --dart-define=API_BASE_URL=https://<public host>/api/v1"
    }
    val uri = try { URI(url) } catch (e: URISyntaxException) { null }
    if (uri == null || uri.scheme == null || uri.host == null) return "API_BASE_URL is not an absolute URL: $url"
    if (!uri.scheme.equals("https", ignoreCase = true)) return "API_BASE_URL must use https in a release build: $url"
    if (uri.userInfo != null) return "API_BASE_URL must not contain credentials: $url"
    val host = uri.host.lowercase().trim('[', ']')
    val ipv4 = host.split(".").takeIf { it.size == 4 }?.map { it.toIntOrNull() }
    val a = ipv4?.getOrNull(0)
    val b = ipv4?.getOrNull(1)
    val local = host == "localhost" || host.endsWith(".localhost") || host.endsWith(".local") ||
        host == "::1" || host == "::" || (host.contains(":") && (host.startsWith("fe80:") || host.startsWith("fc") || host.startsWith("fd"))) ||
        (ipv4 != null && ipv4.all { it != null && it in 0..255 } && a != null && b != null &&
            (a == 0 || a == 10 || a == 127 || (a == 169 && b == 254) || (a == 172 && b in 16..31) || (a == 192 && b == 168)))
    if (local) return "API_BASE_URL points at a local or private address, not allowed in a release build: $url"
    return null
}

// Every release build (assembleRelease, bundleRelease, flutter build apk/appbundle, flutter run --release)
// passes through preReleaseBuild, so these checks gate all of them.
val verifyReleaseConfig = tasks.register("verifyReleaseConfig") {
    group = "verification"
    description = "Fails a release build that has no HTTPS API_BASE_URL or no release signing key."
    val problem = releaseApiBaseUrlProblem(releaseApiBaseUrl())
    val signingProblem = if (hasReleaseSigning) null else
        "Release signing is not configured: android/key.properties is missing or lacks ${missingSigningKeys.joinToString()}. " +
            "Create it with storeFile, storePassword, keyAlias and keyPassword (keep it and the keystore out of git)."
    val appId = android.defaultConfig.applicationId
    doLast {
        if (appId != null && appId.startsWith("com.example.")) {
            logger.warn("WARNING: applicationId is still the placeholder '$appId'. Set the final id in android/app/build.gradle.kts before publishing.")
        }
        val failures = listOfNotNull(problem, signingProblem)
        if (failures.isNotEmpty()) {
            throw GradleException("Release build blocked:\n - " + failures.joinToString("\n - "))
        }
    }
}

tasks.configureEach {
    if (name == "preReleaseBuild") dependsOn(verifyReleaseConfig)
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
