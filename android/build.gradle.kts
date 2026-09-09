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

// Flutter's integration_test plugin requests androidx.test:runner:1.2+.
// Dynamic versions query every repo's maven-metadata.xml; a Maven Central
// TLS/404 flake then fails the whole resolve even when Google Maven has it.
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "androidx.test" && requested.name == "runner") {
                useVersion("1.5.2")
                because("pin past dynamic 1.2+ metadata fetch")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
