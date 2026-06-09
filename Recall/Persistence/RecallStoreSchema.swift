import Foundation
import SwiftData
import os.log

/// SwiftData ModelContainer factory.
/// 6.x added the isSnippet / triggerWord / usageCount fields—SwiftData's
/// lightweight migration handles them automatically (fields have defaults).
enum RecallStoreSchema {
    static let schema = Schema([ClipItem.self])

    static func makeContainer() -> ModelContainer {
        // Reuse ClipStorageLocation.applicationSupportDirectory—which
        // already applies exclude-from-backup and NSFileProtection.complete.
        let url = ClipStorageLocation.applicationSupportDirectory
            .appendingPathComponent("Recall.store")
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let config = ModelConfiguration(
            "Recall",
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            AppLog.store.error("ModelContainer init failed: \(error.localizedDescription, privacy: .public)")
            // User data severely corrupted—actively wipe and rebuild
            // (the app itself is not lost).
            deleteCorruptedStore(at: url)
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                AppLog.store.fault("Recovery after delete failed: \(error.localizedDescription, privacy: .public)")
                return try! ModelContainer(
                    for: schema,
                    configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
                )
            }
        }
    }

    private static func deleteCorruptedStore(at url: URL) {
        for ext in ["", "-shm", "-wal"] {
            let f = url.deletingPathExtension().appendingPathExtension("store\(ext)")
            try? FileManager.default.removeItem(at: f)
        }
        AppLog.store.error("Deleted corrupted store at: \(url.path, privacy: .public)")
    }
}
