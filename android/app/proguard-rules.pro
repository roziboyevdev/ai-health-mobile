-repackageclasses 'x'
-allowaccessmodification

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

-keep class * extends android.app.Activity
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver
-keep class * extends android.content.ContentProvider

-keep class com.veepoo.** { *; }
-keep class com.inuker.bluetooth.** { *; }
-keep class com.jieli.** { *; }

-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}
