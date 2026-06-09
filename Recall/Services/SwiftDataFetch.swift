import Foundation
import SwiftData

/// Generic SwiftData fetch helper: avoid SnippetService / ClipStore
/// re-implementing the "full-table fetch then first(where:)" pattern.
@MainActor
enum SwiftDataFetch {

    /// Fetch a single row by a UUID field (works for models like ClipItem
    /// with `@Attribute(.unique) var id: UUID`).
    /// On macOS 26 / SwiftData, `#Predicate { $0.id == uuidValue }` is
    /// unstable for cross-type inference. Fall back to fetch + in-memory
    /// first(where:). For SwiftData's Predicate limitations see
    /// recall-known-pitfalls #3.
    static func firstByID<T: PersistentModel>(
        _ type: T.Type,
        keyPath: KeyPath<T, UUID>,
        id: UUID,
        in context: ModelContext
    ) -> T? {
        let descriptor = FetchDescriptor<T>()
        return (try? context.fetch(descriptor))?.first { $0[keyPath: keyPath] == id }
    }

    /// Fetch all
    static func all<T: PersistentModel>(
        _ type: T.Type,
        sortedBy sort: [SortDescriptor<T>] = [],
        in context: ModelContext
    ) -> [T] {
        var descriptor = FetchDescriptor<T>()
        if !sort.isEmpty { descriptor.sortBy = sort }
        return (try? context.fetch(descriptor)) ?? []
    }
}
