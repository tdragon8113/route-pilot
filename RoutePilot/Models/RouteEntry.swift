//
//  RouteEntry.swift
//  RoutePilot
//

import Foundation

/// 路由表条目
struct RouteEntry: Identifiable {
    let id = UUID()
    let destination: String
    let gateway: String
    let flags: String
    let interface: String
}