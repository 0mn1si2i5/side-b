//
//  Item.swift
//  Side B
//
//  Created by 李佳鸣 on 2026/4/11.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
