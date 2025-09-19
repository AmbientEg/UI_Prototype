import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Configure missing namespace for certain Android library plugins (AGP 8+ requirement)
subprojects {
    if (name == "flutter_beacon") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "com.umbrall.flutter_beacon"
            }
            // Remove deprecated package attribute from plugin manifest (AGP 8+)
            afterEvaluate {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val original = manifestFile.readText()
                    val cleaned = original.replace(Regex("\\s*package=\"[^\"]+\""), "")
                    if (cleaned != original) {
                        manifestFile.writeText(cleaned)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
