# Meadow Collection — macOS

Kullanıcının beş Three.js canlı duvar kâğıdı için AppKit + WKWebView uyarlaması.

## GitHub'da derleme

Bu klasörün **içeriği** deponun köküne yerleştirilmelidir. Kök dizinde `build.sh`,
`Sources/`, `Resources/`, `Tests/` ve `.github/workflows/macos-build.yml` bulunur.

`main` dalına ilk yükleme Mac derlemesini otomatik başlatır. Daha sonra
**Actions → Meadow Mac Build → Run workflow** ile tekrar çalıştırabilirsiniz.

İki iş çalışır: Apple Silicon ve Intel macOS. Her biri iki işlemci türünü de
barındıran Universal `.app` oluşturur. Başarılı işin **Artifacts** bölümünden
`Meadow-Mac-Universal-built-on-Apple-Silicon` veya Intel karşılığını indirin.
Dış ZIP'in içindeki `Meadow-Collection-Universal.zip` dosyasını da çıkarın.

## Testin sınırı

Derleme + kontrol köprüsü + paket/imza kontrolleri yapılır. Henüz gerçek Mac'te
masaüstü/GPU görsel testi yapılmadı. Başarılı Actions sonucu tüm grafiklerin veya
Finder/Spaces/Stage Manager davranışının doğrulandığı anlamına gelmez.

Uygulama ad-hoc imzalıdır; Apple noter onayı ve Developer ID imzası yoktur.

## Yerel kullanım

Mac üzerinde `MAC-ICIN-BASLAT.command` dosyasını açın veya `bash build.sh`
çalıştırın. Ayrıntılar `README_TR.txt` dosyasında.

## İçerik

Çimen Tepesi · Karlı Dağ Evi · Göl Evi · Buğday Tarlası · Sakura Gölü.
Varsayılan: dengeli kalite, 30 FPS, ana ekran, otomatik günün saati.
