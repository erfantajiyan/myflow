allprojects {
    repositories {
        google()
        mavenCentral()
        // آینه‌ی مخزن گوگل: در شبکه‌هایی که dl.google.com در دسترس نیست
        // (برای artifact ها ۴۰۴ می‌دهد) به عنوان fallback استفاده می‌شود.
        // با برقراری دسترسی مستقیم می‌توان این خط را حذف کرد.
        maven("https://maven.aliyun.com/repository/google")
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
