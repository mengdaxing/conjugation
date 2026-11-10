// Prepare the selected imagegen artwork for both platforms with Core Graphics.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = project.appendingPathComponent("Design/Icon/Conjugation-icon-reference-v2.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let artwork = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let space = CGColorSpace(name: CGColorSpace.sRGB) else {
    fatalError("Cannot decode the selected icon artwork")
}

func render(size: Int, opaque: Bool = true, contentFraction: CGFloat = 1,
            drawArtwork: Bool = true, monochrome: Bool = false) -> CGImage {
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                  bytesPerRow: size * 4, space: space,
                                  bitmapInfo: alpha.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        fatalError("Cannot create icon rendering context")
    }
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    if opaque {
        context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.93, alpha: 1))
        context.fill(bounds)
    }
    if drawArtwork {
        let inset = CGFloat(size) * (1 - contentFraction) / 2
        context.interpolationQuality = .high
        context.draw(artwork, in: bounds.insetBy(dx: inset, dy: inset))
    }
    if monochrome {
        let pixels = context.data!.bindMemory(to: UInt8.self, capacity: size * size * 4)
        for pixel in 0..<(size * size) {
            let index = pixel * 4
            let alpha = Int(pixels[index + 3])
            let darkest = Int(max(pixels[index], max(pixels[index + 1], pixels[index + 2])))
            let maskAlpha = alpha > 0 && darkest * 255 < alpha * 80 ? pixels[index + 3] : 0
            pixels[index] = 0; pixels[index + 1] = 0; pixels[index + 2] = 0
            pixels[index + 3] = maskAlpha
        }
    }
    return context.makeImage()!
}

func save(_ image: CGImage, to url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Cannot write app icon: \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Failed to save app icon")
}

func generateAndroid() {
    for (density, scale) in [("mdpi", 1.0), ("hdpi", 1.5), ("xhdpi", 2.0), ("xxhdpi", 3.0), ("xxxhdpi", 4.0)] {
        let directory = project.appendingPathComponent("Android/app/src/main/res/mipmap-\(density)")
        save(render(size: Int(48 * scale)), to: directory.appendingPathComponent("ic_launcher.png"))
        let size = Int(108 * scale)
        save(render(size: size, drawArtwork: false), to: directory.appendingPathComponent("ic_launcher_background.png"))
        // Keep the mascot and its complete wordmark inside circular launcher masks.
        save(render(size: size, opaque: false, contentFraction: 56.0 / 108.0),
             to: directory.appendingPathComponent("ic_launcher_foreground.png"))
        save(render(size: size, opaque: false, contentFraction: 56.0 / 108.0, monochrome: true),
             to: directory.appendingPathComponent("ic_launcher_monochrome.png"))
    }
    print("Prepared Android legacy, adaptive and monochrome icons in five densities")
}

if CommandLine.arguments.count > 1 {
    if CommandLine.arguments[1] == "--android" {
        generateAndroid()
    } else {
        save(render(size: 1024), to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("Prepared iOS icon: 1024 x 1024, sRGB, opaque")
    }
} else {
    save(render(size: 1024), to: project.appendingPathComponent("Conjugation/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
    let darwin = project.appendingPathComponent("Darwin/Assets.xcassets/AppIcon.appiconset")
    let catalog = try! JSONSerialization.jsonObject(with: Data(contentsOf: darwin.appendingPathComponent("Contents.json"))) as! [String: Any]
    for item in catalog["images"] as! [[String: Any]] {
        guard let filename = item["filename"] as? String,
              let dimensions = item["size"] as? String,
              let scale = item["scale"] as? String,
              let points = Double(dimensions.components(separatedBy: "x")[0]),
              let multiplier = Double(scale.replacingOccurrences(of: "x", with: "")) else { continue }
        save(render(size: Int((points * multiplier).rounded())), to: darwin.appendingPathComponent(filename))
    }
    generateAndroid()
    print("Prepared iOS and Darwin asset catalogs")
}
