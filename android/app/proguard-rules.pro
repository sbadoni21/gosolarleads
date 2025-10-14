###############################
# Razorpay
###############################
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/
-keepclasseswithmembers class * {
    public void onPayment*(...);
}

###############################
# Firebase Authentication
###############################
# Keep all Firebase Auth classes (avoid stripping)
-keep class com.google.firebase.auth.** { *; }
-dontwarn com.google.firebase.auth.**

# Keep Google Play services auth
-keep class com.google.android.gms.internal.firebase_auth.** { *; }
-dontwarn com.google.android.gms.internal.firebase_auth.**

###############################
# Firebase Core + Utils
###############################
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

###############################
# Gson / Jackson (used internally for user/session serialization)
###############################
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep class sun.misc.Unsafe { *; }
-dontwarn sun.misc.Unsafe

###############################
# SharedPreferences / EncryptedPrefs
###############################
-keep class android.content.SharedPreferences { *; }
-keepclassmembers class android.content.SharedPreferences$Editor { *; }

###############################
# General safety for models (if you use custom user models)
###############################
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <fields>;
}
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
}
