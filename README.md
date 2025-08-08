# ALPR Watchlist (Flutter 3.32+) — Flux vidéo, multi-plaques, auto-zoom

- Flux vidéo continu avec `camera` (Camerax).
- OCR on-device via Google ML Kit (texte latin).
- Extraction de **plusieurs plaques** par frame (regex pays EU + fallback).
- Alerte si une ou plusieurs plaques matchent la **watchlist** locale.
- **Auto-zoom** heuristique basé sur la taille des boîtes détectées.
- Fonctionne hors-ligne. Android & iOS.

## Build local (Android)
1. Flutter 3.32.8 (Dart ≥ 3.5) recommandé.
2. `flutter pub get`
3. `flutter create . --platforms=android`
4. Vérifiez `android/app/build.gradle` contient `compileSdkVersion 35` (sinon, voir workflow CI ci-dessous).
5. `flutter build apk --debug`

## iOS
- `flutter create . --platforms=ios`
- Ajoutez dans `ios/Runner/Info.plist` :
  ```
  <key>NSCameraUsageDescription</key>
  <string>Utilisé pour scanner les plaques d’immatriculation.</string>
  ```
- Build depuis Xcode ou `flutter build ios`.

## CI GitHub Actions (APK auto)
- Le workflow `.github/workflows/android.yml` :
  - utilise Flutter `3.32.8`,
  - installe Android SDK **35** + build-tools 35.0.0,
  - patch `compileSdkVersion 35` (+ target 35, min 23),
  - enlève un éventuel anti-slash parasite en 1re ligne de `lib/plate_matcher.dart`,
  - build et uploade `app-debug.apk` en artefact.

## Légal
- Vérifiez la conformité (données personnelles) selon votre juridiction.
- Adaptez les regex dans `plate_matcher.dart` aux formats cibles si besoin.
