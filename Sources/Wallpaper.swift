import AppKit
import CoreImage
import ImageIO

enum WallpaperRenderer {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func render(url: URL?, pointSize: CGSize, scale: CGFloat, dark: Bool) -> NSImage {
        let pixel = CGSize(width: max(1, pointSize.width * min(scale, 2)), height: max(1, pointSize.height * min(scale, 2)))
        let cg = renderCG(url: url, pixelSize: pixel, dark: dark)
        if let cg { return NSImage(cgImage: cg, size: pointSize) }
        let fallback = NSImage(size: pointSize)
        fallback.lockFocus()
        NSColor(calibratedWhite: dark ? 0.18 : 0.55, alpha: 1).setFill()
        NSRect(origin: .zero, size: pointSize).fill()
        fallback.unlockFocus()
        return fallback
    }

    static func renderCG(url: URL?, pixelSize: CGSize, dark: Bool) -> CGImage? {
        let width = Int(pixelSize.width.rounded())
        let height = Int(pixelSize.height.rounded())
        guard width > 0, height > 0 else { return nil }
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        var luminance: CGFloat = dark ? 0.25 : 0.6
        var drew = false
        if let url, let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary) {
            luminance = averageLuminance(image)
            if let filled = blurredFill(image, width: width, height: height) {
                ctx.draw(filled, in: CGRect(x: 0, y: 0, width: width, height: height))
                drew = true
            }
        }
        if !drew {
            let white: CGFloat = dark ? 0.2 : 0.58
            ctx.setFillColor(CGColor(gray: white, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }

        let veil = veilAlpha(luminance: luminance, dark: dark)
        ctx.setFillColor(CGColor(gray: 0, alpha: veil))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        drawVignette(ctx, width: width, height: height)
        return ctx.makeImage()
    }

    private static func veilAlpha(luminance: CGFloat, dark: Bool) -> CGFloat {
        let base: CGFloat
        if luminance > 0.75 { base = 0.34 }
        else if luminance > 0.55 { base = 0.22 }
        else if luminance > 0.32 { base = 0.14 }
        else { base = 0.08 }
        return min(0.5, base + (dark ? 0.05 : 0))
    }

    private static func blurredFill(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        let ci = CIImage(cgImage: image)
        guard ci.extent.width > 1, ci.extent.height > 1 else { return nil }
        let smallWidth: CGFloat = 760
        let smallHeight = smallWidth * (ci.extent.height / ci.extent.width)
        let down = ci.transformed(by: CGAffineTransform(
            scaleX: smallWidth / ci.extent.width,
            y: smallHeight / ci.extent.height
        ))
        let blurred = down.clampedToExtent().applyingGaussianBlur(sigma: 28).cropped(to: down.extent)
        let target = CGSize(width: width, height: height)
        let scale = max(target.width / blurred.extent.width, target.height / blurred.extent.height)
        let scaled = blurred.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let extent = scaled.extent
        let crop = CGRect(
            x: extent.midX - target.width / 2,
            y: extent.midY - target.height / 2,
            width: target.width,
            height: target.height
        )
        return context.createCGImage(scaled, from: crop)
    }

    private static func averageLuminance(_ image: CGImage) -> CGFloat {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0.5 }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let alpha = CGFloat(pixel[3]) / 255
        guard alpha > 0.01 else { return 0.5 }
        let r = CGFloat(pixel[0]) / 255 / alpha
        let g = CGFloat(pixel[1]) / 255 / alpha
        let b = CGFloat(pixel[2]) / 255 / alpha
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    private static func drawVignette(_ ctx: CGContext, width: Int, height: Int) {
        let colors = [CGColor(gray: 0, alpha: 0), CGColor(gray: 0, alpha: 0.2)] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.45, 1]) else { return }
        let center = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        let radius = max(CGFloat(width), CGFloat(height)) * 0.72
        ctx.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: radius * 0.35,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }
}
