//
//  RouteItem.swift
//  RoutePilot
//

import Foundation

/// 路由项模型
struct RouteItem: Identifiable, Codable {
    let id: UUID
    var destination: String
    var note: String?
    var enabled: Bool

    init(destination: String, note: String? = nil, enabled: Bool = true) {
        self.id = UUID()
        self.destination = destination
        self.note = note
        self.enabled = enabled
    }
}