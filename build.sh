#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Bu derleme macOS üzerinde çalıştırılmalıdır.' >&2
  exit 1
fi
if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo 'Apple Command Line Tools gerekiyor. Terminalde xcode-select --install çalıştırın.' >&2
  exit 2
fi
build_root="$(mktemp -d "$PWD/.meadow-build.XXXXXX")"
trap 'rm -rf "$build_root"' EXIT
app_path="$build_root/Meadow Collection.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp Resources/Info.plist "$app_path/Contents/Info.plist"
cp -R Resources/web "$app_path/Contents/Resources/web"
cp Resources/thumb.png "$app_path/Contents/Resources/thumb.png"
cp README_TR.txt "$app_path/Contents/Resources/README_TR.txt"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
build_arches="${MEADOW_ARCHS:-arm64 x86_64}"
output_slices=()
for build_arch in $build_arches; do
  case "$build_arch" in arm64|x86_64) ;; *) echo 'Geçersiz işlemci türü'; exit 1 ;; esac
  echo "Meadow Collection derleniyor: $build_arch"
  xcrun swiftc -swift-version 5 -O -sdk "$sdk_path" \
    -target "$build_arch-apple-macosx12.0" \
    -framework Cocoa -framework WebKit -framework CoreGraphics \
    Sources/main.swift -o "$build_root/Meadow-$build_arch"
  output_slices+=("$build_root/Meadow-$build_arch")
done
xcrun lipo -create "${output_slices[@]}" -output "$app_path/Contents/MacOS/MeadowCollection"
chmod +x "$app_path/Contents/MacOS/MeadowCollection"
/usr/bin/plutil -lint "$app_path/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$app_path"
/usr/bin/codesign --verify --strict "$app_path"
mkdir -p dist
if [[ -e 'dist/Meadow Collection.app' ]]; then
  echo 'dist/Meadow Collection.app zaten var. Önce mevcut uygulamayı başka yere taşıyın.' >&2
  exit 1
fi
mv "$app_path" 'dist/Meadow Collection.app'
echo "Hazır: $PWD/dist/Meadow Collection.app"
