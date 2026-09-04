# SolidLeaf — правила R8 для release.
# Shizuku поднимает UserService рефлексией; AIDL/Binder нельзя ужимать агрессивно.

-keepattributes SourceFile,LineNumberTable,Signature,InnerClasses,EnclosingMethod,*Annotation*
-renamesourcefileattribute SourceFile

# --- Shizuku API / Provider ---
-keep class rikka.shizuku.** { *; }
-keep class moe.shizuku.** { *; }
-dontwarn rikka.shizuku.**
-dontwarn moe.shizuku.**

# --- UserService: конструкторы и весь класс (рефлексия Shizuku) ---
-keep class com.example.re_1999_solidleaf.FileTransferUserService {
    public <init>();
    public <init>(android.content.Context);
    *;
}

# Process-FS fallback (newProcess) — не трогаем
-keep class com.example.re_1999_solidleaf.ShizukuProcessFs { *; }

# AIDL IFileTransferService + Stub/Proxy
-keep class com.example.re_1999_solidleaf.IFileTransferService { *; }
-keep class com.example.re_1999_solidleaf.IFileTransferService$* { *; }

-keep class * implements android.os.IInterface { *; }
-keep class * extends android.os.Binder { *; }
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# MainActivity / MethodChannel entry
-keep class com.example.re_1999_solidleaf.MainActivity { *; }

# Flutter embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Убираем только verbose-логи; warning/error оставляем для диагностики
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Flutter ссылается на Play Core (deferred components) — в sideload APK нет.
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
