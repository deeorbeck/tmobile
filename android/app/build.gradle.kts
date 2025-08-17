plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "uz.uniquepros.tmobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.nftmobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = file("../../mykey.jks")  // .jks (keystore) faylingiz joylashgan manzil
            storePassword = "tmobile362003@"     // keystore paroli
            keyAlias = "myalias"                     // keystore ichidagi alias nomi
            keyPassword = "tmobile362003@"       // shu alias uchun parol
        }
    }


    buildTypes {
	release {
	
            isMinifyEnabled = true

            // keraksiz resurslarni olib tashlash yoqilsin
            isShrinkResources = true

            // keystore bilan imzolash
            signingConfig = signingConfigs.getByName("release")
        }

    }
}

flutter {
    source = "../.."
}
