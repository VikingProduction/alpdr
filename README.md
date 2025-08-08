# ALPR Watchlist (Flutter 3.22.x / Dart 3.4.x compatible)

- Flux vidéo continu (throttle ~2 fps) avec `camera 0.10.5+9` (pin).
- OCR on-device via Google ML Kit.
- Multi-plaques par frame + auto-zoom heuristique.
- CI fournie pour Android SDK 35 + patch compileSdk 35.

Si vous passez à Flutter 3.32+, utilisez la variante plus récente (Dart >=3.5, camera ^0.11.x) et retirez les overrides.
