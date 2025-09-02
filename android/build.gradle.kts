buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.7.3") // AGP version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0") // Kotlin plugin version
        // Add other classpaths here (e.g., Firebase, Hilt)
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: Custom build directory (only use if needed)
val customBuildDir = layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(customBuildDir)

subprojects {
    // Ensure app project is evaluated first
    evaluationDependsOn(":app")
    
    // Optional: Set per-subproject build dirs
    layout.buildDirectory.set(customBuildDir.dir(project.name))
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}