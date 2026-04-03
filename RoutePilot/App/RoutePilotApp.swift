//
//  RoutePilotApp.swift
//  RoutePilot
//

import SwiftUI

@main
struct RoutePilotApp: App {
    @ObservedObject private var app = AppController.shared

    var body: some Scene {
        MenuBarExtra("RoutePilot", systemImage: app.vpnConnected ? "antenna.radiowaves.left.and.right.circle.fill" : "antenna.radiowaves.left.and.right.circle") {
            MenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}