//
//  VPNConfig.swift
//  RoutePilot
//

import Foundation

/// VPN 配置模型
struct VPNConfig: Identifiable, Codable {
    var id: String { name }
    var name: String
    var enabled: Bool = true
    var hidden: Bool = false
    var routes: [RouteItem] = []

    init(name: String, enabled: Bool = true, hidden: Bool = false, routes: [RouteItem] = []) {
        self.name = name
        self.enabled = enabled
        self.hidden = hidden
        self.routes = routes
    }
}