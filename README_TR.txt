MEADOW COLLECTION — MAC UYARLAMASI / DENEME PAKETİ
================================================

ÖNEMLİ DURUM
Bu paket macOS uygulamasının kaynaklarını ve Mac üzerinde uygulamayı oluşturan
başlatıcıyı içerir. Hazır, derlenmiş veya noter onaylı bir .app/.dmg değildir.
Bu ortamda macOS bulunmadığından Swift/AppKit derlemesi ve gerçek Mac masaüstü
testi yapılamadı. macOS 12 ve üzeri hedeflendi. Gerçek uyumluluk Mac'te denenecek.
Derleme betiği Intel ve Apple Silicon için Universal uygulama oluşturur.

MAC'TE BAŞLATMA
1. ZIP'i Mac'e indirin ve tamamen çıkarın.
2. Meadow-Mac klasöründeki MAC-ICIN-BASLAT.command dosyasını açın.
3. Apple Command Line Tools kurulu değilse Apple'ın yükleme penceresi açılır.
   Yüklemeyi bitirin, sonra aynı .command dosyasını tekrar açın.
   Tam Xcode projesi oluşturmanız veya npm kurmanız gerekmez.
4. Derleme tamamlanınca uygulama açılır; üst menüde yaprak simgesi görünür.
5. dist klasöründeki Meadow Collection.app dosyasını Uygulamalar'a taşıyın.
   Sonraki kullanımlarda doğrudan bu uygulamayı açın.

.command açma izni yoksa Terminal'e şu metni yazıp sonuna dosyayı sürükleyin:
  bash 
Ardından Enter'a basın. Bu, aynı başlatıcıyı Terminal ile çalıştırır.
macOS bir güvenlik uyarısı verirse sistemin ilgili dosya için sunduğu Aç /
Gizlilik ve Güvenlik > Yine de Aç seçeneğini kullanın; sistem korumasını kapatmayın.

SAHNELER (paketteki gerçek içerik)
- Meadow Hill / Çimen Tepesi
- Snow Cabin / Karlı Dağ Evi
- Lake House / Göl Evi
- Wheat Field / Buğday Tarlası
- Sakura Lake / Sakura Gölü
Orijinal README'deki Sonbahar sahnesi listesi eskiydi; çalışır bundle'da onun
yerine Buğday Tarlası var. Sahne geometrileri ve shader görselleri korunmuştur.

KULLANIM
- Yaprak menüsü: sahne, günün saati, kalite, FPS, otomatik etkileşim.
- Otomatik saat, bilgisayarın yerel saatini izler; gerçek konuma dayalı astronomik
  gün doğumu/gün batımı hesaplaması değildir.
- Varsayılan: dengeli kalite, 30 FPS, menü çubuğu bulunan ana ekran.
- Tüm ekranlar seçeneği her ekran için ayrı sahne açar; güç tüketimini artırır.
- Masaüstü modunda pencereler/simgeler normal kullanılabilir. Fare hareketi
  çim/su gibi efektleri etkiler. Tıklama Finder'a gider.
- Sakura tıklaması gibi efektleri denemek için Önizleme'yi açın.
- Önizlemeden dönüş de yaprak menüsündeki Masaüstüne dön seçeneğidir.
- Duraklat komutu görüntüyü dondurur. Sistem uyku/ekran uyku/oturum pasifleşme
  bildirimlerinde de duraklatma istenir.
- Çıkış, uygulama pencerelerini kapatır; normal duvar kâğıdı yeniden görünür.
- Açılışta çalıştırma isterseniz macOS Oturum Açma Öğeleri'ne uygulamayı ekleyin.
- Kaynaklar yereldir; sahneler çalışırken CDN, hesap veya internet gerekmez.

SORUN GİDERME
Siyah ekran: İlk sahne hazırlanırken bekleyin. Menüden Önizleme açın.
Hata ayrıntıları çıkarsa metnini iletin. Ardından Düşük kalite ve Yeniden yükle
seçeneklerini deneyin. Intel Mac'lerde Düşük / 30 FPS ile başlayın.
macOS sürümü, işlemci ve ekran sayısını hata raporuna ekleyin.
Görüntü üretilemezse bir kez düşük kalite/güvenli modla yeniden denenir.

Bilinen sınırlar:
- Native derleme, GPU/Metal-WebGL davranışı, Finder simge katmanı, Mission
  Control, Stage Manager, çoklu ekran ve uyku dönüşü gerçek Mac'te doğrulanmadı.
- Başka bir pencere tüm ekranı kapladığında otomatik duraklatma eklenmedi.
- Kilit ekranı/ekran koruyucu değildir; macOS duvar kâğıdı ayarına video kurmaz.
- Apple Developer sertifikası ve noter onayı yok; mağazaya hazır ürün değildir.
- Varsayılan kalite/FPS bir hedeftir; tüm donanımlarda bu hız garanti edilmez.

GELİŞTİRİCİ
Sources/main.swift: AppKit + WKWebView yerel masaüstü kabuğu.
Resources/web: Kullanıcının özgün 3D sahneleri + macOS kontrol köprüsü.
bash build.sh: Universal .app oluşturur; mevcut dist uygulamasının üzerine yazmaz.
MEADOW_ARCHS=arm64 bash build.sh: yalnızca Apple Silicon.
MEADOW_ARCHS=x86_64 bash build.sh: yalnızca Intel.
Yerel ad-hoc imza derleme sırasında uygulanır; Developer ID imzası değildir.
Dağıtım için Developer ID imzalama/notarizasyon ayrıca yapılmalıdır.

Dayanak Apple API belgeleri:
https://developer.apple.com/documentation/webkit/wkwebview/loadfileurl(_:allowingreadaccessto:)
https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct
https://developer.apple.com/documentation/foundation/processinfo/activityoptions/userinitiatedallowingidlesystemsleep
