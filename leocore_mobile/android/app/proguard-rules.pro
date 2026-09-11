# R8 / ProGuard keep rules for LeoCore ERP release builds.
# Flutter's engine rules are applied automatically; these cover the plugins
# that use reflection / native entry points, so R8 doesn't strip them.

# ── Flutter ────────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Google Play In-App Update / Review (Play Core) ──────────────────────────
# in_app_update + in_app_review use Play Core; R8 otherwise warns on missing
# split-install / deferred-component classes.
-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ── ML Kit barcode scanning (mobile_scanner) ────────────────────────────────
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# ── CameraX (mobile_scanner / camera) ───────────────────────────────────────
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ── Document scanner (cunning_document_scanner) ─────────────────────────────
-keep class biz.cunning.cunning_document_scanner.** { *; }
-dontwarn biz.cunning.cunning_document_scanner.**

# ── Keep attributes needed for reflection / serialization ───────────────────
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod, Exceptions

# ── Silence warnings from optional/transitive deps ──────────────────────────
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
