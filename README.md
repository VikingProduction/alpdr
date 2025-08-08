# ALPR Watchlist (Flutter)

Application Flutter (Android + iOS) qui utilise la caméra pour lire des plaques d’immatriculation via OCR (Google ML Kit), compare chaque plaque à une watchlist locale et affiche une alerte en cas de correspondance.

## Contenu
- `lib/` : code source complet (scanner, OCR, watchlist, UI)
- `.github/workflows/android.yml` : CI GitHub Actions pour générer automatiquement un APK **debug** (Android)
- `scripts/` : scripts utilitaires (facultatifs)

## Build local (Android)
1. Installer Flutter (3.22+), Android SDK.
2. Dans ce dossier :
   ```
   flutter pub get
   flutter create . --platforms=android
   # Injecte la permission caméra si nécessaire (normalement le workflow le fait en CI)
   sed -i '/<application/ i \    <uses-permission android:name="android.permission.CAMERA" />\n    <uses-feature android:name="android.hardware.camera" />\n    <uses-feature android:name="android.hardware.camera.autofocus" />' android/app/src/main/AndroidManifest.xml
   flutter build apk --debug
   ```
   APK: `build/app/outputs/flutter-apk/app-debug.apk`

## CI GitHub Actions (APK auto)
1. Poussez ce dépôt sur GitHub.
2. Ouvrez l’onglet **Actions** > lancez le workflow **Android APK**.
3. Téléchargez l’artefact `alpr-watchlist-debug-apk`.

## iOS (optionnel)
- Créez les plateformes localement : `flutter create . --platforms=ios`
- Ajoutez dans `ios/Runner/Info.plist` :
  ```
  <key>NSCameraUsageDescription</key>
  <string>Utilisé pour scanner les plaques d’immatriculation.</string>
  ```
- Build depuis Xcode ou `flutter build ios`.

## Disclaimer
- Vérifiez la conformité légale (données personnelles) selon votre juridiction.
- L’OCR est sensible à la lumière, l’angle et l’état de la plaque. Ajustez `kPlatePatterns` si nécessaire.
