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
    // Unified Java/Kotlin JVM target at configuration time, BEFORE any plugin
    // finalizes compileOptions. The FlutterFire plugins read rootProject.ext.javaVersion
    // from their local-config.gradle, so publishing it here avoids per-plugin overrides.
    rootProject.ext["javaVersion"] = JavaVersion.VERSION_17
    plugins.withId("com.android.library") {
        plugins.apply("org.jetbrains.kotlin.android")
    }
    // Mirror each plugin's own finalized Java compileOptions target for its
    // KotlinCompile tasks, so Java and Kotlin always agree. The lambda reads
    // the extension lazily per task, AFTER the plugin script has finalized
    // compileOptions (reading finalized values is allowed; only writes fail).
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        val javaTarget = project.extensions
            .findByType<com.android.build.api.dsl.LibraryExtension>()
            ?.compileOptions?.targetCompatibility
            ?: JavaVersion.VERSION_17
        compilerOptions.jvmTarget.set(
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget.toString())
        )
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
