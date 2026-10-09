#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
trap 'code=$?; if [[ $code -ne 0 ]]; then echo; echo "İşlem tamamlanamadı. Ekrandaki hatanın fotoğrafını gönderin."; read -r -p "Kapatmak için Enter… " reply || true; fi' EXIT
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Bu dosya Mac üzerinde açılmalıdır.'
  exit 1
fi
if [[ -d 'dist/Meadow Collection.app' ]]; then
  open 'dist/Meadow Collection.app'
  exit 0
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'İlk kurulum için Apple Command Line Tools gerekiyor.'
  echo 'Açılan Apple penceresinde Yükle seçeneğini seçin.'
  echo 'Kurulum bittikten sonra bu dosyayı tekrar açın.'
  xcode-select --install || true
  read -r -p 'Kapatmak için Enter… ' reply || true
  exit 0
fi
bash build.sh
echo 'Uygulama açılıyor. Ekranın üst menüsündeki yaprak simgesine tıklayın.'
echo 'Kalıcı kullanım için dist içindeki Meadow Collection uygulamasını Uygulamalar klasörüne taşıyabilirsiniz.'
open 'dist/Meadow Collection.app'
open -R 'dist/Meadow Collection.app'
