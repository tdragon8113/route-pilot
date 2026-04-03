//
//  RouteItem.swift
//  RoutePilot
//

import Foundation

/// 路由项模型
struct RouteItem: Identifiable, Codable {
    let id: UUID
    var destination: String
    var enabled: Bool

    init(destination: String, enabled: Bool = true) {
        self.id = UUID()
        self.destination = destination
        self.enabled = enabled
    }
}