//
//  ClearableTextField.swift
//  RoutePilot
//

import SwiftUI

/// 带清除按钮的文本输入框
struct ClearableTextField: View {
    let placeholder: String
    @Binding var text: String
    var width: CGFloat? = nil

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .padding(.leading, 2)
            }
        }
        .ifLet(width) { view, w in
            view.frame(width: w)
        }
    }
}

// Helper extension for optional frame
extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(_ value: T?, @ViewBuilder transform: (Self, T) -> Content) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}