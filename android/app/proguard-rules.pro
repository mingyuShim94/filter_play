# ML Kit Face Detection Proguard Rules
-keep class com.google.mlkit.vision.face.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }
-keep class com.google.mlkit.common.** { *; }

# Kotlin Metadata
-keep class kotlin.Metadata { *; }
-keep class kotlin.reflect.** { *; }
-dontwarn kotlin.reflect.**

# Google ML Kit Commons
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }

# Camera Plugin
-keep class io.flutter.plugins.camera.** { *; }

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# Prevent obfuscation of injected fields
-keepclassmembers class * {
    @com.google.auto.value.AutoValue$** <fields>;
}

# Keep native method names
-keepclasseswithmembernames class * {
    native <methods>;
}

# Google Play Core (App Bundle support)
-keep class com.google.android.play.core.splitcompat.SplitCompatApplication { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }