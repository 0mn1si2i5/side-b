import Foundation

struct RecentlyResolvedEntry: Codable {
    let persistenceIdentity: String
    let resolvedAt: Date
}

protocol RecentlyResolvedStoreProtocol: AnyObject {
    func add(_ persistenceIdentity: String)
    func recentEntries(limit: Int) -> [String]
    func allEntries() -> [String]
    func clear()
    func remove(identity: String)
}

final class RecentlyResolvedStore: RecentlyResolvedStoreProtocol {
    static let shared = RecentlyResolvedStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb.recentlyResolved"
    private let maxEntries = 50

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func add(_ persistenceIdentity: String) {
        var entries = loadAllRecords()

        entries.removeAll { $0.persistenceIdentity == persistenceIdentity }

        let newEntry = RecentlyResolvedEntry(
            persistenceIdentity: persistenceIdentity,
            resolvedAt: Date()
        )
        entries.insert(newEntry, at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persistAllRecords(entries)
    }

    func recentEntries(limit: Int = 3) -> [String] {
        let entries = loadAllRecords()
        let limitedEntries = entries.prefix(limit)
        return limitedEntries.map { $0.persistenceIdentity }
    }

    func allEntries() -> [String] {
        let entries = loadAllRecords()
        return entries.map { $0.persistenceIdentity }
    }

    func clear() {
        userDefaults.removeObject(forKey: storageKey)
    }

    func remove(identity: String) {
        var entries = loadAllRecords()
        entries.removeAll { $0.persistenceIdentity == identity }
        persistAllRecords(entries)
    }

    private func loadAllRecords() -> [RecentlyResolvedEntry] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        do {
            return try decoder.decode([RecentlyResolvedEntry].self, from: data)
        } catch {
            print("[RecentlyResolvedStore] decode failed:", error)
            return []
        }
    }

    private func persistAllRecords(_ entries: [RecentlyResolvedEntry]) {
        let data: Data
        do {
            data = try encoder.encode(entries)
        } catch {
            print("[RecentlyResolvedStore] encode failed:", error)
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }
}
