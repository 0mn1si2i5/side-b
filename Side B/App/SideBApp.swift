import SwiftUI
import UIKit

@main
struct SideBApp: App {
    init() {
        let tabBar = UITabBar.appearance()
        tabBar.itemPositioning = .centered
        tabBar.itemWidth = 86
        tabBar.itemSpacing = 28

        URLCache.shared = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 256 * 1024 * 1024,
            directory: nil
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
