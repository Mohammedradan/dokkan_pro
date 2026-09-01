plugins {
    id("com.android.application")
    id("kotlin-android")
    // يجب تطبيق Flutter Gradle Plugin بعد Android و Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.dokkan.grocery"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        applicationId = "com.dokkan.grocery"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // التوقيع بمفتاح التطوير مؤقتاً لسهولة تثبيت نسخة الإصدار
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // مطلوب من flutter_local_notifications للتوافق مع أندرويد القديم
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
