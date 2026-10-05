# MacTodo

Microsoft To Do benzeri, arka planı değiştirilebilen native macOS (SwiftUI) yapılacaklar uygulaması.

## Özellikler

- **Akıllı listeler:** Günüm, Önemli, Planlanan, Görevler
- **Günüm iki sekmeli:** *Günüm* ve *Nice to have* (adını başlığa tıklayıp değiştirebilirsin). Görevler sen kaldırana kadar Günüm'de kalır; sağ tık ya da detay panelinden sekmeler arasında taşınır.
- **Kendi listelerin:** oluştur, başlığa tıklayıp yeniden adlandır, sürükleyerek sırala, sağ tıkla sil
- **Görevler:** tamamla, yıldızla, Günüm'e ekle, son tarih, alt adımlar, notlar, başka listeye taşı
- **Arka plan:** her liste için ayrı; 10 hazır tema veya kendi resmin
  - Araç çubuğundaki 🎨 düğmesi → tema seç ya da "Resim seç…"
  - Ya da bir resmi doğrudan pencereye sürükleyip bırak
- **Menü rengi:** sol menünün altındaki 🖌 düğmesiyle hazır renk, özel renk ya da varsayılan
- Veriler otomatik kaydedilir: `~/Library/Application Support/MacTodo/`

## Gereksinimler

- macOS 14+
- Xcode (lisansı kabul edilmiş olmalı: `sudo xcodebuild -license accept`)

## Çalıştırma

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift run
```

veya `Package.swift` dosyasını Xcode ile açıp ▶︎ Run.

## .app olarak paketleme

```sh
./scripts/build-app.sh
cp -R build/MacTodo.app /Applications/
```

## Kısayollar

- `⇧⌘L` — Yeni liste
- `Enter` — Görev / adım ekle
