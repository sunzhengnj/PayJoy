import AppKit

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let root = cwd.appendingPathComponent("marketing/xiaohongshu")
let screens = root.appendingPathComponent("app-screens")

let ink = NSColor(calibratedRed: 0.07, green: 0.065, blue: 0.055, alpha: 1)
let cream = NSColor(calibratedRed: 0.985, green: 0.965, blue: 0.915, alpha: 1)
let yellow = NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.22, alpha: 1)
let navy = NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.27, alpha: 1)
let blue = NSColor(calibratedRed: 0.18, green: 0.45, blue: 0.65, alpha: 1)

let icon = NSImage(contentsOf: cwd.appendingPathComponent("PayJoy/Resources/app_icon_selected_preview.png"))!
let loungeWorker = NSImage(contentsOf: cwd.appendingPathComponent("PayJoy/Resources/moyu_chair_worker_redraw_v1.png"))!

func font(_ name: String, _ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: weight)
}

func drawText(_ text: String, in rect: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor, lineSpacing: CGFloat = 0) {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.lineSpacing = lineSpacing
    (text as NSString).draw(in: rect, withAttributes: [
        .font: font(weight == .black ? "PingFangSC-Heavy" : "PingFangSC-Medium", size, weight),
        .foregroundColor: color,
        .paragraphStyle: style,
    ])
}

func drawBrand(index: Int, color: NSColor) {
    let iconRect = NSRect(x: 68, y: 1330, width: 48, height: 48)
    let clip = NSBezierPath(roundedRect: iconRect, xRadius: 11, yRadius: 11)
    NSGraphicsContext.saveGraphicsState()
    clip.addClip()
    icon.draw(in: iconRect, from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    drawText("开薪", in: NSRect(x: 130, y: 1338, width: 120, height: 36), size: 25, weight: .semibold, color: color)
    drawText(String(format: "%02d  /  04", index), in: NSRect(x: 882, y: 1340, width: 130, height: 32), size: 19, weight: .medium, color: color.withAlphaComponent(0.55))
}

func drawHeader(title: String, subtitle: String, color: NSColor) {
    drawText(title, in: NSRect(x: 68, y: 1150, width: 930, height: 160), size: 56, weight: .black, color: color, lineSpacing: 4)
    let line = NSBezierPath(roundedRect: NSRect(x: 70, y: 1122, width: 72, height: 7), xRadius: 3.5, yRadius: 3.5)
    yellow.setFill()
    line.fill()
    drawText(subtitle, in: NSRect(x: 68, y: 1066, width: 930, height: 42), size: 25, weight: .medium, color: color.withAlphaComponent(0.82))
}

func drawSoftBlob(_ rect: NSRect, color: NSColor) {
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
}

func drawProductImage(_ image: NSImage, sourceRect: NSRect, targetRect: NSRect, radius: CGFloat) {
    let sourceRatio = sourceRect.width / sourceRect.height
    let targetRatio = targetRect.width / targetRect.height
    precondition(abs(sourceRatio - targetRatio) < 0.002, "Source and target ratios must match")

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()

    let shape = NSBezierPath(roundedRect: targetRect, xRadius: radius, yRadius: radius)
    NSColor.white.setFill()
    shape.fill()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    image.draw(in: targetRect, from: sourceRect, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 0.2, alpha: 0.22).setStroke()
    shape.lineWidth = 1.5
    shape.stroke()
}

func topCrop(_ image: NSImage, height: CGFloat) -> NSRect {
    let cropHeight = min(height, image.size.height)
    return NSRect(x: 0, y: image.size.height - cropHeight, width: image.size.width, height: cropHeight)
}

func makeCanvas(background: NSColor, draw: () -> Void) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1080,
        pixelsHigh: 1440,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high
    background.setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1080, height: 1440)).fill()
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func write(_ bitmap: NSBitmapImageRep, name: String) throws {
    let data = bitmap.representation(using: .png, properties: [:])!
    try data.write(to: root.appendingPathComponent(name), options: .atomic)
}

let home = NSImage(contentsOf: screens.appendingPathComponent("home.png"))!
let widgets = NSImage(contentsOf: screens.appendingPathComponent("widgets.png"))!
let wish = NSImage(contentsOf: screens.appendingPathComponent("wish-tab.png"))!
let daily = NSImage(contentsOf: screens.appendingPathComponent("daily-report.png"))!

try write(makeCanvas(background: cream) {
    drawSoftBlob(NSRect(x: 125, y: 40, width: 830, height: 830), color: yellow.withAlphaComponent(0.38))
    drawSoftBlob(NSRect(x: 690, y: 705, width: 300, height: 300), color: blue.withAlphaComponent(0.10))
    drawBrand(index: 1, color: ink)
    drawHeader(title: "上班这件事，\n终于有了进度条", subtitle: "每一秒都算数，离下班也越来越近。", color: ink)
    let height: CGFloat = 1120
    let width = height * home.size.width / home.size.height
    drawProductImage(home, sourceRect: NSRect(origin: .zero, size: home.size), targetRect: NSRect(x: (1080 - width) / 2, y: -82, width: width, height: height), radius: 58)
}, name: "01-cover-office-companion.png")

try write(makeCanvas(background: navy) {
    drawSoftBlob(NSRect(x: 165, y: 120, width: 750, height: 750), color: yellow.withAlphaComponent(0.18))
    drawBrand(index: 2, color: cream)
    drawHeader(title: "不用反复点开，\n抬眼就知道还有多久", subtitle: "桌面、锁屏和灵动岛，陪你一起倒数。", color: cream)
    let source = topCrop(widgets, height: 1450)
    let width: CGFloat = 820
    let height = width * source.height / source.width
    drawProductImage(widgets, sourceRect: source, targetRect: NSRect(x: 130, y: 45, width: width, height: height), radius: 44)
}, name: "02-lockscreen-countdown.png")

try write(makeCanvas(background: cream) {
    drawSoftBlob(NSRect(x: 80, y: 115, width: 920, height: 700), color: blue.withAlphaComponent(0.13))
    drawSoftBlob(NSRect(x: 720, y: 760, width: 250, height: 250), color: yellow.withAlphaComponent(0.22))
    drawBrand(index: 3, color: ink)
    drawHeader(title: "把想去的地方，\n放进今天的进度里", subtitle: "普通的一天，也在悄悄靠近愿望。", color: ink)
    let height: CGFloat = 1115
    let width = height * wish.size.width / wish.size.height
    drawProductImage(wish, sourceRect: NSRect(origin: .zero, size: wish.size), targetRect: NSRect(x: (1080 - width) / 2, y: -82, width: width, height: height), radius: 58)
}, name: "03-wish-progress.png")

try write(makeCanvas(background: NSColor(calibratedRed: 1.0, green: 0.945, blue: 0.75, alpha: 1)) {
    drawBrand(index: 4, color: ink)
    drawHeader(title: "今日份班，\n平安收工", subtitle: "给认真过完的这一天，一个小小句号。", color: ink)
    let source = topCrop(daily, height: 720)
    let width: CGFloat = 900
    let height = width * source.height / source.width
    drawProductImage(daily, sourceRect: source, targetRect: NSRect(x: 90, y: 490, width: width, height: height), radius: 38)
    loungeWorker.draw(in: NSRect(x: 330, y: 38, width: 420, height: 384), from: .zero, operation: .sourceOver, fraction: 1)
}, name: "04-after-work-relief.png")
