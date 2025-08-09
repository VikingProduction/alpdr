#!/bin/bash
set -e

echo "🔧 Téléchargement HERE SDK..."

# Variables
HERE_SDK_VERSION="4.17.0"
HERE_SDK_URL="https://developer.here.com/downloads/here-sdk-flutter-${HERE_SDK_VERSION}.tar.gz"
SDK_DIR="here_sdk"

# Créer le dossier
mkdir -p $SDK_DIR

# Télécharger et extraire
echo "📦 Téléchargement depuis HERE..."
curl -L -o here_sdk.tar.gz "$HERE_SDK_URL" \
  --header "Authorization: Bearer $HERE_DOWNLOAD_TOKEN" \
  --fail

echo "📂 Extraction du SDK..."
tar -xzf here_sdk.tar.gz -C $SDK_DIR --strip-components=1

echo "🧹 Nettoyage..."
rm here_sdk.tar.gz

echo "✅ HERE SDK installé dans $SDK_DIR"
