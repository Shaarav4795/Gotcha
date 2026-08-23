import UIKit

enum ImageProcessor {
    private static let imageCache = NSCache<NSData, UIImage>()

    private static let croppedCache = NSCache<CropCacheKey, UIImage>()

    static func uiImage(for data: Data) -> UIImage? {
        let key = data as NSData
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }
        imageCache.setObject(image, forKey: key)
        return image
    }

    static func croppedImage(for data: Data, ratio: CGFloat) -> UIImage? {
        let key = CropCacheKey(data, ratio)
        if let cached = croppedCache.object(forKey: key) { return cached }
        guard let image = uiImage(for: data),
              let cropped = cropped(image: image, ratio: ratio) else { return nil }
        croppedCache.setObject(cropped, forKey: key)
        return cropped
    }

    static func normalizedJPEG(from image: UIImage,
                               maxDimension: CGFloat = 1600) -> Data? {
        let normalized: UIImage
        if image.imageOrientation == .up, image.scale == 1 {
            normalized = image
        } else {
            let renderer = UIGraphicsImageRenderer(size: image.size)
            normalized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }

        guard let cgImage = normalized.cgImage else { return nil }

        let size = normalized.size
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }

    private static func cropped(image: UIImage, ratio: CGFloat) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let pixelW = CGFloat(cgImage.width)
        let pixelH = CGFloat(cgImage.height)
        guard pixelW > 0, pixelH > 0 else { return nil }

        let imageRatio = pixelW / pixelH
        let cropRect: CGRect
        if imageRatio > ratio {
            let cropWidth = pixelH * ratio
            cropRect = CGRect(x: (pixelW - cropWidth) / 2, y: 0,
                              width: cropWidth, height: pixelH)
        } else {
            let cropHeight = pixelW / ratio
            cropRect = CGRect(x: 0, y: (pixelH - cropHeight) / 2,
                              width: pixelW, height: cropHeight)
        }

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cropped)
    }
}

private final class CropCacheKey: NSObject {
    let data: NSData
    let ratio: Int

    init(_ data: Data, _ ratio: CGFloat) {
        self.data = data as NSData
        self.ratio = Int((ratio * 1000).rounded())
    }

    override var hash: Int { data.hash ^ ratio }

    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? CropCacheKey else { return false }
        return other.ratio == ratio && other.data.isEqual(data)
    }
}
