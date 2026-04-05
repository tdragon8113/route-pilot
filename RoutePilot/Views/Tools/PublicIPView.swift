//
//  PublicIPView.swift
//  RoutePilot
//

import SwiftUI

/// 公网 IP 查询组件
struct PublicIPView: View {
    @State private var publicIPInfo: PublicIPInfo?
    @State private var isQueryingIP = false
    @State private var ipQueryError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("公网 IP 查询")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("查询当前公网 IP 及地理位置")
                .font(.caption)
                .foregroundColor(.secondary)

            if isQueryingIP {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("查询中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let info = publicIPInfo {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("IP:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.query)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("位置:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(info.country), \(info.city)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("运营商:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(info.isp)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
            }

            if let error = ipQueryError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(isQueryingIP ? "查询中..." : "查询") {
                queryPublicIP()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isQueryingIP)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private func queryPublicIP() {
        isQueryingIP = true
        ipQueryError = nil

        guard let url = URL(string: "https://ipapi.co/json/") else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                await MainActor.run {
                    isQueryingIP = false
                    if let ip = json?["ip"] as? String {
                        publicIPInfo = PublicIPInfo(
                            status: "success",
                            country: json?["country_name"] as? String ?? "",
                            city: json?["city"] as? String ?? "",
                            isp: json?["org"] as? String ?? "",
                            query: ip
                        )
                    } else {
                        ipQueryError = "查询失败"
                    }
                }
            } catch {
                await MainActor.run {
                    isQueryingIP = false
                    ipQueryError = "查询失败，请检查网络连接"
                }
            }
        }
    }
}