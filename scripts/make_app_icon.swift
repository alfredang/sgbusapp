// Generates a 1024x1024 App Store icon for SG Bus Live: a clean side-view bus
// (white) on a green gradient, with windows, wheels, a route sign and motion lines.
// Usage: swift scripts/make_app_icon.swift <out.png>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let S = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("ctx")
}
func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r/255), CGFloat(g/255), CGFloat(b/255), CGFloat(a)])!
}
func rrect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ r: Double) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

// Background: green gradient (brand green)
let grad = CGGradient(colorsSpace: cs, colors: [rgb(22,160,90), rgb(11,92,60)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

let navy = rgb(21, 34, 51)
let white = rgb(255, 255, 255)
let windowBlue = rgb(120, 196, 236)

// ---- Bus body (side view) ----
let bx = 168.0, by = 360.0, bw = 688.0, bh = 320.0
ctx.addPath(rrect(bx, by, bw, bh, 64)); ctx.setFillColor(white); ctx.fillPath()

// Roof sign / route board (dark) near top-left
ctx.addPath(rrect(bx + 40, by + bh - 92, 250, 64, 16)); ctx.setFillColor(navy); ctx.fillPath()

// Windows row (blue, rounded)
let winY = by + 150.0, winH = 104.0, winW = 120.0, gap = 26.0
var wx = bx + 40
for _ in 0..<4 {
    ctx.addPath(rrect(wx, winY, winW, winH, 18)); ctx.setFillColor(windowBlue); ctx.fillPath()
    wx += winW + gap
}

// Lower accent stripe (green) along the body
ctx.addPath(rrect(bx, by + 44, bw, 40, 8)); ctx.setFillColor(rgb(22,160,90)); ctx.fillPath()

// Headlight (amber) front-right
ctx.addPath(CGPath(ellipseIn: CGRect(x: bx + bw - 52, y: by + 30, width: 34, height: 34), transform: nil))
ctx.setFillColor(rgb(245, 180, 60)); ctx.fillPath()

// ---- Wheels ----
func wheel(_ cxp: Double) {
    let r = 78.0, cyp = by - 8.0
    ctx.addPath(CGPath(ellipseIn: CGRect(x: cxp - r, y: cyp - r, width: 2*r, height: 2*r), transform: nil))
    ctx.setFillColor(navy); ctx.fillPath()
    let ir = 34.0
    ctx.addPath(CGPath(ellipseIn: CGRect(x: cxp - ir, y: cyp - ir, width: 2*ir, height: 2*ir), transform: nil))
    ctx.setFillColor(rgb(200, 210, 220)); ctx.fillPath()
}
wheel(bx + 168)
wheel(bx + bw - 168)

// ---- Motion lines (brand colors) behind the bus ----
let lineColors = [rgb(232, 150, 40), rgb(40, 90, 200), rgb(60, 160, 90)]
var ly = by + bh - 70
for c in lineColors {
    ctx.setStrokeColor(c); ctx.setLineWidth(26); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 60, y: ly)); ctx.addLine(to: CGPoint(x: 150, y: ly)); ctx.strokePath()
    ly -= 60
}

guard let img = ctx.makeImage() else { fatalError("img") }
let url = URL(fileURLWithPath: outPath)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
