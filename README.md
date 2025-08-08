# ALPR Watchlist — Dernières versions (Flutter 3.32.8 / Dart >= 3.5)

- Flux vidéo continu (camera ^0.11.x), multi-plaques, auto-zoom.
- OCR on-device via Google ML Kit (google_mlkit_text_recognition ^0.15.x).
- Watchlist locale (shared_preferences ^2.3.x).
- CI incluse: Android SDK 35 + patch compileSdk 35, build APK.

## Démarrage rapide
```
flutter pub get
flutter create . --platforms=android
flutter build apk --debug
```
Artefact CI: onglet **Actions** -> téléchargement `app-debug.apk`.
