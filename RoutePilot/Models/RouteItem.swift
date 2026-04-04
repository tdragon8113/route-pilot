//
//  RouteItem.swift
//  RoutePilot
//

import Foundation

/// 路由类型
enum RouteType: String, Codable {
    case cidr    // IP 网络，如 10.0.0.0/8
    case domain  // 域名，如 github.com
}

/// 路由项模型
struct RouteItem: Identifiable, Codable {
    let id: UUID
    var destination: String
    var type: RouteType
    var note: String?
    var enabled: Bool

    init(destination: String, type: RouteType = .cidr, note: String? = nil, enabled: Bool = true) {
        self.id = UUID()
        self.destination = destination
        self.type = type
        self.note = note
        self.enabled = enabled
    }
}