allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 让每个 Flutter 插件（com.android.library）的 Kotlin jvmTarget 跟随其自身的 Java
// sourceCompatibility，避免 AGP 9.0 的 "Inconsistent JVM Target Compatibility" 检查失败。
// 不同插件硬编码的 Java 版本不一（tflite_flutter=1.8, flutter_tts=11, camera_android_camerax=17），
// 强制统一会破坏原本一致的插件或被 AGP finalize 拒绝；这里只读取 Java 版本（读取不被
// finalize 拦截）并将 Kotlin 对齐到同版本。:app 是 application 不会进入此分支。
subprojects {
    plugins.withId("com.android.library") {
        project.afterEvaluate {
            val android = extensions.getByType<com.android.build.api.dsl.LibraryExtension>()
            val javaVer = android.compileOptions.sourceCompatibility
            val ktTarget = when {
                javaVer <= JavaVersion.VERSION_1_8 ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8
                javaVer <= JavaVersion.VERSION_11 ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                else ->
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(ktTarget)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
