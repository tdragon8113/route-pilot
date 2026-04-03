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
    var routes: [RouteItem] = []

    init(name: String) {
        self.name = name
    }
}