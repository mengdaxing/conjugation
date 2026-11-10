// Check actual source and compiled pixels, not just PNG dimensions or file existence.
import Foundation
import CoreGraphics
import ImageIO

precondition(CommandLine.arguments.count > 1, "Pass one or more PNG paths")
for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          let context = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8,
                                  bytesPerRow: 256, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        fatalError("Cannot read icon: \(path)")
    }
    precondition(image.width == image.height && image.width >= 60, "Invalid icon dimensions")
    precondition([CGImageAlphaInfo.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo), "App icons must be opaque")
    context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
    let pixels = context.data!.bindMemory(to: UInt8.self, capacity: 64 * 64 * 4)
    var sum = 0.0, sumSquared = 0.0, white = 0, blue = 0, red = 0
    for pixel in 0..<(64 * 64) {
        let r = Double(pixels[pixel * 4]) / 255
        let g = Double(pixels[pixel * 4 + 1]) / 255
        let b = Double(pixels[pixel * 4 + 2]) / 255
        let luminance = (r + g + b) / 3
        sum += luminance; sumSquared += luminance * luminance
        if r > 0.78 && g > 0.78 && b > 0.78 { white += 1 }
        if b > 0.5 && b > r * 1.5 && b > g * 1.2 { blue += 1 }
        if r > 0.6 && r > g * 1.5 && r > b * 1.5 { red += 1 }
    }
    let count = Double(64 * 64), mean = sum / count
    let variance = sumSquared / count - mean * mean
    precondition(mean > 0.18 && variance > 0.005, "Icon is black, blank, or has insufficient contrast: \(path)")
    precondition(Double(white) / count > 0.15 && Double(blue) / count > 0.06 && Double(red) / count > 0.06,
                 "Expected blue, white and red mascot icon: \(path)")
    print("Icon verified: \(image.width)x\(image.height), opaque, visible French tricolor mascot: \(path)")
}
