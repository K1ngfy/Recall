import AppKit
import CryptoKit

/// Translates a single NSPasteboard change into a storable ClipItem.
enum ClipItemBuilder {

    struct Result {
        let type: ClipContentType
        let textContent: String?
        let imageOriginal: NSImage?
        let contentHash: String
    }

    /// Only route to the .image stream when the file extension belongs to a
    /// "real" image format. Don't use NSImage(contentsOf:) as the discriminator:
    /// it also succeeds for PDF / SVG, which would store PDFs as image items
    /// and leave the list showing only the app icon with no body text.
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp", "heic", "heif",
        "ico", "icns", "pict", "jp2", "j2k"
    ]

    static func build(from pb: NSPasteboard) -> Result? {
        // 1) Image priority: read image data directly from the pasteboard
        if let image = readImageData(from: pb) {
            let hash = sha256(of: image.tiffRepresentation ?? Data())
            return Result(type: .image, textContent: nil, imageOriginal: image, contentHash: hash)
        }

        // 2) File URL (common cases: copy a file in Finder / drag a file into Terminal)
        //    - Extension hits the image whitelist → .image
        //    - Otherwise (PDF / txt / doc / zip / video etc.) → .file
        if let fileURL = readFileURL(from: pb) {
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext), let image = NSImage(contentsOf: fileURL) {
                let hash = sha256(of: image.tiffRepresentation ?? Data())
                return Result(type: .image, textContent: fileURL.path, imageOriginal: image, contentHash: hash)
            }
            let hash = sha256(of: Data(fileURL.path.utf8))
            return Result(type: .file, textContent: fileURL.path, imageOriginal: nil, contentHash: hash)
        }

        // 3) Links / text all go through the string channel
        if let str = pb.string(forType: .string), !str.isEmpty {
            let hash = sha256(of: Data(str.utf8))
            if let url = URL(string: str), url.isSafeWeb {
                return Result(type: .link, textContent: str, imageOriginal: nil, contentHash: hash)
            }
            return Result(type: .text, textContent: str, imageOriginal: nil, contentHash: hash)
        }

        return nil
    }

    private static func readImageData(from pb: NSPasteboard) -> NSImage? {
        if let data = pb.data(forType: .png) ?? pb.data(forType: .tiff) {
            return NSImage(data: data)
        }
        return nil
    }

    private static func readFileURL(from pb: NSPasteboard) -> URL? {
        // Explicit fileURL type (Finder drag / copy)
        if let urls = pb.readObjects(forClasses: [NSURL.self]) as? [URL],
           let first = urls.first,
           first.isFileURL,
           first.path.hasPrefix("/") {     // Guard against malformed entries like `file://relative-path`
            return first
        }
        // Fallback: string channel contains a file:// URL
        if let str = pb.string(forType: .string),
           let url = URL(string: str),
           url.isFileURL,
           url.path.hasPrefix("/"),
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    private static func sha256(of data: Data) -> String {
        SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }
}
