import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 上架签名配置：android/key.properties + android/app/fatbattle-release.keystore
// 由 scripts/setup_signing.ps1 生成，均已 gitignore；缺失时回退 debug 签名
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.fatbattle.fat_battle"
    // google_mlkit_pose_detection 需要 compileSdk >= 35
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.fatbattle.fat_battle"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_mlkit_pose_detection 要求 minSdk>=21, compileSdk>=35, targetSdk>=35
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = maxOf(flutter.targetSdkVersion, 35)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // 存在 key.properties 时用正式签名（上架），否则回退 debug 签名
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Flutter 插件默认开启 minify；ML Kit 在 R8 下仍会 Internal error。
            // 先关混淆保证姿态可用，后续再收紧 keep 规则。
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// Flutter Gradle Plugin 会把 release.isMinifyEnabled 强制为 true，这里再关一次。
afterEvaluate {
    android.buildTypes.getByName("release").apply {
        isMinifyEnabled = false
        isShrinkResources = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// pose-detection 18.0.0-beta5 在 Android 14+（含本机 API 36）上有已知崩溃/Internal error；
// 社区 workaround：强制降到 beta1。见 googlesamples/mlkit#982
configurations.all {
    resolutionStrategy {
        force("com.google.mlkit:pose-detection:18.0.0-beta1")
        force("com.google.mlkit:pose-detection-accurate:18.0.0-beta1")
    }
}
