import Foundation

extension Notification.Name {
    static let sideBRoomDissolved = Notification.Name("sideBRoomDissolved")
    static let sideBRoomUpdated = Notification.Name("sideBRoomUpdated")
}

enum RoomNotificationKey {
    static let roomID = "roomID"
}
