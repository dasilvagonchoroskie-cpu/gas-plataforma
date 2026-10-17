import java.util.Properties

// Chave de assinatura da revenda. O arquivo key.properties só existe na esteira
// de build (é criado na hora e apagado no fim); nunca vai para o repositório.
val propriedadesChave = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) {
        arquivo.inputStream().use { load(it) }
    }
}

// Marca da revenda (marca/marca.json, na raiz do repositório): nomes dos apps.
@Suppress("UNCHECKED_CAST")
val marca: Map<String, Any?> = rootProject.file("../../../marca/marca.json").let { arquivo ->
    if (arquivo.exists()) groovy.json.JsonSlurper().parse(arquivo) as Map<String, Any?> else emptyMap()
}

fun nomeDaMarca(chave: String, padrao: String): String =
    (marca[chave] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: padrao

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "br.com.fortalezadigitalsecurity.gasagua.painel"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.fortalezadigitalsecurity.gasagua.painel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // As notificações (Firebase) pedem Android 7 ou mais novo.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dois aplicativos com o mesmo código. Gerar com --flavor supercentral ou
    // --flavor central (e --dart-define=PAINEL com o mesmo nome).
    flavorDimensions += "painel"
    productFlavors {
        create("supercentral") {
            dimension = "painel"
            // Mesmo identificador do painel antigo: instala por cima no celular
            // do dono, sem perder o login.
            applicationId = "br.com.fortalezadigitalsecurity.gasagua.painel"
            manifestPlaceholders["nomeApp"] = nomeDaMarca("NOME_SUPER_CENTRAL", "Super Central")
        }
        create("central") {
            dimension = "painel"
            applicationId = "br.com.fortalezadigitalsecurity.gasagua.central"
            manifestPlaceholders["nomeApp"] = nomeDaMarca("NOME_CENTRAL", "Central")
        }
    }

    signingConfigs {
        if (!propriedadesChave.isEmpty()) {
            create("revenda") {
                storeFile = file(propriedadesChave.getProperty("storeFile"))
                storePassword = propriedadesChave.getProperty("storePassword")
                keyAlias = propriedadesChave.getProperty("keyAlias")
                keyPassword = propriedadesChave.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Com a chave da revenda quando disponível; sem ela (em testes
            // locais), usa a chave de depuração.
            signingConfig = if (propriedadesChave.isEmpty()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("revenda")
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
