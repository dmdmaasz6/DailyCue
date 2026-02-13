import java.net.URL

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val onnxGenAiVersion = "0.12.0"
val onnxAarFile = file("libs/onnxruntime-genai.aar")

// Auto-download the ONNX Runtime GenAI AAR if it doesn't exist locally.
// The package is not published to Maven Central so we fetch it from GitHub Releases.
val downloadOnnxAar by tasks.registering {
    val outputFile = onnxAarFile
    outputs.file(outputFile)
    doLast {
        if (!outputFile.exists()) {
            val url = "https://github.com/microsoft/onnxruntime-genai/releases/download/v$onnxGenAiVersion/onnxruntime-genai-android-$onnxGenAiVersion.aar"
            logger.lifecycle("Downloading ONNX Runtime GenAI v$onnxGenAiVersion AAR …")
            outputFile.parentFile.mkdirs()
            URL(url).openStream().use { input ->
                outputFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            logger.lifecycle("Downloaded to ${outputFile.absolutePath}")
        }
    }
}

tasks.named("preBuild") {
    dependsOn(downloadOnnxAar)
}

android {
    namespace = "com.example.dailycue"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.dailycue"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24) // ONNX Runtime GenAI requires API 24+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packagingOptions {
        // Ensure native libraries are properly extracted
        jniLibs {
            useLegacyPackaging = false
            pickFirsts.add("lib/*/libonnxruntime.so")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // ONNX Runtime — base library required by GenAI
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.24.1")
    // ONNX Runtime GenAI — local AAR (auto-downloaded from GitHub Releases).
    implementation(files("libs/onnxruntime-genai.aar"))
}

flutter {
    source = "../.."
}
