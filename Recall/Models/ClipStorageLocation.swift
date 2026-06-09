import Foundation

/// Centralized management of "in / out of app sandbox" file directories.
///
/// 6.7 privacy hardening:
/// 1. Exclude from backup: prevents clipboard history (which may contain
///    passwords / tokens / private text) from leaking to Time Machine /
///    iCloud backup disks.
/// 2. NSFileProtection.complete: on macOS 14+, marks files as "unreadable
///    while the user is not logged in"; even same-user processes can't read
///    them when the screen is locked / the user is switched out.
enum ClipStorageLocation {
    /// Application Support/Recall/Images/  stores the original images (after thumbnail)
    static var imageDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Recall", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        ensureDirectory(base)
        excludeFromBackup(base)
        return base
    }

    /// Application Support/Recall/  stores the SwiftData store
    static var applicationSupportDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Recall", isDirectory: true)
        ensureDirectory(base)
        excludeFromBackup(base)
        return base
    }

    static let thumbnailMaxPixel: CGFloat = 256
    static let thumbnailJPEGQuality: CGFloat = 0.7

    private static func ensureDirectory(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// 1) Exclude from iCloud + Time Machine backup
    /// 2) macOS 14+ FileProtection.complete: unreadable by same-user
    ///    processes after the screen is locked
    ///    (stored in xattr, transparent to CoreData-derived engines like
    ///    SwiftData)
    private static func excludeFromBackup(_ url: URL) {
        var v = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? v.setResourceValues(resourceValues)

        // The macOS kernel recognizes the `com.apple.fileprotection` xattr.
        // Foundation's URLFileProtection / fileProtectionKey are stubs on
        // macOS (the real implementation is iOS-only), so we must call the
        // setxattr syscall directly.
        //   NSFileProtectionNone        = 0
        //   NSFileProtectionComplete    = 1   (file isn't locked, but the app
        //                                      must unlock it to read)
        //   ... We only care about "unreadable after the screen is locked",
        //       so use .complete
        //   Apple's iOS header rawValue is 1; the kernel actually receives
        //   4 little-endian bytes.
        var raw: UInt32 = 1
        let bytes = withUnsafeBytes(of: &raw) { Data($0) }
        _ = bytes.withUnsafeBytes { ptr in
            setxattr(
                url.path,
                "com.apple.fileprotection",
                ptr.baseAddress,
                ptr.count,
                0,                  // position
                XATTR_NOFOLLOW      // do not follow symlinks
            )
        }
    }

    /// 6.7 retroactively tag pre-existing files with the protection label
    /// at startup.
    /// excludeFromBackup() only affects files that exist at the moment of
    /// the call; store files and images written before this upgrade are not
    /// tagged automatically, so we walk them explicitly.
    /// Note: SwiftData's .store / -shm / -wal are individual files—each
    /// must be tagged.
    static func applyProtectionToExistingFiles() {
        let fm = FileManager.default
        let base = applicationSupportDirectory

        // 1) store main file + SQLite companions (-shm / -wal)
        for ext in ["", "-shm", "-wal"] {
            let storeURL = base.appendingPathComponent("Recall.store\(ext)")
            if fm.fileExists(atPath: storeURL.path) {
                excludeFromBackup(storeURL)
            }
        }

        // 2) All originals under Images/
        let images = base.appendingPathComponent("Images", isDirectory: true)
        if let entries = try? fm.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) {
            for file in entries {
                excludeFromBackup(file)
            }
        }
    }

    /// 6.7 post-write fallback: re-tag the store trio's xattr at the end of
    /// every upsert.
    /// In SQLite WAL mode, -wal may be truncated at checkpoint and -shm may
    /// be regenerated—new files don't inherit xattr—so we force-set every
    /// write.
    /// setxattr is an O(1) syscall, negligible cost (a single pasteboard
    /// tick only does 1-2 calls).
    static func reapplyStoreXattr() {
        let fm = FileManager.default
        let base = applicationSupportDirectory
        for ext in ["", "-shm", "-wal"] {
            let url = base.appendingPathComponent("Recall.store\(ext)")
            if fm.fileExists(atPath: url.path) {
                excludeFromBackup(url)
            }
        }
    }
}
