import Foundation

struct PersistedPlatformLinkRecord {
    let platformLinks: [PlatformLink]
    let platformLinkStatuses: [PlatformLinkStatusEntry]
    let updatedAt: Date
}

final class PlatformLinkPersistenceStore {
    static let shared = PlatformLinkPersistenceStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb.persistedPlatformLinks"
    private let loadingExpiryInterval: TimeInterval = 5 * 60

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func restore(track: Track) -> Track? {
        guard let record = loadRecord(for: track) else { return nil }
        let sanitizedStatuses = sanitizeStatuses(record.platformLinkStatuses, updatedAt: record.updatedAt)
        return track.restoringPersistedPlatformLinks(record.platformLinks, statuses: sanitizedStatuses)
    }

    func save(track: Track) {
        guard let identity = track.persistenceIdentity else { return }
        var records = loadAllRecords()
        let platformLinkBodies = track.platformLinks.map { platformLink in
            PersistedPlatformLinkBody(platformLink: platformLink)
        }
        let platformLinkStatusBodies = track.platformLinkStatuses.map { status in
            PersistedPlatformLinkStatusBody(status: status)
        }
        records[identity] = PersistedPlatformLinkRecordBody(
            platformLinks: platformLinkBodies,
            platformLinkStatuses: platformLinkStatusBodies,
            updatedAt: Date()
        )
        persistAllRecords(records)
    }

    private func loadRecord(for track: Track) -> PersistedPlatformLinkRecord? {
        for identity in candidateIdentities(for: track) {
            guard let record = loadAllRecords()[identity] else { continue }
            return record.toDomain()
        }

        return nil
    }

    private func candidateIdentities(for track: Track) -> [String] {
        var identities: [String] = []
        if let sourcePlatformID = track.sourcePlatformID, !sourcePlatformID.isEmpty {
            identities.append("\(track.sourcePlatform.rawValue)::\(sourcePlatformID)")
        }
        if let sourceURL = track.sourceURL?.absoluteString {
            identities.append(sourceURL)
        }
        return identities
    }

    private func sanitizeStatuses(_ statuses: [PlatformLinkStatusEntry], updatedAt: Date) -> [PlatformLinkStatusEntry] {
        guard Date().timeIntervalSince(updatedAt) > loadingExpiryInterval else { return statuses }

        return statuses.map { entry in
            guard entry.state == .loading else { return entry }
            return PlatformLinkStatusEntry(platform: entry.platform, state: .idle)
        }
    }

    private func loadAllRecords() -> [String: PersistedPlatformLinkRecordBody] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try decoder.decode([String: PersistedPlatformLinkRecordBody].self, from: data)
        } catch {
            print("[PlatformLinkPersistenceStore] decode failed:", error)
            return [:]
        }
    }

    private func persistAllRecords(_ records: [String: PersistedPlatformLinkRecordBody]) {
        let data: Data
        do {
            data = try encoder.encode(records)
        } catch {
            print("[PlatformLinkPersistenceStore] encode failed:", error)
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }
}

private struct PersistedPlatformLinkRecordBody: Codable {
    let platformLinks: [PersistedPlatformLinkBody]
    let platformLinkStatuses: [PersistedPlatformLinkStatusBody]
    let updatedAt: Date

    func toDomain() -> PersistedPlatformLinkRecord {
        let restoredPlatformLinks = platformLinks.compactMap { $0.toDomain }
        let restoredStatuses = platformLinkStatuses.compactMap { $0.toDomain }
        return PersistedPlatformLinkRecord(
            platformLinks: restoredPlatformLinks,
            platformLinkStatuses: restoredStatuses,
            updatedAt: updatedAt
        )
    }
}

private struct PersistedPlatformLinkBody: Codable {
    let platform: String
    let destinationURL: String
    let isSource: Bool

    init(platformLink: PlatformLink) {
        platform = platformLink.platform.rawValue
        destinationURL = platformLink.destinationURL.absoluteString
        isSource = platformLink.isSource
    }

    init(_ platformLink: PlatformLink) {
        self.init(platformLink: platformLink)
    }

    var toDomain: PlatformLink? {
        guard let platform = MusicPlatform(rawValue: platform), let destinationURL = URL(string: destinationURL) else {
            return nil
        }

        return PlatformLink(platform: platform, destinationURL: destinationURL, isSource: isSource)
    }
}

private struct PersistedPlatformLinkStatusBody: Codable {
    let platform: String
    let state: String

    init(status: PlatformLinkStatusEntry) {
        platform = status.platform.rawValue
        state = status.state.rawValue
    }

    init(_ status: PlatformLinkStatusEntry) {
        self.init(status: status)
    }

    var toDomain: PlatformLinkStatusEntry? {
        guard
            let platform = MusicPlatform(rawValue: platform),
            let state = PlatformLinkLoadState(rawValue: state)
        else {
            return nil
        }

        return PlatformLinkStatusEntry(platform: platform, state: state)
    }
}
