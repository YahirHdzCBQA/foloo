# google_mlkit_text_recognition references every optional script recognizer.
# Foloo ships the Latin recognizer only, so these absent optional modules must
# not prevent R8 from producing the Release APK (OCR-01, RNF-02).
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# firebase-components 16.1.0 keeps ComponentRegistrar implementations by name,
# but its consumer rule predates AGP 9 strict full-mode semantics. Registration
# is reflective, so retain only the public no-arg constructor needed to create
# ML Kit registrars and resolve SharedPrefManager (OCR-02, OCR-05, RNF-02).
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
