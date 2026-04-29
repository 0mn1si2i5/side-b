import Foundation

extension URL {
    func appendingSideBPath(_ path: String) -> URL {
        let parts = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let normalizedPath = String(parts.first ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !normalizedPath.isEmpty else { return self }

        let url = appending(path: normalizedPath)
        guard parts.count == 2 else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.percentEncodedQuery = String(parts[1])
        return components?.url ?? url
    }
}
