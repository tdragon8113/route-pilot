//
//  TracerouteHop.swift
//  RoutePilot
//

import Foundation

/// 路由追踪跳数
struct TracerouteHop: Identifiable {
    let id = UUID()
    let hopNumber: Int
    let ip: String?
    let hostname: String?
    let time: String?
}