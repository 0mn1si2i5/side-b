import Foundation

extension UUID {
    var sideBPathID: String {
        uuidString.lowercased()
    }
}
