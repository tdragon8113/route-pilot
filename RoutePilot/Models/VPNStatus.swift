//
//  VPNStatus.swift
//  RoutePilot
//

import Foundation

/// VPN 状态模型
struct VPNStatus: Equatable {
    let name: String
    let connected: Bool
    let interface: String?
}