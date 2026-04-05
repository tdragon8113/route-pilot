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
                .onAppear {
                    applySavedTheme()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func applySavedTheme() {
        let savedTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "") ?? .system
        switch savedTheme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .system:
            NSApp.appearance = nil
        }
    }
}