# Google ML Kit — ComponentDiscovery 通过反射调用无参构造；R8 全量模式下会裁掉导致
# PoseRegistrar / CommonComponentRegistrar / VisionCommonRegistrar 初始化失败，
# 随后 InputImage.fromByteArray 抛 NPE（getClass on null）。
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_** { *; }
-keep class com.google.android.gms.internal.mlkit_common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.internal.mlkit_**

# 显式保留 Registrar 无参构造（ComponentDiscovery 反射入口）
-keepclassmembers class com.google.mlkit.common.internal.CommonComponentRegistrar {
    public <init>();
}
-keepclassmembers class com.google.mlkit.vision.common.internal.VisionCommonRegistrar {
    public <init>();
}
-keepclassmembers class com.google.mlkit.vision.pose.internal.PoseRegistrar {
    public <init>();
}
