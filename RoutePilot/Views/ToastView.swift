//
//  ToastView.swift
//  RoutePilot
//

import SwiftUI

/// Toast 提示视图
struct ToastView: View {
    let toast: ToastItem
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.type.icon)
                .foregroundColor(toast.type.color)
                .font(.system(size: 14))

            Text(toast.message)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(toast.type.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(toast.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.15), radius: 3, y: 2)
    }
}