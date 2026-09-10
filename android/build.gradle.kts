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

// 统一强制所有插件模块 compileSdk=36，规避 file_picker 等
// 旧插件编译在 android-34 导致的 AAR metadata 校验失败。
// 注意：:app 已被 evaluationDependsOn 提前求值，需判断 state.executed。
subprojects {
    fun forceCompileSdk() {
        val android = extensions.findByName("android") ?: return
        runCatching {
            android.javaClass.getMethod("setCompileSdk", Int::class.java)
                .invoke(android, 36)
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
