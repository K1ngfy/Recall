import Foundation

/// Centralized management of "in / out of app sandbox" file directories.
///
/// 6.7 privacy hardening:
/// - **Exclude from backup**: prevents clipboard history (which may contain
///   passwords / tokens / private text) from leaking to Time Machine /
///   iCloud backup disks.
///
/// 6.9 security note: we previously also wrote `com.apple.fileprotection` xattr
/// claiming "unreadable when screen is locked". That xattr is **iOS-only** —
/// the macOS kernel does not enforce it, so the claim was misleading. We
/// removed the setxattr call to avoid suggesting protection that doesn't
/// exist on macOS. Same-user processes can still read the SwiftData store
/// when the screen is locked; if you need true at-rest encryption, layer
/// application-level AES-GCM on top of `textContent`.
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

    /// Exclude the URL from iCloud + Time Machine backup.
    /// 6.9: setxattr "com.apple.fileprotection" removed — see file-level doc.
    private static func excludeFromBackup(_ url: URL) {
        var v = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? v.setResourceValues(resourceValues)
    }

    /// 6.7 retroactively tag pre-existing files with the backup-exclusion
    /// label at startup. excludeFromBackup() only affects files that exist at
    /// the moment of the call; store files and images written before this
    /// upgrade are not tagged automatically, so we walk them explicitly.
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

    /// 6.7 post-write fallback: re-tag the store trio's backup-exclusion xattr
    /// at the end of every upsert. In SQLite WAL mode, -wal may be truncated
    /// at checkpoint and -shm may be regenerated—new files don't inherit the
    /// xattr—so we force-set every write. setResourceValues is cheap.
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
