// Uygulama ikonunu çizer: swift scripts/make-icon.swift <çıktı.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// macOS ikon ızgarası: 1024'lük tuvalde 824'lük yuvarlatılmış kare.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

// Gölge
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
color(0x2F80ED).setFill()
tilePath.fill()
ctx.restoreGState()

// Arka plan gradyanı
ctx.saveGState()
tilePath.addClip()
NSGradient(colors: [color(0x56CCF2), color(0x2F80ED), color(0x3B4FD8)], atLocations: [0, 0.55, 1],
           colorSpace: .sRGB)!.draw(in: tile, angle: -60)

// Sağ üstte güneş (Günüm)
let sunCenter = CGPoint(x: 772, y: 772)
NSGradient(colors: [color(0xFFE29A), color(0xFFB347)])!
    .draw(in: NSBezierPath(ovalIn: CGRect(x: sunCenter.x - 72, y: sunCenter.y - 72, width: 144, height: 144)),
          relativeCenterPosition: NSPoint(x: -0.3, y: 0.3))

// Hafif parlama
NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!
    .draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
ctx.restoreGState()

// Görev kartı
let card = CGRect(x: 282, y: 232, width: 460, height: 460)
let cardPath = NSBezierPath(roundedRect: card, xRadius: 96, yRadius: 96)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setFill()
cardPath.fill()
ctx.restoreGState()

// Onay işareti
let check = NSBezierPath()
check.move(to: CGPoint(x: 392, y: 470))
check.line(to: CGPoint(x: 478, y: 384))
check.line(to: CGPoint(x: 632, y: 548))
check.lineWidth = 60
check.lineCapStyle = .round
check.lineJoinStyle = .round
color(0x2F80ED).setStroke()
check.stroke()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("İkon yazıldı: \(output)")
