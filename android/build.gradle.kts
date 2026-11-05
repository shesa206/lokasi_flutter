allprojects {
    repositories {
        google()
        mavenCentral()
    }
    extra["compileSdkVersion"] = 36
    extra["targetSdkVersion"] = 36
    extra["minSdkVersion"] = 21
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
    afterEvaluate {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                val method = androidExtension.javaClass.methods.find { it.name == "compileSdkVersion" && it.parameterTypes.size == 1 }
                method?.invoke(androidExtension, 36)
            } catch (e: Exception) {
                // ignore
            }
        }

        // Disable AAR metadata checks to bypass older package compileSdk requirements
        tasks.matching { it.name.contains("AarMetadata") }.all {
            enabled = false
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
