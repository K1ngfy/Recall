import Foundation
import AppKit

/// Background thumbnail generator. The actor guarantees thread safety.
/// Large images (>1MB) on the PasteboardMonitor main thread get only a
/// placeholder (no thumbnailData) so ListViewModel can render immediately;
/// once the actor finishes, it posts a notification to update the database
/// and UI.
actor ImageThumbnailActor {
    static let shared = ImageThumbnailActor()

    /// Generate thumbnail (pure compute, no UI side effects)
    func makeThumbnail(tiff: Data) -> Data? {
        guard let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        let original = bitmap.size
        let maxSide = ClipStorageLocation.thumbnailMaxPixel
        let scale = min(1.0, maxSide / max(original.width, original.height))
        let target = NSSize(
            width: max(1, floor(original.width * scale)),
            height: max(1, floor(original.height * scale))
        )

        guard let cgImage = bitmap.cgImage else { return nil }
        let resized = NSImage(size: target)
        resized.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.cgContext.draw(
            cgImage,
            in: NSRect(origin: .zero, size: target)
        )
        resized.unlockFocus()

        guard let resizedTiff = resized.tiffRepresentation,
              let resizedBitmap = NSBitmapImageRep(data: resizedTiff) else { return nil }

        return resizedBitmap.representation(
            using: .jpeg,
            properties: [.compressionFactor: ClipStorageLocation.thumbnailJPEGQuality]
        )
    }

    /// Write original image to disk
    func writeOriginal(tiff: Data, filename: String) -> URL? {
        let url = ClipStorageLocation.imageDirectory.appendingPathComponent(filename)
        guard let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
        do {
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
