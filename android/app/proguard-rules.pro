-keepattributes *Annotation*
-keep @interface dart.vm.EntryPoint
-keepclassmembers class * {
    @dart.vm.EntryPoint <methods>;
}
