#################################################
#          LAPORAN HAFALAN PROGUARD             #
#################################################

############################
# Flutter Core
############################
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }
-dontwarn io.flutter.**

############################
# MainActivity
############################
-keep class com.mirailabs.quran_report.MainActivity { *; }

############################
# AndroidX
############################
-keep class androidx.core.** { *; }
-keep class androidx.activity.** { *; }
-keep class androidx.lifecycle.** { *; }
-keep class androidx.annotation.Keep

############################
# Material Design
############################
-keep class com.google.android.material.** { *; }
-dontwarn com.google.android.material.**

############################
# Kotlin
############################
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**
-dontwarn org.jetbrains.annotations.**

############################
# Hive (local storage)
############################
-keep class hive.** { *; }
-dontwarn hive.**

############################
# Share Plus / URL Launcher / Path Provider
############################
-keep class io.flutter.plugins.share.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

############################
# Shared Preferences
############################
-keep class io.flutter.plugins.sharedpreferences.** { *; }

############################
# PDF / Printing plugin
############################
-keep class net.nfet.flutter.printing.** { *; }
-dontwarn net.nfet.flutter.printing.**

############################
# Enum (dipakai model SantriRecord)
############################
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

############################
# Keep Source Mapping
############################
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes *Annotation*

############################
# Ignore Warnings (transitive libs)
############################
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn okhttp3.**
-dontwarn okio.**
