#!/bin/bash
set -e

echo "🔧 Téléchargement HERE SDK..."

# Variables
HERE_SDK_VERSION="4.22.0.0"  # Version mise à jour
SDK_DIR="plugins/here_sdk"   # Structure correcte

# Créer la structure de dossiers
mkdir -p plugins

# Télécharger depuis les releases GitHub officielle
echo "📦 Téléchargement depuis GitHub releases..."
wget -O here_sdk.tar.gz \
  "https://github.com/heremaps/here-sdk-ref-app-flutter/archive/refs/tags/1.14.0.zip"

echo "📂 Extraction du SDK..."
mkdir -p $SDK_DIR
tar -xzf here_sdk.tar.gz -C $SDK_DIR --strip-components=1

echo "🧹 Nettoyage..."
rm here_sdk.tar.gz

echo "✅ HERE SDK installé dans $SDK_DIR"
